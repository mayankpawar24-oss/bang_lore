import 'dart:math' as math;

/// Single 3D accelerometer sample with timestamp.
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

  /// Orientation-invariant Euclidean norm of 3D acceleration vector.
  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

/// Detection result for a single sample processed by [AdaptivePeakValleyStepCounter].
class StepDetectionResult {
  final bool isStep;
  final int totalSteps;
  final double confidence;
  final double filteredMagnitude;
  final double dynamicThreshold;

  const StepDetectionResult({
    required this.isStep,
    required this.totalSteps,
    required this.confidence,
    required this.filteredMagnitude,
    required this.dynamicThreshold,
  });
}

/// Deterministic, orientation-tolerant adaptive peak/valley step detection algorithm.
///
/// Conceptual Pipeline:
/// 1. 3D Acceleration vector → Euclidean magnitude (orientation invariant)
/// 2. Low-pass exponential moving average filter (removes sensor noise & high-frequency tremors)
/// 3. Sliding window statistics (rolling mean, max, min) for adaptive dynamic thresholds
/// 4. Peak and valley extraction with minimum magnitude swing condition (suppresses stationary noise)
/// 5. Peak-valley pairing with strict temporal cadence constraints (220ms - 2000ms)
/// 6. Step emission with confidence scoring
class AdaptivePeakValleyStepCounter {
  final double alpha; // Low-pass EMA smoothing factor (0.0 to 1.0)
  final int windowSize; // Sample window for adaptive threshold
  final double minMagnitudeSwing; // Minimum peak-to-valley swing in m/s^2
  final int minStepIntervalMs; // Minimum refractory period between steps (220ms = ~4.5Hz)
  final int maxStepIntervalMs; // Maximum stride window (2000ms = 0.5Hz)

  double? _lastFilteredMagnitude;
  final List<double> _magnitudeHistory = [];

  // Peak/valley detection state
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
  });

  int get totalSteps => _stepCount;

  void reset() {
    _lastFilteredMagnitude = null;
    _magnitudeHistory.clear();
    _searchingPeak = true;
    _candidatePeakMagnitude = null;
    _candidatePeakTime = null;
    _lastStepTime = null;
    _stepCount = 0;
  }

  /// Processes one accelerometer sample and returns step detection metrics.
  StepDetectionResult processSample(AccelerometerSample sample) {
    final rawMag = sample.magnitude;

    // 1. Low-pass filter (Exponential Moving Average)
    final double filtered;
    if (_lastFilteredMagnitude == null) {
      filtered = rawMag;
    } else {
      filtered = alpha * rawMag + (1.0 - alpha) * _lastFilteredMagnitude!;
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

    bool detectedStep = false;
    double confidence = 0.0;

    // Insufficient movement swing: device is stationary or resting
    if (dynamicSwing < minMagnitudeSwing) {
      _searchingPeak = true;
      _candidatePeakMagnitude = null;
      return StepDetectionResult(
        isStep: false,
        totalSteps: _stepCount,
        confidence: 0.0,
        filteredMagnitude: filtered,
        dynamicThreshold: peakThreshold,
      );
    }

    // 4. Peak / Valley State Machine
    final now = sample.timestamp;

    if (_searchingPeak) {
      if (filtered > peakThreshold) {
        if (_candidatePeakMagnitude == null || filtered > _candidatePeakMagnitude!) {
          _candidatePeakMagnitude = filtered;
          _candidatePeakTime = now;
        }
      } else if (_candidatePeakMagnitude != null) {
        // We crossed below peak threshold after observing a candidate peak
        _searchingPeak = false;
      }
    } else {
      // Searching for matching valley
      if (_candidatePeakTime != null &&
          now.difference(_candidatePeakTime!).inMilliseconds > maxStepIntervalMs) {
        // Candidate peak timed out; reset to search for fresh peak
        _searchingPeak = true;
        _candidatePeakMagnitude = null;
        _candidatePeakTime = null;
        if (filtered > peakThreshold) {
          _candidatePeakMagnitude = filtered;
          _candidatePeakTime = now;
        }
      } else if (filtered > (_candidatePeakMagnitude ?? peakThreshold)) {
        // Track higher peak if acceleration increases again before valley
        _candidatePeakMagnitude = filtered;
        _candidatePeakTime = now;
      } else if (filtered < valleyThreshold) {
        final peakMag = _candidatePeakMagnitude ?? (mean + deltaPeak);
        final swing = peakMag - filtered;

        if (swing >= minMagnitudeSwing) {
          // Check temporal constraints
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

            // Confidence calculation based on swing & plausible human cadence
            final swingScore = ((swing - minMagnitudeSwing) / 3.0).clamp(0.0, 1.0);
            final temporalScore = (elapsedSinceLastStep <= maxStepIntervalMs) ? 1.0 : 0.8;
            confidence = (0.7 + 0.25 * swingScore) * temporalScore;
            confidence = confidence.clamp(0.6, 0.99);
          }

          // Reset for next peak
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
    );
  }
}
