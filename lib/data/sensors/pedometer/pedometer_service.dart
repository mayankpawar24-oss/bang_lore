import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/twin_sensor_signals.dart';
import 'adaptive_step_counter.dart';

enum StepSensorSource {
  nativePedometer,
  rawSensorFallback,
  unavailable,
}

/// Service managing step telemetry with system pedometer and adaptive fallback.
class PedometerService {
  final _stepController = StreamController<NormalizedStepCount>.broadcast();
  final AdaptivePeakValleyStepCounter _fallbackCounter;

  StreamSubscription<StepCount>? _nativePedometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  StepSensorSource _activeSource = StepSensorSource.unavailable;
  int _currentSteps = 0;
  int? _initialNativeOffset;

  PedometerService({AdaptivePeakValleyStepCounter? fallbackCounter})
      : _fallbackCounter = fallbackCounter ?? AdaptivePeakValleyStepCounter();

  Stream<NormalizedStepCount> get stepStream => _stepController.stream;
  StepSensorSource get activeSource => _activeSource;
  int get currentSteps => _currentSteps;

  /// Starts step counting, attempting native system pedometer first.
  Future<void> start() async {
    stop();

    try {
      // 1. Attempt system pedometer stream
      _nativePedometerSubscription = Pedometer.stepCountStream.listen(
        _handleNativeStepCount,
        onError: (err) {
          // Native pedometer failed (unsupported hardware or permission denied)
          _startRawSensorFallback();
        },
      );
      _activeSource = StepSensorSource.nativePedometer;
    } catch (_) {
      _startRawSensorFallback();
    }
  }

  void _handleNativeStepCount(StepCount event) {
    _activeSource = StepSensorSource.nativePedometer;

    // The native pedometer reports steps since last phone reboot.
    // We calibrate so steps are cumulative for today's session.
    _initialNativeOffset ??= event.steps;

    _currentSteps = event.steps - _initialNativeOffset!;
    if (_currentSteps < 0) _currentSteps = 0;

    final signal = NormalizedStepCount(
      steps: _currentSteps,
      timestamp: event.timeStamp,
      source: TwinSignalSource.phoneSensor,
      isCumulative: true,
      confidence: TwinSignalConfidence.high,
    );

    if (!_stepController.isClosed) {
      _stepController.add(signal);
    }
  }

  void _startRawSensorFallback() {
    _nativePedometerSubscription?.cancel();
    _nativePedometerSubscription = null;
    _activeSource = StepSensorSource.rawSensorFallback;

    try {
      _accelerometerSubscription = accelerometerEventStream().listen(
        (event) {
          final sample = AccelerometerSample(
            x: event.x,
            y: event.y,
            z: event.z,
            timestamp: DateTime.now(),
          );

          final result = _fallbackCounter.processSample(sample);
          if (result.isStep) {
            _currentSteps = result.totalSteps;
            final signal = NormalizedStepCount(
              steps: _currentSteps,
              timestamp: DateTime.now(),
              source: TwinSignalSource.phoneSensor,
              isCumulative: true,
              confidence: result.confidence >= 0.8
                  ? TwinSignalConfidence.medium
                  : TwinSignalConfidence.low,
            );

            if (!_stepController.isClosed) {
              _stepController.add(signal);
            }
          }
        },
        onError: (_) {
          _activeSource = StepSensorSource.unavailable;
        },
      );
    } catch (_) {
      _activeSource = StepSensorSource.unavailable;
    }
  }

  void stop() {
    _nativePedometerSubscription?.cancel();
    _nativePedometerSubscription = null;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _activeSource = StepSensorSource.unavailable;
  }

  void dispose() {
    stop();
    _stepController.close();
  }
}
