import 'dart:async';
import '../models/twin_sensor_signals.dart';
import '../motion/phone_motion_pipeline.dart';
import 'adaptive_step_counter.dart';

enum StepSensorSource {
  internalHardwareSensors,
  nativePedometer,
  unavailable,
}

/// Service managing real phone step detection using internal accelerometer & gyroscope.
class PedometerService {
  final _stepController = StreamController<NormalizedStepCount>.broadcast();
  final _cadenceController = StreamController<double>.broadcast();
  final AdaptivePeakValleyStepCounter _counter;

  StreamSubscription<SensorSample>? _pipelineSub;
  StepSensorSource _activeSource = StepSensorSource.unavailable;
  int _currentSteps = 0;
  StepDetectionResult? _latestResult;

  PedometerService({AdaptivePeakValleyStepCounter? counter})
      : _counter = counter ?? AdaptivePeakValleyStepCounter();

  Stream<NormalizedStepCount> get stepStream => _stepController.stream;
  Stream<double> get cadenceStream => _cadenceController.stream;
  StepSensorSource get activeSource => _activeSource;
  int get currentSteps => _currentSteps;
  StepDetectionResult? get latestResult => _latestResult;
  AdaptivePeakValleyStepCounter get counter => _counter;

  /// Starts step detection using the internal [PhoneMotionPipeline].
  void start(PhoneMotionPipeline pipeline) {
    stop();
    _activeSource = StepSensorSource.internalHardwareSensors;

    _pipelineSub = pipeline.sampleStream.listen(
      (sample) {
        final result = _counter.processSensorSample(sample);
        _latestResult = result;

        if (!_cadenceController.isClosed) {
          _cadenceController.add(result.cadenceEstimate);
        }

        if (result.isStep) {
          _currentSteps++;
          final signal = NormalizedStepCount(
            steps: 1, // 1 step delta detected by internal hardware sensors
            timestamp: result.timestamp,
            source: TwinSignalSource.phoneSensor,
            isCumulative: false,
            confidence: result.confidence >= 0.8
                ? TwinSignalConfidence.high
                : TwinSignalConfidence.medium,
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
  }

  /// Resets daily step count (e.g. at local midnight).
  void reset() {
    _counter.reset();
    _currentSteps = 0;
    _latestResult = null;
  }

  void stop() {
    _pipelineSub?.cancel();
    _pipelineSub = null;
    _activeSource = StepSensorSource.unavailable;
  }

  void dispose() {
    stop();
    _stepController.close();
    _cadenceController.close();
  }
}
