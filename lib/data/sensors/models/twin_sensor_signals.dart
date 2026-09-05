import 'package:uuid/uuid.dart';

enum TwinActivityType {
  stationary('STATIONARY', 'Stationary'),
  sitting('SITTING', 'Sitting'),
  standing('STANDING', 'Standing'),
  walking('WALKING', 'Walking'),
  briskWalking('BRISK_WALKING', 'Brisk Walking'),
  running('RUNNING', 'Running'),
  stairsUp('STAIRS_UP', 'Climbing Stairs'),
  stairsDown('STAIRS_DOWN', 'Descending Stairs'),
  cycling('CYCLING', 'Cycling'),
  automotive('AUTOMOTIVE', 'In Vehicle'),
  highActivity('HIGH_ACTIVITY', 'High Activity'),
  other('OTHER', 'Active'),
  unknown('UNKNOWN', 'Unknown');

  final String value;
  final String label;
  const TwinActivityType(this.value, this.label);

  static TwinActivityType fromString(String? val) {
    if (val == null) return TwinActivityType.unknown;
    final upper = val.toUpperCase().trim();
    for (final type in TwinActivityType.values) {
      if (type.value == upper) return type;
    }
    return TwinActivityType.unknown;
  }
}

enum TwinSignalSource {
  phoneSensor('PHONE_SENSOR'),
  watch('WATCH'),
  healthConnect('HEALTH_CONNECT'),
  healthKit('HEALTHKIT'),
  ble('BLE'),
  esp32('ESP32'),
  chat('CHAT'),
  clinicalSystem('CLINICAL_SYSTEM'),
  userInput('USER_INPUT'),
  unknown('UNKNOWN');

  final String value;
  const TwinSignalSource(this.value);

  static TwinSignalSource fromString(String? val) {
    if (val == null) return TwinSignalSource.unknown;
    final upper = val.toUpperCase().trim();
    for (final s in TwinSignalSource.values) {
      if (s.value == upper) return s;
    }
    return TwinSignalSource.unknown;
  }
}

enum TwinSignalConfidence {
  high('HIGH'),
  medium('MEDIUM'),
  low('LOW'),
  unknown('UNKNOWN');

  final String value;
  const TwinSignalConfidence(this.value);
}

class NormalizedHeartRate {
  final double bpm;
  final DateTime timestamp;
  final TwinSignalSource source;
  final String? deviceId;
  final String? sensorLocation;
  final bool? sensorContact;
  final int? energyExpendedKj;
  final List<double> rrIntervalsMs;
  final TwinSignalConfidence confidence;

  const NormalizedHeartRate({
    required this.bpm,
    required this.timestamp,
    this.source = TwinSignalSource.ble,
    this.deviceId,
    this.sensorLocation,
    this.sensorContact,
    this.energyExpendedKj,
    this.rrIntervalsMs = const [],
    this.confidence = TwinSignalConfidence.high,
  });

  Map<String, dynamic> toTwinSignal(String patientId) {
    return {
      'signal_id': 'sig_hr_${const Uuid().v4()}',
      'patient_id': patientId,
      'signal_type': 'HEART_RATE_UPDATED',
      'timestamp': timestamp.toUtc().toIso8601String(),
      'source': source.value,
      'confidence': confidence.value,
      'heart_rate': bpm,
      'metadata': {
        if (deviceId != null) 'device_id': deviceId,
        if (sensorLocation != null) 'sensor_location': sensorLocation,
        if (sensorContact != null) 'sensor_contact': sensorContact,
        if (energyExpendedKj != null) 'energy_expended_kj': energyExpendedKj,
        if (rrIntervalsMs.isNotEmpty) 'rr_intervals_ms': rrIntervalsMs,
      },
    };
  }
}

class NormalizedActivity {
  final TwinActivityType activity;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final TwinSignalConfidence confidence;
  final TwinSignalSource source;
  final String? deviceId;
  final Map<String, dynamic>? evidence;

  const NormalizedActivity({
    required this.activity,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    this.confidence = TwinSignalConfidence.high,
    this.source = TwinSignalSource.phoneSensor,
    this.deviceId,
    this.evidence,
  });

  Map<String, dynamic> toTwinSignal(String patientId, {String? platform}) {
    final dur = durationSeconds ??
        endTime?.difference(startTime).inSeconds.clamp(0, 86400);
    return {
      'signal_id': 'sig_act_${const Uuid().v4()}',
      'patient_id': patientId,
      'signal_type': 'ACTIVITY_CHANGED',
      'timestamp': startTime.toUtc().toIso8601String(),
      'source': source.value,
      'confidence': confidence.value,
      'activity_state': activity.value,
      if (dur != null) 'duration_seconds': dur,
      'metadata': {
        if (deviceId != null) 'device_id': deviceId,
        'device_platform': deviceId ?? platform ?? 'phone',
        if (endTime != null) 'end_time': endTime!.toUtc().toIso8601String(),
        if (evidence != null) 'evidence': evidence,
      },
    };
  }
}

class NormalizedStepCount {
  final int steps;
  final DateTime timestamp;
  final TwinSignalSource source;
  final String? deviceId;
  final bool isCumulative;
  final TwinSignalConfidence confidence;

  const NormalizedStepCount({
    required this.steps,
    required this.timestamp,
    this.source = TwinSignalSource.phoneSensor,
    this.deviceId,
    this.isCumulative = true,
    this.confidence = TwinSignalConfidence.high,
  });

  Map<String, dynamic> toTwinSignal(String patientId) {
    return {
      'signal_id': 'sig_step_${const Uuid().v4()}',
      'patient_id': patientId,
      'signal_type': 'STEP_PROGRESS_UPDATED',
      'timestamp': timestamp.toUtc().toIso8601String(),
      'source': source.value,
      'confidence': confidence.value,
      'steps': steps,
      'metadata': {
        if (deviceId != null) 'device_id': deviceId,
        'is_cumulative': isCumulative,
      },
    };
  }
}

class NormalizedEnvironment {
  final String metric; // 'temperature' or 'humidity'
  final double value;
  final String unit; // '°C' or '%'
  final DateTime timestamp;
  final TwinSignalSource source;
  final String? deviceId;

  const NormalizedEnvironment({
    required this.metric,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.source = TwinSignalSource.esp32,
    this.deviceId,
  });

  Map<String, dynamic> toTwinSignal(String patientId) {
    return {
      'signal_id': 'sig_env_${const Uuid().v4()}',
      'patient_id': patientId,
      'signal_type': 'ENVIRONMENT_UPDATED',
      'timestamp': timestamp.toUtc().toIso8601String(),
      'source': source.value,
      'confidence': 'HIGH',
      'metadata': {
        'metric': metric,
        'value': value,
        'unit': unit,
        metric: value,
        '${metric}_unit': unit,
        if (deviceId != null) 'device_id': deviceId,
      },
    };
  }
}
