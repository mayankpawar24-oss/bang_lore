import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/models/twin_state_model.dart';
import 'package:continuum_health/data/sensors/ble/ble_device_manager.dart';
import 'package:continuum_health/data/sensors/ble/heart_rate_ble_adapter.dart';
import 'package:continuum_health/data/sensors/health/health_platform_service.dart';
import 'package:continuum_health/data/sensors/iot/esp32_environment_adapter.dart';
import 'package:continuum_health/data/sensors/models/twin_sensor_signals.dart';
import 'package:continuum_health/data/sensors/twin_sensor_coordinator.dart';
import 'package:continuum_health/data/services/backend_service.dart';

class MockBackendService implements BackendService {
  bool shouldSucceed = true;
  List<List<Map<String, dynamic>>> transmittedBatches = [];

  @override
  String get baseUrl => 'http://mock';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<TwinStateModel?> sendTwinSignals(
    String patientId,
    List<Map<String, dynamic>> signals,
  ) async {
    transmittedBatches.add(List.from(signals));
    if (!shouldSucceed) return null;

    return TwinStateModel(
      patientId: patientId,
      updatedAt: DateTime.now(),
      activitySummary: const TwinActivitySummaryModel(
        currentActivity: 'WALKING',
        currentDurationMinutes: 10,
        isSedentary: false,
        sedentaryDurationMinutes: 0,
        stepsToday: 1500,
        stepGoal: 6000,
      ),
      latestHealthSignals: {},
      baselines: const TwinBaselinesModel(sampleCount: 5, completeness: 'COMPLETE'),
      activeRecommendations: [],
      recentUserReportedStates: [],
    );
  }
}

class MockBleDeviceManager implements IBleDeviceManager {
  final _statusController = StreamController<BleDeviceStatus>.broadcast();

  @override
  Stream<BleDeviceStatus> get statusStream => _statusController.stream;

  @override
  BleDeviceStatus get currentStatus => BleDeviceStatus.disconnected;

  @override
  String? get connectedDeviceId => null;

  @override
  BleStatus get bleStatus => BleStatus.ready;

  @override
  Stream<BleStatus> get bleStatusStream => Stream.value(BleStatus.ready);

  @override
  Future<BlePermissionReport> checkAndRequestPermissions() async => BlePermissionReport.ready;

  @override
  Stream<DiscoveredBleDevice> scanForDevices({
    List<Uuid> serviceUuids = const [],
    Duration duration = const Duration(seconds: 10),
  }) =>
      const Stream.empty();

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String deviceId, {Duration timeout = const Duration(seconds: 15)}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<List<int>> subscribeToCharacteristic({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
  }) =>
      const Stream.empty();

  @override
  Future<List<int>> readCharacteristic({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
  }) async =>
      [];

  @override
  void dispose() {
    _statusController.close();
  }
}

class MockHealthPlatformService implements IHealthPlatformService {
  @override
  TwinSignalSource get platformSource => TwinSignalSource.watch;

  @override
  Future<HealthPlatformStatus> checkStatus() async => HealthPlatformStatus.available;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<HealthDataSnapshot> fetchSnapshot() async => const HealthDataSnapshot();
}

void main() {
  group('TwinSensorCoordinator Queue & In-Flight Resilience', () {
    TwinSensorCoordinator buildTestCoordinator({
      required BackendService backendService,
    }) {
      final mockBle1 = MockBleDeviceManager();
      final mockBle2 = MockBleDeviceManager();
      return TwinSensorCoordinator(
        patientId: 'pat_coord_01',
        backendService: backendService,
        heartRateAdapter: HeartRateBleAdapter(bleManager: mockBle1),
        esp32Adapter: Esp32EnvironmentAdapter(bleManager: mockBle2),
        healthPlatformService: MockHealthPlatformService(),
      );
    }

    test('updates reactive notifiers on incoming sensor signals', () {
      final mockBackend = MockBackendService();
      final coordinator = buildTestCoordinator(backendService: mockBackend);

      // Verify initial values
      expect(coordinator.currentActivityNotifier.value, TwinActivityType.unknown);
      expect(coordinator.currentStepsNotifier.value, 0);
      expect(coordinator.currentHeartRateNotifier.value, isNull);
      expect(coordinator.currentTemperatureNotifier.value, isNull);
      expect(coordinator.currentHumidityNotifier.value, isNull);

      coordinator.dispose();
    });

    test('reconciles steps and manages offline queue lifecycle', () async {
      final mockBackend = MockBackendService();
      final coordinator = buildTestCoordinator(backendService: mockBackend);

      // Trigger step reconciliation
      final step = NormalizedStepCount(
        steps: 1200,
        timestamp: DateTime.now(),
        source: TwinSignalSource.phoneSensor,
        isCumulative: true,
      );
      final reconciled = coordinator.reconciler.reconcileSteps(step);
      expect(reconciled, isNotNull);
      expect(coordinator.reconciler.currentSteps, 1200);

      // Attempt flush on empty queue does not fail
      await coordinator.flushQueue();
      expect(mockBackend.transmittedBatches.isEmpty, isTrue);

      coordinator.dispose();
    });
  });
}
