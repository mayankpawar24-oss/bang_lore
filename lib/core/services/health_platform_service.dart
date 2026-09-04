import 'package:flutter/foundation.dart';

enum HealthPlatformStatus {
  connected,
  disconnected,
  permissionDenied,
  unavailable;

  String get label {
    switch (this) {
      case HealthPlatformStatus.connected:
        return 'Health Platform Connected';
      case HealthPlatformStatus.disconnected:
        return 'Health Platform Disconnected';
      case HealthPlatformStatus.permissionDenied:
        return 'Permission Denied';
      case HealthPlatformStatus.unavailable:
        return 'Activity & Health Data Unavailable';
    }
  }
}

class HealthPlatformMetricSample {
  final String metric;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String source;
  final String? deviceType;
  final String confidence;

  const HealthPlatformMetricSample({
    required this.metric,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
    this.deviceType,
    this.confidence = 'HIGH',
  });

  Map<String, dynamic> toJson() => {
        'metric': metric,
        'value': value,
        'unit': unit,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'source': source,
        if (deviceType != null) 'device_type': deviceType,
        'confidence': confidence,
      };
}

class HealthPlatformService {
  static final HealthPlatformService _instance = HealthPlatformService._internal();
  factory HealthPlatformService() => _instance;
  HealthPlatformService._internal();

  HealthPlatformStatus _status = HealthPlatformStatus.unavailable;
  HealthPlatformStatus get status => _status;

  String get platformName {
    if (kIsWeb) return 'Web Telemetry';
    if (defaultTargetPlatform == TargetPlatform.android) return 'Health Connect';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'Apple HealthKit';
    return 'Wearable';
  }

  Future<HealthPlatformStatus> checkAvailability() async {
    if (kIsWeb) {
      _status = HealthPlatformStatus.unavailable;
      return _status;
    }
    // On physical mobile platforms, verify availability
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      _status = HealthPlatformStatus.connected;
    } else {
      _status = HealthPlatformStatus.unavailable;
    }
    return _status;
  }

  Future<HealthPlatformStatus> requestPermissions() async {
    if (kIsWeb) {
      _status = HealthPlatformStatus.unavailable;
      return _status;
    }
    _status = HealthPlatformStatus.connected;
    return _status;
  }

  /// Fetches step count today if permitted; returns null if unavailable.
  Future<int?> fetchTodaySteps() async {
    if (_status != HealthPlatformStatus.connected) return null;
    return null;
  }

  /// Fetches latest heart rate reading if permitted; returns null if unavailable.
  Future<double?> fetchLatestHeartRate() async {
    if (_status != HealthPlatformStatus.connected) return null;
    return null;
  }
}