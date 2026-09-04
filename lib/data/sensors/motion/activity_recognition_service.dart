import 'dart:async';
import 'dart:math' as math;
import '../models/twin_sensor_signals.dart';
import 'phone_motion_pipeline.dart';

/// Classifies motion into normalized activity states locally using multi-sensor
/// windowed feature extraction from real phone accelerometer and gyroscope signals.
///
/// Ensures raw high-frequency sensor streams are processed entirely on-device,
/// emitting only structured, normalized activity events to TWIN.
class ActivityRecognitionService {
  final _activityController = StreamController<NormalizedActivity>.broadcast();
  StreamSubscription<SensorSample>? _pipelineSub;

  final int windowSampleCount;
  final List<SensorSample> _sampleWindow = [];

  TwinActivityType _currentActivity = TwinActivityType.unknown;
  DateTime _currentActivityStartedAt = DateTime.now();

  // Hysteresis & Stabilization State
  int _consecutiveCandidateWindows = 0;
  TwinActivityType _candidateActivity = TwinActivityType.unknown;
  DateTime? _lastSignificantMotionTime;
  double _currentCadence = 0.0;

  ActivityRecognitionService({this.windowSampleCount = 30});

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
      final classified = classifyWindow(List.from(_sampleWindow), cadence: _currentCadence);
      // Sliding window hop: retain 80% overlap for smooth, responsive state transitions
      const hopSize = 10;
      if (_sampleWindow.length > hopSize) {
        _sampleWindow.removeRange(0, hopSize);
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

  /// Classifies a window of [SensorSample]s into a [TwinActivityType].
  static TwinActivityType classifyWindow(List<SensorSample> samples, {double cadence = 0.0}) {
    if (samples.isEmpty) return TwinActivityType.unknown;

    final n = samples.length;

    // 1. Acceleration Metrics
    double sumMag = 0.0;
    double sumSqMag = 0.0;
    double maxMag = samples[0].accelMagnitude;
    double minMag = samples[0].accelMagnitude;

    double sumUserMag = 0.0;

    // 2. Gyroscope Metrics
    double sumGyro = 0.0;

    for (final s in samples) {
      final aMag = s.accelMagnitude;
      final uMag = s.userAccelMagnitude;
      final gMag = s.gyroMagnitude;

      sumMag += aMag;
      sumSqMag += aMag * aMag;
      if (aMag > maxMag) maxMag = aMag;
      if (aMag < minMag) minMag = aMag;

      sumUserMag += uMag;
      sumGyro += gMag;
    }

    final meanMag = sumMag / n;
    final rmsAccel = math.sqrt(sumSqMag / n);
    final meanUserMag = sumUserMag / n;
    final meanGyro = sumGyro / n;
    final swing = maxMag - minMag;

    double varianceSum = 0.0;
    for (final s in samples) {
      final diff = s.accelMagnitude - meanMag;
      varianceSum += diff * diff;
    }
    final variance = varianceSum / n;
    final stdDev = math.sqrt(variance);

    // 3. Multi-Feature Biomechanical Classification
    // A. Stationary: very low acceleration variance, low user motion, minimal rotation
    if (stdDev < 0.22 && meanUserMag < 0.35 && meanGyro < 0.25 && cadence < 15) {
      return TwinActivityType.stationary;
    }

    // B. Automotive: low-frequency continuous vibration with no cadence and flat user trajectory
    if (stdDev >= 0.15 && stdDev < 0.40 && cadence == 0 && meanGyro < 0.20 && swing < 1.6) {
      return TwinActivityType.automotive;
    }

    // C. Cycling: smooth periodic angular momentum with low vertical impact swing
    if (meanGyro > 0.8 && stdDev < 1.2 && cadence < 30 && meanUserMag > 0.4) {
      return TwinActivityType.cycling;
    }

    // D. High Activity: extreme variance, explosive acceleration, or very high RMS
    if (rmsAccel > 16.0 || stdDev >= 4.0 || maxMag >= 18.0) {
      return TwinActivityType.highActivity;
    }

    // E. Running: high acceleration variance, high swing, high cadence
    if (stdDev >= 1.8 && (stdDev < 4.0 && maxMag < 18.0) || cadence > 140) {
      return TwinActivityType.running;
    }

    // F. Walking: standard periodic human gait (moderate variance, rhythm, cadence > 0)
    if ((stdDev >= 0.22 && stdDev < 1.8 && maxMag < 16.0) || cadence >= 20) {
      return TwinActivityType.walking;
    }

    return TwinActivityType.other;
  }

  void _handleClassifiedWindow(TwinActivityType windowActivity) {
    final now = DateTime.now();

    if (windowActivity != TwinActivityType.stationary) {
      _lastSignificantMotionTime = now;
    }

    // Hysteresis State Machine:
    // Require 2 consecutive matching windows before switching candidates
    if (windowActivity == _candidateActivity) {
      _consecutiveCandidateWindows++;
    } else {
      _candidateActivity = windowActivity;
      _consecutiveCandidateWindows = 1;
    }

    // Debounce transition from WALKING to STATIONARY:
    // Ensure walking doesn't drop to stationary during a brief pause (e.g. stopping at crosswalk)
    bool allowTransition = true;
    if (_currentActivity == TwinActivityType.walking &&
        _candidateActivity == TwinActivityType.stationary) {
      if (_lastSignificantMotionTime != null &&
          now.difference(_lastSignificantMotionTime!).inSeconds < 4) {
        allowTransition = false; // Hold walking state during brief pauses
      }
    }

    if (_consecutiveCandidateWindows >= 2 &&
        _candidateActivity != _currentActivity &&
        allowTransition) {
      _currentActivity = _candidateActivity;
      _currentActivityStartedAt = now;

      final signal = NormalizedActivity(
        activity: _currentActivity,
        startTime: now,
        durationSeconds: 0,
        confidence: TwinSignalConfidence.high,
        source: TwinSignalSource.phoneSensor,
      );

      if (!_activityController.isClosed) {
        _activityController.add(signal);
      }
    } else if (_candidateActivity == _currentActivity &&
        _currentActivity != TwinActivityType.unknown) {
      // Heartbeat signal every 30 windows (~30-45s) updating active duration
      if (_consecutiveCandidateWindows > 0 && _consecutiveCandidateWindows % 30 == 0) {
        final elapsed = now.difference(_currentActivityStartedAt).inSeconds;
        final signal = NormalizedActivity(
          activity: _currentActivity,
          startTime: _currentActivityStartedAt,
          durationSeconds: elapsed,
          confidence: TwinSignalConfidence.high,
          source: TwinSignalSource.phoneSensor,
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
