import 'dart:math' as math;
import '../motion/phone_motion_pipeline.dart';

/// Single 3D accelerometer sample with timestamp (retained for backward compatibility).
class AccelerometerSample {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const AccelerometerSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

/// Detection result for a single sample processed by [AdaptivePeakValleyStepCounter].
class StepDetectionResult {
  final bool isStep;
  final int totalSteps;
  final double confidence;
  final double filteredMagnitude;
  final double dynamicThreshold;
  final double signalQuality;
  final double cadenceEstimate; // Steps per minute
  final DateTime timestamp;

  const StepDetectionResult({
    required this.isStep,
    required this.totalSteps,
    required this.confidence,
    required this.filteredMagnitude,
    required this.dynamicThreshold,
    this.signalQuality = 1.0,
    this.cadenceEstimate = 0.0,
    required this.timestamp,
  });
}

/// Deterministic, orientation-tolerant adaptive peak/valley step detection algorithm
/// with gyroscope-assisted false-positive rotational suppression.
///
/// Conceptual Pipeline:
/// 1. Sensor Fusion: Raw 3D Acceleration + Gyroscope rotation vector.
/// 2. Euclidean Norm: Magnitude calculation ensures orientation invariance.
/// 3. Low-Pass Exponential Moving Average: Alpha filtering suppresses high-frequency sensor noise.
/// 4. Sliding Window Statistics: Computes dynamic peak and valley thresholds from recent biomechanical movement.
/// 5. Gyroscope Rotational Suppression: Distinguishes pure device rotation (high rad/s, low translational bounce)
///    from actual footsteps (periodic translational acceleration with low/moderate rotation).
/// 6. Strict Temporal Refractory Constraints: Enforces 220ms - 2000ms human gait cadence limits.
/// 7. Dynamic Cadence & Confidence Estimation.
class AdaptivePeakValleyStepCounter {
  final double alpha; // Low-pass EMA smoothing factor (0.0 to 1.0)
  final int windowSize; // Sample window for adaptive threshold
  final double minMagnitudeSwing; // Minimum peak-to-valley swing in m/s^2 (suppresses desk jitter)
  final int minStepIntervalMs; // Minimum refractory period between steps (220ms = ~4.5 Hz)
  final int maxStepIntervalMs; // Maximum stride window (2000ms = 0.5 Hz)
  final double maxGyroRotationThreshold; // Max rotation rate (rad/s) before candidate step is suppressed as rotation

  double? _lastFilteredMagnitude;
  final List<double> _magnitudeHistory = [];
  final List<DateTime> _recentStepTimestamps = [];

  // Peak/valley detection state machine
  bool _searchingPeak = true;
  double? _candidatePeakMagnitude;
  DateTime? _candidatePeakTime;
  DateTime? _lastStepTime;
  int _stepCount = 0;

  AdaptivePeakValleyStepCounter({
    this.alpha = 0.25,
    this.windowSize = 40,
    this.minMagnitudeSwing = 1.4,
    this.minStepIntervalMs = 220,
    this.maxStepIntervalMs = 2000,
    this.maxGyroRotationThreshold = 2.5, // > 2.5 rad/s (~143 deg/s) indicates fast hand rotation
  });

  int get totalSteps => _stepCount;

  void reset() {
    _lastFilteredMagnitude = null;
    _magnitudeHistory.clear();
    _recentStepTimestamps.clear();
    _searchingPeak = true;
    _candidatePeakMagnitude = null;
    _candidatePeakTime = null;
    _lastStepTime = null;
    _stepCount = 0;
  }

  /// Processes a fused [SensorSample] with accelerometer and gyroscope data.
  StepDetectionResult processSensorSample(SensorSample sample) {
    return _evaluate(
      rawMagnitude: sample.accelMagnitude,
      gyroMagnitude: sample.gyroMagnitude,
      timestamp: sample.timestamp,
    );
  }

  /// Backward-compatible processing method for [AccelerometerSample].
  StepDetectionResult processSample(AccelerometerSample sample) {
    return _evaluate(
      rawMagnitude: sample.magnitude,
      gyroMagnitude: 0.0,
      timestamp: sample.timestamp,
    );
  }

  StepDetectionResult _evaluate({
    required double rawMagnitude,
    required double gyroMagnitude,
    required DateTime timestamp,
  }) {
    final now = timestamp;

    // 1. Low-pass filter (Exponential Moving Average)
    final double filtered;
    if (_lastFilteredMagnitude == null) {
      filtered = rawMagnitude;
    } else {
      filtered = alpha * rawMagnitude + (1.0 - alpha) * _lastFilteredMagnitude!;
    }
    _lastFilteredMagnitude = filtered;

    // 2. Maintain sliding window of filtered magnitudes
    _magnitudeHistory.add(filtered);
    if (_magnitudeHistory.length > windowSize) {
      _magnitudeHistory.removeAt(0);
    }

    // 3. Compute adaptive thresholds from sliding window
    double mean = 9.81;
    double minVal = filtered;
    double maxVal = filtered;

    if (_magnitudeHistory.isNotEmpty) {
      double sum = 0.0;
      for (final v in _magnitudeHistory) {
        sum += v;
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
      mean = sum / _magnitudeHistory.length;
    }

    final dynamicSwing = maxVal - minVal;
    final deltaPeak = math.max(0.6, 0.35 * (maxVal - mean));
    final deltaValley = math.max(0.6, 0.35 * (mean - minVal));
    final peakThreshold = mean + deltaPeak;
    final valleyThreshold = mean - deltaValley;

    // Calculate cadence from recent steps
    _pruneRecentSteps(now);
    final cadence = _calculateCadence();

    // Insufficient movement swing: device is resting, stationary or micro-vibrating
    if (dynamicSwing < minMagnitudeSwing) {
      _searchingPeak = true;
      _candidatePeakMagnitude = null;
      return StepDetectionResult(
        isStep: false,
        totalSteps: _stepCount,
        confidence: 0.0,
        filteredMagnitude: filtered,
        dynamicThreshold: peakThreshold,
        signalQuality: 1.0,
        cadenceEstimate: cadence,
        timestamp: now,
      );
    }

    // Gyroscope False-Positive Suppression:
    // If the phone is undergoing intense angular rotation (flipping, waving, table spinning)
    // without proportional vertical translational bounce, suppress step candidate.
    final bool isExtremeRotation = gyroMagnitude > maxGyroRotationThreshold && dynamicSwing < 2.5;

    bool detectedStep = false;
    double confidence = 0.0;
    double signalQuality = 1.0;

    // 4. Peak / Valley State Machine
    if (_searchingPeak) {
      if (filtered > peakThreshold) {
        if (_candidatePeakMagnitude == null || filtered > _candidatePeakMagnitude!) {
          _candidatePeakMagnitude = filtered;
          _candidatePeakTime = now;
        }
      } else if (_candidatePeakMagnitude != null) {
        // Crossed below peak threshold after observing a peak
        _searchingPeak = false;
      }
    } else {
      // Searching for matching valley
      if (_candidatePeakTime != null &&
          now.difference(_candidatePeakTime!).inMilliseconds > maxStepIntervalMs) {
        // Stride timed out; reset to search for fresh peak
        _searchingPeak = true;
        _candidatePeakMagnitude = null;
        _candidatePeakTime = null;
        if (filtered > peakThreshold) {
          _candidatePeakMagnitude = filtered;
          _candidatePeakTime = now;
        }
      } else if (filtered > (_candidatePeakMagnitude ?? peakThreshold)) {
        // Track higher peak if acceleration increases again before hitting valley
        _candidatePeakMagnitude = filtered;
        _candidatePeakTime = now;
      } else if (filtered < valleyThreshold) {
        final peakMag = _candidatePeakMagnitude ?? (mean + deltaPeak);
        final swing = peakMag - filtered;

        if (swing >= minMagnitudeSwing && !isExtremeRotation) {
          // Check temporal refractory constraints
          final int elapsedSinceLastStep = _lastStepTime != null
              ? now.difference(_lastStepTime!).inMilliseconds
              : (minStepIntervalMs + 100);
          final int peakToValleyMs = _candidatePeakTime != null
              ? now.difference(_candidatePeakTime!).inMilliseconds
              : 200;

          if (elapsedSinceLastStep >= minStepIntervalMs && peakToValleyMs <= 1200) {
            _stepCount++;
            detectedStep = true;
            _lastStepTime = now;
            _recentStepTimestamps.add(now);

            // Confidence scoring based on physiological gait pattern
            final swingScore = ((swing - minMagnitudeSwing) / 3.0).clamp(0.0, 1.0);
            final temporalScore = (elapsedSinceLastStep <= maxStepIntervalMs) ? 1.0 : 0.8;
            final gyroScore = (gyroMagnitude < 1.5) ? 1.0 : 0.85;

            confidence = (0.7 + 0.25 * swingScore) * temporalScore * gyroScore;
            confidence = confidence.clamp(0.6, 0.99);
            signalQuality = gyroScore;
          }

          // Reset for next peak
          _searchingPeak = true;
          _candidatePeakMagnitude = null;
          _candidatePeakTime = null;
        } else if (isExtremeRotation) {
          // Rotation suppressed: reset peak search
          _searchingPeak = true;
          _candidatePeakMagnitude = null;
          _candidatePeakTime = null;
        }
      }
    }

    return StepDetectionResult(
      isStep: detectedStep,
      totalSteps: _stepCount,
      confidence: confidence,
      filteredMagnitude: filtered,
      dynamicThreshold: peakThreshold,
      signalQuality: signalQuality,
      cadenceEstimate: _calculateCadence(),
      timestamp: now,
    );
  }

  void _pruneRecentSteps(DateTime now) {
    _recentStepTimestamps.removeWhere(
      (t) => now.difference(t).inSeconds > 10,
    );
  }

  double _calculateCadence() {
    if (_recentStepTimestamps.length < 2) return 0.0;
    final elapsedSec = _recentStepTimestamps.last
            .difference(_recentStepTimestamps.first)
            .inMilliseconds /
        1000.0;
    if (elapsedSec <= 0) return 0.0;
    final stepsPerSec = (_recentStepTimestamps.length - 1) / elapsedSec;
    return (stepsPerSec * 60.0).clamp(0.0, 240.0);
  }
}
