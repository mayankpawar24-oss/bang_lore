import 'dart:async';
import 'dart:math' as math;
import '../models/twin_sensor_signals.dart';
import 'phone_motion_pipeline.dart';

/// Detailed result of windowed sensor classification including confidence,
/// biomechanical metrics, and explainability evidence.
class WindowClassificationResult {
  final TwinActivityType activity;
  final TwinSignalConfidence confidence;
  final Map<String, dynamic> evidence;
  final String? rejectionReason;

  const WindowClassificationResult({
    required this.activity,
    required this.confidence,
    required this.evidence,
    this.rejectionReason,
  });
}

/// Classifies motion into normalized activity states locally using multi-sensor
/// windowed feature extraction from real phone accelerometer and gyroscope signals.
///
/// Implements Activity Recognition 2.0:
/// - Level 1: Motion Intensity, Jerk, Periodicity, and Rotational Ratio extraction.
/// - Level 2: Biomechanical Classification with False-Positive Swing Rejection.
/// - Multi-Window Hysteresis & Temporal Stability State Machine.
class ActivityRecognitionService {
  final _activityController = StreamController<NormalizedActivity>.broadcast();
  StreamSubscription<SensorSample>? _pipelineSub;

  final int windowSampleCount;
  final int hopSampleCount;
  final List<SensorSample> _sampleWindow = [];

  TwinActivityType _currentActivity = TwinActivityType.unknown;
  DateTime _currentActivityStartedAt = DateTime.now();

  // Hysteresis & Stabilization State
  int _consecutiveCandidateWindows = 0;
  TwinActivityType _candidateActivity = TwinActivityType.unknown;
  TwinSignalConfidence _candidateConfidence = TwinSignalConfidence.unknown;
  Map<String, dynamic>? _candidateEvidence;
  DateTime? _lastSignificantMotionTime;
  double _currentCadence = 0.0;

  // Crosswalk Debounce Duration
  final Duration crosswalkDebounceDuration;

  ActivityRecognitionService({
    this.windowSampleCount = 60,
    int? hopSampleCount,
    this.crosswalkDebounceDuration = const Duration(seconds: 5),
  }) : hopSampleCount = hopSampleCount ?? (windowSampleCount ~/ 2);

  Stream<NormalizedActivity> get activityStream => _activityController.stream;
  TwinActivityType get currentActivity => _currentActivity;
  DateTime get currentActivityStartedAt => _currentActivityStartedAt;

  /// Starts listening to the [PhoneMotionPipeline] stream.
  void start(PhoneMotionPipeline pipeline) {
    stop();
    _currentActivityStartedAt = DateTime.now();

    _pipelineSub = pipeline.sampleStream.listen(
      addSample,
      onError: (_) {},
    );
  }

  /// Ingests a new sensor sample into the rolling window with sliding hop.
  void addSample(SensorSample sample) {
    _sampleWindow.add(sample);

    if (_sampleWindow.length >= windowSampleCount) {
      final classified = classifyWindowDetailed(
        List.unmodifiable(_sampleWindow),
        cadence: _currentCadence,
      );

      // Slide window by hopSampleCount
      if (_sampleWindow.length > hopSampleCount) {
        _sampleWindow.removeRange(0, hopSampleCount);
      } else {
        _sampleWindow.clear();
      }

      _handleClassifiedWindow(classified);
    }
  }

  /// Updates current step cadence (steps/minute) to enhance classification accuracy.
  void updateCadence(double cadence) {
    _currentCadence = cadence;
  }

  /// Backward-compatible static classification entrypoint returning [TwinActivityType].
  static TwinActivityType classifyWindow(
    List<SensorSample> samples, {
    double cadence = 0.0,
  }) {
    final result = classifyWindowDetailed(samples, cadence: cadence);
    return result.activity;
  }

  /// Evaluates a window of [SensorSample]s and returns complete [WindowClassificationResult].
  static WindowClassificationResult classifyWindowDetailed(
    List<SensorSample> samples, {
    double cadence = 0.0,
  }) {
    if (samples.isEmpty) {
      return const WindowClassificationResult(
        activity: TwinActivityType.unknown,
        confidence: TwinSignalConfidence.unknown,
        evidence: {},
      );
    }

    final n = samples.length;

    // -------------------------------------------------------------
    // LEVEL 1: MULTI-SENSOR FEATURE EXTRACTION
    // -------------------------------------------------------------

    // 1. Acceleration Metrics
    double sumMag = 0.0;
    double maxMag = samples[0].accelMagnitude;
    double minMag = samples[0].accelMagnitude;

    double sumUserMag = 0.0;
    double sumSqUserMag = 0.0;
    double maxUserMag = samples[0].userAccelMagnitude;

    // 2. Gyroscope Metrics
    double sumGyro = 0.0;
    double sumSqGyro = 0.0;
    double maxGyro = samples[0].gyroMagnitude;

    // 3. Gravity Alignment & Vertical User Acceleration
    double sumGravY = 0.0;
    double sumGravZ = 0.0;
    double maxVerticalUser = -999.0;
    double minVerticalUser = 999.0;

    for (final s in samples) {
      final aMag = s.accelMagnitude;
      final uMag = s.userAccelMagnitude;
      final gMag = s.gyroMagnitude;

      sumMag += aMag;
      if (aMag > maxMag) maxMag = aMag;
      if (aMag < minMag) minMag = aMag;

      sumUserMag += uMag;
      sumSqUserMag += uMag * uMag;
      if (uMag > maxUserMag) maxUserMag = uMag;

      sumGyro += gMag;
      sumSqGyro += gMag * gMag;
      if (gMag > maxGyro) maxGyro = gMag;

      sumGravY += s.gravityY.abs();
      sumGravZ += s.gravityZ.abs();

      // Estimate vertical user acceleration along gravity direction
      final gNorm = math.sqrt(
        s.gravityX * s.gravityX + s.gravityY * s.gravityY + s.gravityZ * s.gravityZ,
      );
      if (gNorm > 0.1) {
        final vert = (s.userAx * s.gravityX +
                s.userAy * s.gravityY +
                s.userAz * s.gravityZ) /
            gNorm;
        if (vert > maxVerticalUser) maxVerticalUser = vert;
        if (vert < minVerticalUser) minVerticalUser = vert;
      }
    }

    final meanMag = sumMag / n;
    final meanUserMag = sumUserMag / n;
    final meanGyro = sumGyro / n;
    final swing = maxMag - minMag;
    final rmsUserMag = math.sqrt(sumSqUserMag / n);
    final rmsGyro = math.sqrt(sumSqGyro / n);

    double varianceSum = 0.0;
    for (final s in samples) {
      final diff = s.accelMagnitude - meanMag;
      varianceSum += diff * diff;
    }
    final variance = varianceSum / n;
    final stdDev = math.sqrt(variance);

    // 4. Mean Jerk Metric: rate of change of 3D acceleration vector
    double sumJerk = 0.0;
    for (int i = 0; i < n - 1; i++) {
      final s1 = samples[i];
      final s2 = samples[i + 1];
      final dtMs = s2.timestamp.difference(s1.timestamp).inMilliseconds;
      final dtSec = (dtMs > 0 && dtMs < 200) ? (dtMs / 1000.0) : 0.02;
      final dax = s2.ax - s1.ax;
      final day = s2.ay - s1.ay;
      final daz = s2.az - s1.az;
      final deltaNorm = math.sqrt(dax * dax + day * day + daz * daz);
      sumJerk += deltaNorm / dtSec;
    }
    final meanJerk = (n > 1) ? (sumJerk / (n - 1)) : 0.0;

    // 5. Rotational Energy Ratio: Angular momentum vs Translational user energy
    // R = (mean_omega^2) / (mean_user_accel^2 + epsilon)
    final rotationalRatio = (rmsGyro * rmsGyro) / ((rmsUserMag * rmsUserMag) + 0.08);

    // 6. Cyclical Periodicity via Normalized Autocorrelation
    double periodicity = 0.0;
    if (n >= 15 && variance > 0.01) {
      // Mean-centered user acceleration series
      final y = List<double>.generate(n, (i) => samples[i].userAccelMagnitude - meanUserMag);
      double denom = 0.0;
      for (int i = 0; i < n; i++) {
        denom += y[i] * y[i];
      }

      if (denom > 1e-4) {
        // Gait lag range: covers human step frequencies (0.7 Hz to 3.5 Hz)
        final minLag = math.max(2, (n * 0.1).round());
        final maxLag = math.min(n - 2, (n * 0.6).round());

        double maxAutocorr = -1.0;
        for (int lag = minLag; lag <= maxLag; lag++) {
          double num = 0.0;
          for (int i = 0; i < n - lag; i++) {
            num += y[i] * y[i + lag];
          }
          final r = num / denom;
          if (r > maxAutocorr) maxAutocorr = r;
        }
        periodicity = math.max(0.0, maxAutocorr);
      }
    }

    final evidence = <String, dynamic>{
      'sample_count': n,
      'accel_variance': stdDev,
      'accel_swing': swing,
      'mean_user_mag': meanUserMag,
      'max_user_mag': maxUserMag,
      'mean_gyro': meanGyro,
      'max_gyro': maxGyro,
      'mean_jerk': meanJerk,
      'rotational_ratio': rotationalRatio,
      'periodicity': periodicity,
      'cadence': cadence,
      'mean_grav_y': sumGravY / n,
      'mean_grav_z': sumGravZ / n,
    };

    // -------------------------------------------------------------
    // LEVEL 2: BIOMECHANICAL CLASSIFICATION & EVIDENCE SCORING
    // -------------------------------------------------------------

    // A. Cycling: Smooth continuous angular rotation with minimal vertical foot-impact shock
    final isCyclingMotion = (meanGyro >= 0.65 &&
        meanGyro < 2.5 &&
        stdDev < 1.4 &&
        swing < 2.5 &&
        cadence < 30.0 &&
        meanUserMag >= 0.35);

    if (isCyclingMotion) {
      return WindowClassificationResult(
        activity: TwinActivityType.cycling,
        confidence: TwinSignalConfidence.medium,
        evidence: evidence,
      );
    }

    // B. FALSE-POSITIVE REJECTION: Isolated Phone Swing, Twist, or Random Shake
    // If rotational energy dominates or gyro spikes without genuine periodic translational gait:
    final isRotationalDominance = (rotationalRatio > 2.2 || maxGyro > 2.6 || meanGyro > 1.8);
    final hasPeriodicGait = (periodicity >= 0.30 && cadence >= 25.0) || cadence >= 45.0;

    if (isRotationalDominance && !hasPeriodicGait) {
      // User is waving, rotating, tossing, or swinging phone in hand!
      // Strictly REJECT from HIGH_ACTIVITY, WALKING, and RUNNING.
      return WindowClassificationResult(
        activity: TwinActivityType.other,
        confidence: TwinSignalConfidence.low,
        evidence: evidence,
        rejectionReason: 'DEVICE_SWING_ROTATION_REJECTED',
      );
    }

    // Erratic non-periodic high-jerk shake rejection
    if (meanJerk > 45.0 && periodicity < 0.22 && cadence < 30.0) {
      return WindowClassificationResult(
        activity: TwinActivityType.other,
        confidence: TwinSignalConfidence.low,
        evidence: evidence,
        rejectionReason: 'RANDOM_SHAKE_REJECTED',
      );
    }

    // B. Stationary & Posture (Sitting vs Standing)
    if (stdDev < 0.22 && meanUserMag < 0.35 && meanGyro < 0.25 && cadence < 15.0) {
      final meanGy = sumGravY / n;
      final meanGz = sumGravZ / n;

      // Check static orientation if motion is virtually zero
      if (stdDev < 0.08 && meanGyro < 0.12) {
        if (meanGy > 7.5 && meanGz < 3.0) {
          // Phone upright in portrait (e.g. standing with phone in pocket or held static)
          return WindowClassificationResult(
            activity: TwinActivityType.standing,
            confidence: TwinSignalConfidence.medium,
            evidence: evidence,
          );
        } else if (meanGz > 7.5 || (meanGy < 3.0 && meanGz < 4.0)) {
          // Phone horizontal / resting on flat thigh or table
          return WindowClassificationResult(
            activity: TwinActivityType.sitting,
            confidence: TwinSignalConfidence.medium,
            evidence: evidence,
          );
        }
      }

      return WindowClassificationResult(
        activity: TwinActivityType.stationary,
        confidence: TwinSignalConfidence.high,
        evidence: evidence,
      );
    }

    // C. Automotive: Low-frequency continuous vibration with zero cadence and low rotation
    if (stdDev >= 0.15 &&
        stdDev < 0.42 &&
        cadence == 0.0 &&
        meanGyro < 0.22 &&
        swing < 1.6 &&
        meanUserMag < 0.6) {
      return WindowClassificationResult(
        activity: TwinActivityType.automotive,
        confidence: TwinSignalConfidence.medium,
        evidence: evidence,
      );
    }

    // D. Cycling: Smooth continuous angular rotation with minimal vertical foot-impact shock
    if (meanGyro >= 0.65 &&
        meanGyro < 2.5 &&
        stdDev < 1.4 &&
        swing < 2.2 &&
        cadence < 30.0 &&
        meanUserMag >= 0.35) {
      return WindowClassificationResult(
        activity: TwinActivityType.cycling,
        confidence: TwinSignalConfidence.medium,
        evidence: evidence,
      );
    }

    // E. High Activity (Redefined): Sustained Vigorous Multi-Axis Body Workout
    // Requires: high user acceleration energy, elevated multi-axis variance,
    // sustained jerk, AND controlled rotational ratio (NOT isolated phone spin).
    if (stdDev >= 3.0 &&
        meanUserMag >= 2.0 &&
        swing >= 6.0 &&
        meanJerk >= 10.0 &&
        rotationalRatio < 2.5 &&
        maxGyro < 3.5) {
      return WindowClassificationResult(
        activity: TwinActivityType.highActivity,
        confidence: TwinSignalConfidence.high,
        evidence: evidence,
      );
    }

    // F. Running: High cadence or high acceleration dynamic swing with sustained periodicity
    if (cadence >= 140.0 ||
        (stdDev >= 1.8 &&
            swing >= 4.0 &&
            (periodicity >= 0.30 || cadence >= 90.0) &&
            maxGyro < 3.2)) {
      return WindowClassificationResult(
        activity: TwinActivityType.running,
        confidence: TwinSignalConfidence.high,
        evidence: evidence,
      );
    }

    // G. Stairs (Up / Down): Vertical acceleration asymmetry with step cadence
    if (cadence >= 40.0 && cadence <= 95.0 && periodicity >= 0.25) {
      final verticalRange = maxVerticalUser - minVerticalUser;
      if (verticalRange > 3.0) {
        // Downward landing shock vs upward push-off
        if (maxVerticalUser.abs() > minVerticalUser.abs() * 1.5) {
          return WindowClassificationResult(
            activity: TwinActivityType.stairsDown,
            confidence: TwinSignalConfidence.medium,
            evidence: evidence,
          );
        } else if (minVerticalUser.abs() > maxVerticalUser.abs() * 1.3) {
          return WindowClassificationResult(
            activity: TwinActivityType.stairsUp,
            confidence: TwinSignalConfidence.medium,
            evidence: evidence,
          );
        }
      }
    }

    // H. Brisk Walking: High cadence or elevated walking variance with high periodicity
    if (cadence >= 115.0 && cadence < 140.0 ||
        (stdDev >= 1.2 && stdDev < 2.2 && periodicity >= 0.35 && cadence >= 70.0)) {
      return WindowClassificationResult(
        activity: TwinActivityType.briskWalking,
        confidence: TwinSignalConfidence.high,
        evidence: evidence,
      );
    }

    // I. Walking: Standard periodic human gait
    if ((stdDev >= 0.22 && stdDev < 1.8 && (periodicity >= 0.25 || cadence >= 20.0)) ||
        (cadence >= 20.0 && cadence < 115.0)) {
      final conf = (cadence >= 40.0 || periodicity >= 0.35)
          ? TwinSignalConfidence.high
          : TwinSignalConfidence.medium;
      return WindowClassificationResult(
        activity: TwinActivityType.walking,
        confidence: conf,
        evidence: evidence,
      );
    }

    // J. Fallback
    return WindowClassificationResult(
      activity: TwinActivityType.other,
      confidence: TwinSignalConfidence.low,
      evidence: evidence,
    );
  }

  void _handleClassifiedWindow(WindowClassificationResult windowResult) {
    final now = DateTime.now();
    final windowActivity = windowResult.activity;

    if (windowActivity != TwinActivityType.stationary &&
        windowActivity != TwinActivityType.sitting &&
        windowActivity != TwinActivityType.standing) {
      _lastSignificantMotionTime = now;
    }

    // Temporal Hysteresis:
    // Track matching consecutive candidate windows
    if (windowActivity == _candidateActivity) {
      _consecutiveCandidateWindows++;
    } else {
      _candidateActivity = windowActivity;
      _candidateConfidence = windowResult.confidence;
      _candidateEvidence = windowResult.evidence;
      _consecutiveCandidateWindows = 1;
    }

    // Threshold of required consecutive windows:
    // High activity requires 3 consecutive confirmations (~4-8s) to prevent transient spikes
    final requiredWindows = (_candidateActivity == TwinActivityType.highActivity) ? 3 : 2;

    // Crosswalk Debounce:
    // If currently active (walking, running, stairs) and candidate is resting (stationary/sitting/standing),
    // hold active state during brief pedestrian pauses (e.g. traffic light)
    bool allowTransition = true;
    final isActiveState = _currentActivity == TwinActivityType.walking ||
        _currentActivity == TwinActivityType.briskWalking ||
        _currentActivity == TwinActivityType.running ||
        _currentActivity == TwinActivityType.stairsUp ||
        _currentActivity == TwinActivityType.stairsDown;

    final isRestingCandidate = _candidateActivity == TwinActivityType.stationary ||
        _candidateActivity == TwinActivityType.sitting ||
        _candidateActivity == TwinActivityType.standing;

    if (isActiveState && isRestingCandidate) {
      if (_lastSignificantMotionTime != null &&
          now.difference(_lastSignificantMotionTime!) < crosswalkDebounceDuration) {
        allowTransition = false; // Hold current active state
      }
    }

    if (_consecutiveCandidateWindows >= requiredWindows &&
        _candidateActivity != _currentActivity &&
        allowTransition) {
      _currentActivity = _candidateActivity;
      _currentActivityStartedAt = now;

      final signal = NormalizedActivity(
        activity: _currentActivity,
        startTime: now,
        durationSeconds: 0,
        confidence: _candidateConfidence,
        source: TwinSignalSource.phoneSensor,
        evidence: _candidateEvidence,
      );

      if (!_activityController.isClosed) {
        _activityController.add(signal);
      }
    } else if (_candidateActivity == _currentActivity &&
        _currentActivity != TwinActivityType.unknown) {
      // Periodic heartbeat signal every 25 matching windows updating duration
      if (_consecutiveCandidateWindows > 0 && _consecutiveCandidateWindows % 25 == 0) {
        final elapsed = now.difference(_currentActivityStartedAt).inSeconds;
        final signal = NormalizedActivity(
          activity: _currentActivity,
          startTime: _currentActivityStartedAt,
          durationSeconds: elapsed,
          confidence: _candidateConfidence,
          source: TwinSignalSource.phoneSensor,
          evidence: _candidateEvidence,
        );
        if (!_activityController.isClosed) {
          _activityController.add(signal);
        }
      }
    }
  }

  /// Manually reports platform activity (e.g. from Health Platform or external source).
  void reportPlatformActivity(
    TwinActivityType activity, {
    TwinSignalConfidence confidence = TwinSignalConfidence.high,
    TwinSignalSource source = TwinSignalSource.phoneSensor,
    String? deviceId,
    Map<String, dynamic>? evidence,
  }) {
    if (activity != _currentActivity) {
      final now = DateTime.now();
      _currentActivity = activity;
      _currentActivityStartedAt = now;

      final signal = NormalizedActivity(
        activity: _currentActivity,
        startTime: now,
        durationSeconds: 0,
        confidence: confidence,
        source: source,
        deviceId: deviceId,
        evidence: evidence,
      );

      if (!_activityController.isClosed) {
        _activityController.add(signal);
      }
    }
  }

  void stop() {
    _pipelineSub?.cancel();
    _pipelineSub = null;
    _sampleWindow.clear();
    _consecutiveCandidateWindows = 0;
  }

  void dispose() {
    stop();
    _activityController.close();
  }
}
