import 'twin_sensor_signals.dart';

/// Comprehensive developer diagnostics snapshot for internal phone motion sensors.
class SensorDiagnosticsData {
  // Accelerometer Telemetry
  final bool accelReceiving;
  final int accelSampleCount;
  final DateTime? accelLastTimestamp;
  final double accelEstimatedHz;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double accelMagnitude;
  final double userAccelMagnitude;

  // Gyroscope Telemetry
  final bool gyroReceiving;
  final int gyroSampleCount;
  final DateTime? gyroLastTimestamp;
  final double gyroEstimatedHz;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double gyroMagnitude;

  // Processing Layer State
  final bool sensorStreamActive;
  final bool filteringActive;
  final bool stepDetectorActive;
  final bool activityClassifierActive;

  // Output State
  final int detectedSteps;
  final TwinActivityType currentActivity;
  final double confidence;
  final DateTime? lastTransitionTime;
  final DateTime? lastTwinSignalEmittedAt;
  final String activeStepSource;

  const SensorDiagnosticsData({
    this.accelReceiving = false,
    this.accelSampleCount = 0,
    this.accelLastTimestamp,
    this.accelEstimatedHz = 0.0,
    this.accelX = 0.0,
    this.accelY = 0.0,
    this.accelZ = 0.0,
    this.accelMagnitude = 0.0,
    this.userAccelMagnitude = 0.0,
    this.gyroReceiving = false,
    this.gyroSampleCount = 0,
    this.gyroLastTimestamp,
    this.gyroEstimatedHz = 0.0,
    this.gyroX = 0.0,
    this.gyroY = 0.0,
    this.gyroZ = 0.0,
    this.gyroMagnitude = 0.0,
    this.sensorStreamActive = false,
    this.filteringActive = false,
    this.stepDetectorActive = false,
    this.activityClassifierActive = false,
    this.detectedSteps = 0,
    this.currentActivity = TwinActivityType.unknown,
    this.confidence = 0.0,
    this.lastTransitionTime,
    this.lastTwinSignalEmittedAt,
    this.activeStepSource = 'PHONE_RAW_SENSOR_STEP_COUNT',
  });

  SensorDiagnosticsData copyWith({
    bool? accelReceiving,
    int? accelSampleCount,
    DateTime? accelLastTimestamp,
    double? accelEstimatedHz,
    double? accelX,
    double? accelY,
    double? accelZ,
    double? accelMagnitude,
    double? userAccelMagnitude,
    bool? gyroReceiving,
    int? gyroSampleCount,
    DateTime? gyroLastTimestamp,
    double? gyroEstimatedHz,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? gyroMagnitude,
    bool? sensorStreamActive,
    bool? filteringActive,
    bool? stepDetectorActive,
    bool? activityClassifierActive,
    int? detectedSteps,
    TwinActivityType? currentActivity,
    double? confidence,
    DateTime? lastTransitionTime,
    DateTime? lastTwinSignalEmittedAt,
    String? activeStepSource,
  }) {
    return SensorDiagnosticsData(
      accelReceiving: accelReceiving ?? this.accelReceiving,
      accelSampleCount: accelSampleCount ?? this.accelSampleCount,
      accelLastTimestamp: accelLastTimestamp ?? this.accelLastTimestamp,
      accelEstimatedHz: accelEstimatedHz ?? this.accelEstimatedHz,
      accelX: accelX ?? this.accelX,
      accelY: accelY ?? this.accelY,
      accelZ: accelZ ?? this.accelZ,
      accelMagnitude: accelMagnitude ?? this.accelMagnitude,
      userAccelMagnitude: userAccelMagnitude ?? this.userAccelMagnitude,
      gyroReceiving: gyroReceiving ?? this.gyroReceiving,
      gyroSampleCount: gyroSampleCount ?? this.gyroSampleCount,
      gyroLastTimestamp: gyroLastTimestamp ?? this.gyroLastTimestamp,
      gyroEstimatedHz: gyroEstimatedHz ?? this.gyroEstimatedHz,
      gyroX: gyroX ?? this.gyroX,
      gyroY: gyroY ?? this.gyroY,
      gyroZ: gyroZ ?? this.gyroZ,
      gyroMagnitude: gyroMagnitude ?? this.gyroMagnitude,
      sensorStreamActive: sensorStreamActive ?? this.sensorStreamActive,
      filteringActive: filteringActive ?? this.filteringActive,
      stepDetectorActive: stepDetectorActive ?? this.stepDetectorActive,
      activityClassifierActive: activityClassifierActive ?? this.activityClassifierActive,
      detectedSteps: detectedSteps ?? this.detectedSteps,
      currentActivity: currentActivity ?? this.currentActivity,
      confidence: confidence ?? this.confidence,
      lastTransitionTime: lastTransitionTime ?? this.lastTransitionTime,
      lastTwinSignalEmittedAt: lastTwinSignalEmittedAt ?? this.lastTwinSignalEmittedAt,
      activeStepSource: activeStepSource ?? this.activeStepSource,
    );
  }
}
