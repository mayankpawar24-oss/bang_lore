import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/twin_state_model.dart';
import '../services/backend_service.dart';
import 'ble/ble_device_manager.dart';
import 'ble/heart_rate_ble_adapter.dart';
import 'health/health_platform_service.dart';
import 'iot/esp32_environment_adapter.dart';
import 'models/sensor_diagnostics_model.dart';
import 'models/twin_sensor_signals.dart';
import 'motion/activity_recognition_service.dart';
import 'motion/phone_motion_pipeline.dart';
import 'pedometer/pedometer_service.dart';
import 'reconciliation/sensor_data_reconciler.dart';

/// Master coordinator managing hardware sensor adapters, data normalization,
/// deduplication, local buffering, offline resilience, and TWIN backend ingestion.
class TwinSensorCoordinator {
  final String patientId;
  final BackendService backendService;

  final PhoneMotionPipeline motionPipeline;
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
  final ValueNotifier<double?> currentSpo2Notifier = ValueNotifier(null);
  final ValueNotifier<double?> currentTemperatureNotifier = ValueNotifier(null);
  final ValueNotifier<double?> currentHumidityNotifier = ValueNotifier(null);
  final ValueNotifier<BleDeviceStatus> bleHrStatusNotifier =
      ValueNotifier(BleDeviceStatus.disconnected);
  final ValueNotifier<BleDeviceStatus> esp32StatusNotifier =
      ValueNotifier(BleDeviceStatus.disconnected);
  final ValueNotifier<HealthPlatformStatus> healthStatusNotifier =
      ValueNotifier(HealthPlatformStatus.unavailable);
  final ValueNotifier<TwinStateModel?> twinStateNotifier =
      ValueNotifier(null);

  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];
  Timer? _batchFlushTimer;
  Timer? _periodicHealthSyncTimer;

  // Signal transmission queue (offline resilience)
  final List<Map<String, dynamic>> _signalQueue = [];
  static const int _maxQueueSize = 50;
  bool _isFlushing = false;
  bool _isInitialized = false;

  TwinSensorCoordinator({
    required this.patientId,
    required this.backendService,
    PhoneMotionPipeline? motionPipeline,
    HeartRateBleAdapter? heartRateAdapter,
    Esp32EnvironmentAdapter? esp32Adapter,
    PedometerService? pedometerService,
    ActivityRecognitionService? activityService,
    IHealthPlatformService? healthPlatformService,
    SensorDataReconciler? reconciler,
  })  : motionPipeline = motionPipeline ?? PhoneMotionPipeline(),
        heartRateAdapter = heartRateAdapter ?? HeartRateBleAdapter(),
        esp32Adapter = esp32Adapter ?? Esp32EnvironmentAdapter(),
        pedometerService = pedometerService ?? PedometerService(),
        activityService = activityService ?? ActivityRecognitionService(),
        healthPlatformService =
            healthPlatformService ?? HealthPlatformService(),
        reconciler = reconciler ?? SensorDataReconciler();

  ValueNotifier<SensorDiagnosticsData> get diagnosticsNotifier =>
      motionPipeline.diagnosticsNotifier;

  /// Initializes all sensors, connects streams, and starts background synchronization.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

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
    _subscriptions.add(
      pedometerService.cadenceStream.listen((cadence) {
        activityService.updateCadence(cadence);
        motionPipeline.updateProcessorDiagnostics(
          currentCadence: cadence,
        );
      }),
    );

    // 4. Listen to Motion Activity Recognition
    _subscriptions.add(
      activityService.activityStream.listen(_onActivityReceived),
    );

    // 5. Start Phone Internal Accelerometer + Gyroscope Motion Pipeline
    motionPipeline.start();
    pedometerService.start(motionPipeline);
    activityService.start(motionPipeline);

    motionPipeline.updateProcessorDiagnostics(
      stepDetectorActive: true,
      activityClassifierActive: true,
    );

    // 6. Check Health Platform Status
    final status = await healthPlatformService.checkStatus();
    healthStatusNotifier.value = status;

    // 7. Start batch flusher (every 15 seconds)
    _batchFlushTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => flushQueue(),
    );

    // 8. Start periodic HealthKit / Health Connect sync (every 5 minutes)
    _periodicHealthSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncHealthPlatform(),
    );

    // Initial platform sync if permitted
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

  /// Seeds today's baseline steps from backend TWIN state so new sensor steps accumulate accurately.
  void seedInitialSteps(int steps) {
    if (steps > 0) {
      reconciler.seedDailySteps(steps);
      if (currentStepsNotifier.value < steps) {
        currentStepsNotifier.value = steps;
      }
    }
  }

  void _onStepsReceived(NormalizedStepCount steps) {
    final reconciled = reconciler.reconcileSteps(steps);
    if (reconciled != null) {
      currentStepsNotifier.value = reconciled.steps;
      motionPipeline.updateProcessorDiagnostics(
        detectedSteps: reconciled.steps,
        lastTwinSignalEmittedAt: reconciled.timestamp,
      );
      _enqueueSignal(reconciled.toTwinSignal(patientId));
    }
  }

  void _onActivityReceived(NormalizedActivity act) {
    currentActivityNotifier.value = act.activity;
    motionPipeline.updateProcessorDiagnostics(
      currentActivity: act.activity,
      lastTransitionTime: act.startTime,
      lastTwinSignalEmittedAt: act.startTime,
    );
    _enqueueSignal(act.toTwinSignal(patientId));
  }

  /// Manually or externally report SpO2 from a connected oximeter
  void reportSpo2(double spo2, {String source = 'BLE', String confidence = 'HIGH'}) {
    currentSpo2Notifier.value = spo2;
    final now = DateTime.now().toUtc();
    _enqueueSignal({
      'patient_id': patientId,
      'signal_type': 'SPO2',
      'source': source,
      'metric': 'spo2',
      'value': spo2,
      'unit': '%',
      'confidence': confidence,
      'timestamp': now.toIso8601String(),
    });
  }

  /// Synchronizes background health platform records (HealthKit / Health Connect).
  Future<void> syncHealthPlatform() async {
    final status = await healthPlatformService.checkStatus();
    healthStatusNotifier.value = status;
    if (status != HealthPlatformStatus.permissionsGranted) return;

    final now = DateTime.now();
    final snapshot = await healthPlatformService.fetchSnapshot();

    // Sync cumulative daily steps
    if (snapshot.stepsToday != null) {
      final normSteps = NormalizedStepCount(
        steps: snapshot.stepsToday!,
        timestamp: now,
        source: healthPlatformService.platformSource,
        isCumulative: true,
        confidence: TwinSignalConfidence.high,
      );
      _onStepsReceived(normSteps);
    }

    // Sync latest resting heart rate
    if (snapshot.heartRateBpm != null && !snapshot.isHeartRateStale) {
      final normHr = NormalizedHeartRate(
        bpm: snapshot.heartRateBpm!,
        timestamp: snapshot.heartRateTimestamp ?? now,
        source: healthPlatformService.platformSource,
        confidence: TwinSignalConfidence.high,
      );
      _onHeartRateReceived(normHr);
    }

    // Sync sleep duration
    if (snapshot.sleepHoursLastNight != null) {
      _enqueueSignal({
        'patient_id': patientId,
        'signal_type': 'HEALTH_METRIC',
        'source': healthPlatformService.platformSource.name.toUpperCase(),
        'metric': 'sleep_duration_minutes',
        'value': snapshot.sleepHoursLastNight! * 60.0,
        'unit': 'minutes',
        'confidence': 'HIGH',
        'timestamp': now.toUtc().toIso8601String(),
      });
    }
  }

  // Facade methods for device management UI
  Future<bool> requestHealthPermissions() =>
      healthPlatformService.requestPermissions();

  Stream<DiscoveredBleDevice> scanHeartRateMonitors() =>
      heartRateAdapter.scanForHeartRateMonitors();

  Future<void> connectHeartRateMonitor(String id) =>
      heartRateAdapter.connect(id);

  Stream<DiscoveredBleDevice> scanEsp32Sensors() =>
      esp32Adapter.scanForEsp32Sensors();

  Future<void> connectEsp32(String id) => esp32Adapter.connect(id);

  void _enqueueSignal(Map<String, dynamic> signal) {
    _signalQueue.add(signal);
    if (_signalQueue.length > _maxQueueSize) {
      _signalQueue.removeAt(0); // Evict oldest telemetry if offline backlog fills
    }
  }

  /// Flushes queued signals to the Continuum backend API.
  Future<void> flushQueue() async {
    if (_signalQueue.isEmpty || _isFlushing) return;
    _isFlushing = true;

    final batch = List<Map<String, dynamic>>.from(_signalQueue);
    try {
      final updatedState = await backendService.sendTwinSignals(patientId, batch);
      if (updatedState != null) {
        _signalQueue.removeRange(0, batch.length);
        twinStateNotifier.value = updatedState;
      }
    } catch (_) {
      // Retained in queue for subsequent retry (offline resilience)
    } finally {
      _isFlushing = false;
    }
  }

  /// Pauses sensor polling (e.g. app backgrounded).
  void pause() {
    motionPipeline.stop();
  }

  /// Resumes sensor polling (e.g. app resumed to foreground).
  void resume() {
    motionPipeline.start();
    pedometerService.start(motionPipeline);
    activityService.start(motionPipeline);
  }

  /// Disposes coordinator, timers, and adapter streams.
  void dispose() {
    _batchFlushTimer?.cancel();
    _periodicHealthSyncTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    motionPipeline.dispose();
    pedometerService.dispose();
    activityService.dispose();
    heartRateAdapter.dispose();
    esp32Adapter.dispose();

    currentActivityNotifier.dispose();
    currentStepsNotifier.dispose();
    currentHeartRateNotifier.dispose();
    currentSpo2Notifier.dispose();
    currentTemperatureNotifier.dispose();
    currentHumidityNotifier.dispose();
    bleHrStatusNotifier.dispose();
    esp32StatusNotifier.dispose();
    healthStatusNotifier.dispose();
    twinStateNotifier.dispose();
    _isInitialized = false;
  }
}
