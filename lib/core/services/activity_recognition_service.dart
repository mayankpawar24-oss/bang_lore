import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum FlutterTwinActivityState {
  stationary,
  walking,
  running,
  cycling,
  automotive,
  other,
  unknown;

  String get label {
    switch (this) {
      case FlutterTwinActivityState.stationary:
        return 'Sitting / Still';
      case FlutterTwinActivityState.walking:
        return 'Walking';
      case FlutterTwinActivityState.running:
        return 'Running';
      case FlutterTwinActivityState.cycling:
        return 'Cycling';
      case FlutterTwinActivityState.automotive:
        return 'Driving / Transit';
      case FlutterTwinActivityState.other:
        return 'Active';
      case FlutterTwinActivityState.unknown:
        return 'Unknown';
    }
  }

  String toBackendString() {
    switch (this) {
      case FlutterTwinActivityState.stationary:
        return 'STATIONARY';
      case FlutterTwinActivityState.walking:
        return 'WALKING';
      case FlutterTwinActivityState.running:
        return 'RUNNING';
      case FlutterTwinActivityState.cycling:
        return 'CYCLING';
      case FlutterTwinActivityState.automotive:
        return 'AUTOMOTIVE';
      case FlutterTwinActivityState.other:
        return 'OTHER';
      case FlutterTwinActivityState.unknown:
        return 'UNKNOWN';
    }
  }

  static FlutterTwinActivityState fromBackendString(String? val) {
    if (val == null) return FlutterTwinActivityState.unknown;
    switch (val.toUpperCase()) {
      case 'STATIONARY':
        return FlutterTwinActivityState.stationary;
      case 'WALKING':
        return FlutterTwinActivityState.walking;
      case 'RUNNING':
        return FlutterTwinActivityState.running;
      case 'CYCLING':
        return FlutterTwinActivityState.cycling;
      case 'AUTOMOTIVE':
        return FlutterTwinActivityState.automotive;
      case 'OTHER':
        return FlutterTwinActivityState.other;
      default:
        return FlutterTwinActivityState.unknown;
    }
  }
}

enum ActivityPermissionStatus {
  granted,
  denied,
  restricted,
  unavailable;

  bool get isGranted => this == ActivityPermissionStatus.granted;
}

class ActivitySample {
  final FlutterTwinActivityState state;
  final DateTime timestamp;
  final Duration? duration;
  final String confidence;
  final String source;
  final String devicePlatform;

  const ActivitySample({
    required this.state,
    required this.timestamp,
    this.duration,
    this.confidence = 'HIGH',
    this.source = 'PHONE_SENSOR',
    this.devicePlatform = 'mobile',
  });
}

class ActivityRecognitionService {
  static final ActivityRecognitionService _instance = ActivityRecognitionService._internal();
  factory ActivityRecognitionService() => _instance;
  ActivityRecognitionService._internal();

  final _activityController = StreamController<ActivitySample>.broadcast();
  Stream<ActivitySample> get activityStream => _activityController.stream;

  ActivityPermissionStatus _permissionStatus = ActivityPermissionStatus.unavailable;
  ActivityPermissionStatus get permissionStatus => _permissionStatus;

  FlutterTwinActivityState _currentState = FlutterTwinActivityState.unknown;
  FlutterTwinActivityState get currentState => _currentState;

  DateTime? _stateStartedAt;
  DateTime? get stateStartedAt => _stateStartedAt;

  Timer? _pollingTimer;

  Future<ActivityPermissionStatus> checkPermission() async {
    if (kIsWeb) {
      _permissionStatus = ActivityPermissionStatus.unavailable;
      return _permissionStatus;
    }
    try {
      final status = await Permission.activityRecognition.status;
      if (status.isGranted) {
        _permissionStatus = ActivityPermissionStatus.granted;
      } else if (status.isPermanentlyDenied || status.isDenied) {
        _permissionStatus = ActivityPermissionStatus.denied;
      } else if (status.isRestricted) {
        _permissionStatus = ActivityPermissionStatus.restricted;
      } else {
        _permissionStatus = ActivityPermissionStatus.unavailable;
      }
    } catch (_) {
      _permissionStatus = ActivityPermissionStatus.unavailable;
    }
    return _permissionStatus;
  }

  Future<ActivityPermissionStatus> requestPermission() async {
    if (kIsWeb) {
      _permissionStatus = ActivityPermissionStatus.unavailable;
      return _permissionStatus;
    }
    try {
      final res = await Permission.activityRecognition.request();
      if (res.isGranted) {
        _permissionStatus = ActivityPermissionStatus.granted;
      } else if (res.isPermanentlyDenied || res.isDenied) {
        _permissionStatus = ActivityPermissionStatus.denied;
      } else {
        _permissionStatus = ActivityPermissionStatus.restricted;
      }
    } catch (_) {
      _permissionStatus = ActivityPermissionStatus.unavailable;
    }
    return _permissionStatus;
  }

  Future<void> start() async {
    await checkPermission();
    if (!_permissionStatus.isGranted) {
      return;
    }

    _pollingTimer?.cancel();
    // Periodic activity state monitoring
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _onActivitySampled(_currentState);
    });
  }

  void _onActivitySampled(FlutterTwinActivityState newState) {
    final now = DateTime.now();
    if (_currentState != newState) {
      _currentState = newState;
      _stateStartedAt = now;
    }

    final duration = _stateStartedAt != null ? now.difference(_stateStartedAt!) : Duration.zero;
    final sample = ActivitySample(
      state: _currentState,
      timestamp: now,
      duration: duration,
      confidence: 'HIGH',
      source: 'PHONE_SENSOR',
      devicePlatform: defaultTargetPlatform.name,
    );
    _activityController.add(sample);
  }

  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void dispose() {
    stop();
    _activityController.close();
  }
}