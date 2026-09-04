import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/backend_service.dart';
import 'ble/ble_device_manager.dart';
import 'ble/heart_rate_ble_adapter.dart';
import 'health/health_platform_service.dart';
import 'iot/esp32_environment_adapter.dart';
import 'models/twin_sensor_signals.dart';
import 'motion/activity_recognition_service.dart';
import 'pedometer/pedometer_service.dart';
import 'reconciliation/sensor_data_reconciler.dart';

/// Master coordinator managing hardware sensor adapters, data normalization,
/// deduplication, local buffering, offline resilience, and TWIN backend ingestion.
class TwinSensorCoordinator {
  final String patientId;
  final BackendService backendService;

  final HeartRateBleAdapter heartRateAdapter;
  final Esp32EnvironmentAdapter esp32Adapter;
  final PedometerService pedometerService;
  final ActivityRecognitionService activityService;
  final IHealthPlatformService healthPlatformService;
  final SensorDataReconciler reconciler;

  // Reactive UI state notifiers
  final ValueNotifier<TwinActivityType> currentActivityNotifier =
      ValueNotifier(TwinActivityType.unknown);
  final ValueNotifier<int> currentStepsNotifier = ValueNotifier(0);
  final ValueNotifier<NormalizedHeartRate?> currentHeartRateNotifier =
      ValueNotifier(null);
  final ValueNotifier<double?> currentTemperatureNotifier = ValueNotifier(null);
  final ValueNotifier<double?> currentHumidityNotifier = ValueNotifier(null);
  final ValueNotifier<BleDeviceStatus> bleHrStatusNotifier =
      ValueNotifier(BleDeviceStatus.disconnected);
  final ValueNotifier<BleDeviceStatus> esp32StatusNotifier =
      ValueNotifier(BleDeviceStatus.disconnected);
  final ValueNotifier<HealthPlatformStatus> healthStatusNotifier =
      ValueNotifier(HealthPlatformStatus.unavailable);

  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];
  Timer? _batchFlushTimer;
  Timer? _periodicHealthSyncTimer;

  // Signal transmission queue (offline resilience)
  final List<Map<String, dynamic>> _signalQueue = [];
  static const int _maxQueueSize = 50;
  bool _isFlushing = false;

  TwinSensorCoordinator({
    required this.patientId,
    required this.backendService,
    HeartRateBleAdapter? heartRateAdapter,
    Esp32EnvironmentAdapter? esp32Adapter,
    PedometerService? pedometerService,
    ActivityRecognitionService? activityService,
    IHealthPlatformService? healthPlatformService,
    SensorDataReconciler? reconciler,
  })  : heartRateAdapter = heartRateAdapter ?? HeartRateBleAdapter(),
        esp32Adapter = esp32Adapter ?? Esp32EnvironmentAdapter(),
        pedometerService = pedometerService ?? PedometerService(),
        activityService = activityService ?? ActivityRecognitionService(),
        healthPlatformService =
            healthPlatformService ?? HealthPlatformService(),
        reconciler = reconciler ?? SensorDataReconciler();

  /// Initializes all sensors, connects streams, and starts background synchronization.
  Future<void> initialize() async {
    // 1. Listen to BLE Heart Rate
    _subscriptions.add(
      heartRateAdapter.heartRateStream.listen(_onHeartRateReceived),
    );
    _subscriptions.add(
      heartRateAdapter.statusStream.listen((status) {
        bleHrStatusNotifier.value = status;
      }),
    );

    // 2. Listen to ESP32 Environment Telemetry
    _subscriptions.add(
      esp32Adapter.environmentStream.listen(_onEnvironmentReceived),
    );
    _subscriptions.add(
      esp32Adapter.statusStream.listen((status) {
        esp32StatusNotifier.value = status;
      }),
    );

    // 3. Listen to Pedometer
    _subscriptions.add(
      pedometerService.stepStream.listen(_onStepsReceived),
    );

    // 4. Listen to Motion Activity Recognition
    _subscriptions.add(
      activityService.activityStream.listen(_onActivityReceived),
    );

    // 5. Check Health Platform Status
    final status = await healthPlatformService.checkStatus();
    healthStatusNotifier.value = status;

    // Start local sensor streams
    await pedometerService.start();
    activityService.start();

    // Start batch flusher (every 15 seconds)
    _batchFlushTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => flushQueue(),
    );

    // Start periodic HealthKit / Health Connect sync (every 5 minutes)
    _periodicHealthSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncHealthPlatform(),
    );

    // Initial platform sync
    if (status == HealthPlatformStatus.permissionsGranted) {
      await syncHealthPlatform();
    }
  }

  void _onHeartRateReceived(NormalizedHeartRate hr) {
    final reconciled = reconciler.reconcileHeartRate(hr);
    if (reconciled != null) {
      currentHeartRateNotifier.value = reconciled;
      _enqueueSignal(reconciled.toTwinSignal(patientId));
    }
  }

  void _onEnvironmentReceived(NormalizedEnvironment env) {
    if (env.metric == 'temperature') {
      currentTemperatureNotifier.value = env.value;
    } else if (env.metric == 'humidity') {
      currentHumidityNotifier.value = env.value;
    }
    _enqueueSignal(env.toTwinSignal(patientId));
  }

  void _onStepsReceived(NormalizedStepCount steps) {
    final reconciled = reconciler.reconcileSteps(steps);
    if (reconciled != null) {
      currentStepsNotifier.value = reconciled.steps;
      _enqueueSignal(reconciled.toTwinSignal(patientId));
    }
  }

  void _onActivityReceived(NormalizedActivity act) {
    currentActivityNotifier.value = act.activity;
    _enqueueSignal(act.toTwinSignal(patientId));
  }

  /// Synchronizes data from Apple HealthKit or Android Health Connect.
  Future<void> syncHealthPlatform() async {
    final snapshot = await healthPlatformService.fetchSnapshot();
    final pSource = healthPlatformService.platformSource;

    // Sync steps
    if (snapshot.stepsToday != null) {
      final stepSignal = NormalizedStepCount(
        steps: snapshot.stepsToday!,
        timestamp: DateTime.now(),
        source: pSource,
        isCumulative: true,
      );
      _onStepsReceived(stepSignal);
    }

    // Sync heart rate (if fresh)
    if (snapshot.heartRateBpm != null && !snapshot.isHeartRateStale) {
      final hrSignal = NormalizedHeartRate(
        bpm: snapshot.heartRateBpm!,
        timestamp: snapshot.heartRateTimestamp ?? DateTime.now(),
        source: pSource,
        confidence: TwinSignalConfidence.high,
      );
      _onHeartRateReceived(hrSignal);
    }
  }

  void _enqueueSignal(Map<String, dynamic> signalMap) {
    _signalQueue.add(signalMap);
    if (_signalQueue.length > _maxQueueSize) {
      _signalQueue.removeAt(0); // Bounded in-memory FIFO
    }
  }

  /// Flushes queued signals to the backend TWIN endpoint.
  Future<void> flushQueue() async {
    if (_isFlushing || _signalQueue.isEmpty) return;
    _isFlushing = true;

    final inFlight = List<Map<String, dynamic>>.from(_signalQueue);
    _signalQueue.clear();

    try {
      final result = await backendService.sendTwinSignals(patientId, inFlight);
      if (result == null) {
        // Backend returned failure status; restore in-flight signals
        _restoreInFlight(inFlight);
      }
    } catch (_) {
      // Network failure; restore in-flight signals for retry
      _restoreInFlight(inFlight);
    } finally {
      _isFlushing = false;
    }
  }

  void _restoreInFlight(List<Map<String, dynamic>> failedItems) {
    _signalQueue.insertAll(0, failedItems);
    while (_signalQueue.length > _maxQueueSize) {
      _signalQueue.removeLast();
    }
  }

  // Device management convenience APIs for UI

  Stream<DiscoveredBleDevice> scanHeartRateMonitors() {
    return heartRateAdapter.scanForHeartRateMonitors();
  }

  Future<void> connectHeartRateMonitor(String deviceId) async {
    await heartRateAdapter.connect(deviceId);
  }

  Future<void> disconnectHeartRateMonitor() async {
    await heartRateAdapter.disconnect();
  }

  Stream<DiscoveredBleDevice> scanEsp32Sensors() {
    return esp32Adapter.scanForEsp32Sensors();
  }

  Future<void> connectEsp32(String deviceId) async {
    await esp32Adapter.connect(deviceId);
  }

  Future<void> disconnectEsp32() async {
    await esp32Adapter.disconnect();
  }

  Future<bool> requestHealthPermissions() async {
    final granted = await healthPlatformService.requestPermissions();
    healthStatusNotifier.value = granted
        ? HealthPlatformStatus.permissionsGranted
        : HealthPlatformStatus.permissionsDenied;
    if (granted) {
      await syncHealthPlatform();
    }
    return granted;
  }

  void dispose() {
    _batchFlushTimer?.cancel();
    _periodicHealthSyncTimer?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();

    heartRateAdapter.dispose();
    esp32Adapter.dispose();
    pedometerService.dispose();
    activityService.dispose();

    currentActivityNotifier.dispose();
    currentStepsNotifier.dispose();
    currentHeartRateNotifier.dispose();
    currentTemperatureNotifier.dispose();
    currentHumidityNotifier.dispose();
    bleHrStatusNotifier.dispose();
    esp32StatusNotifier.dispose();
    healthStatusNotifier.dispose();
  }
}
