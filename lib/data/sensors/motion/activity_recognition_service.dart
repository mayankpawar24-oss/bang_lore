import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

import '../models/twin_sensor_signals.dart';

/// Classifies motion into normalized activity states locally in windows.
///
/// Ensures raw high-frequency accelerometer/gyroscope data is NEVER streamed
/// to backend or Gemini, but aggregated locally into bounded activity events.
class ActivityRecognitionService {
  final _activityController = StreamController<NormalizedActivity>.broadcast();
  StreamSubscription<UserAccelerometerEvent>? _userAccelSubscription;

  final int windowSampleCount;
  final List<double> _windowMagnitudes = [];

  TwinActivityType _currentActivity = TwinActivityType.unknown;
  DateTime _currentActivityStartedAt = DateTime.now();
  int _consecutiveWindowCount = 0;
  TwinActivityType _candidateActivity = TwinActivityType.unknown;

  ActivityRecognitionService({this.windowSampleCount = 25});

  Stream<NormalizedActivity> get activityStream => _activityController.stream;
  TwinActivityType get currentActivity => _currentActivity;
  DateTime get currentActivityStartedAt => _currentActivityStartedAt;

  /// Starts listening to phone motion sensors for windowed activity classification.
  void start() {
    stop();
    _currentActivityStartedAt = DateTime.now();

    try {
      _userAccelSubscription = userAccelerometerEventStream().listen(
        (event) {
          // User accelerometer isolates movement from Earth's gravity (9.8 m/s^2)
          final mag = math.sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          _addSample(mag);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _addSample(double magnitude) {
    _windowMagnitudes.add(magnitude);

    if (_windowMagnitudes.length >= windowSampleCount) {
      final classified = classifyWindow(List.from(_windowMagnitudes));
      _windowMagnitudes.clear();
      _handleClassifiedWindow(classified);
    }
  }

  /// Classifies a window of acceleration magnitudes into a [TwinActivityType].
  static TwinActivityType classifyWindow(List<double> magnitudes) {
    if (magnitudes.isEmpty) return TwinActivityType.unknown;

    double sum = 0.0;
    for (final m in magnitudes) {
      sum += m;
    }
    final mean = sum / magnitudes.length;

    double varianceSum = 0.0;
    double maxVal = magnitudes[0];
    for (final m in magnitudes) {
      varianceSum += (m - mean) * (m - mean);
      if (m > maxVal) maxVal = m;
    }
    final variance = varianceSum / magnitudes.length;
    final stdDev = math.sqrt(variance);

    // Classification heuristics based on human biomechanics
    if (stdDev < 0.20 && mean < 0.35) {
      return TwinActivityType.stationary;
    } else if (stdDev >= 0.20 && stdDev < 1.8 && maxVal < 4.5) {
      return TwinActivityType.walking;
    } else if (stdDev >= 1.8 && (stdDev < 3.5 && maxVal < 8.0)) {
      return TwinActivityType.running;
    } else if (stdDev >= 3.5 || maxVal >= 8.0) {
      return TwinActivityType.highActivity;
    }

    return TwinActivityType.other;
  }

  /// Manually injects or reports a platform-recognized activity (e.g. from Android Activity Recognition / Apple CoreMotion).
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

  void _handleClassifiedWindow(TwinActivityType windowActivity) {
    if (windowActivity == _candidateActivity) {
      _consecutiveWindowCount++;
    } else {
      _candidateActivity = windowActivity;
      _consecutiveWindowCount = 1;
    }

    // Require 2 consecutive matching windows (debounce momentary jitter)
    if (_consecutiveWindowCount >= 2 && _candidateActivity != _currentActivity) {
      final now = DateTime.now();
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
    } else if (_candidateActivity == _currentActivity && _currentActivity != TwinActivityType.unknown) {
      // Periodic heartbeat every 30 consecutive windows (~45-60s) to keep activity duration live
      if (_consecutiveWindowCount > 0 && _consecutiveWindowCount % 30 == 0) {
        final now = DateTime.now();
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

  void stop() {
    _userAccelSubscription?.cancel();
    _userAccelSubscription = null;
    _windowMagnitudes.clear();
  }

  void dispose() {
    stop();
    _activityController.close();
  }
}
