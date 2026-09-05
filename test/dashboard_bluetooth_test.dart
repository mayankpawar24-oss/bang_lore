import 'dart:async';
import 'package:flutter/material.dart';
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
import 'package:continuum_health/features/patient/dashboard/widgets/ble_device_manager_sheet.dart';
import 'package:continuum_health/features/patient/dashboard/widgets/twin_activity_card.dart';

class MockBackendService implements BackendService {
  @override
  String get baseUrl => 'http://mock';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<TwinStateModel?> getTwinState(String patientId) async => null;

  @override
  Future<List<TwinInAppNotification>> getActiveNotifications(String patientId) async => [];
}

class MockBleDeviceManager implements IBleDeviceManager {
  final _statusController = StreamController<BleDeviceStatus>.broadcast();
  BlePermissionReport permissionReport = BlePermissionReport.ready;

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
  Future<BlePermissionReport> checkAndRequestPermissions() async => permissionReport;

  final _scanController = StreamController<DiscoveredBleDevice>.broadcast();

  @override
  Stream<DiscoveredBleDevice> scanForDevices({
    List<Uuid> serviceUuids = const [],
    Duration duration = const Duration(seconds: 10),
  }) =>
      _scanController.stream;

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
    _scanController.close();
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
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TwinActivityCard renders Bluetooth header button and dedicated BLE section on dashboard', (WidgetTester tester) async {
    final backendService = MockBackendService();
    final coordinator = TwinSensorCoordinator(
      patientId: 'patient_test_01',
      backendService: backendService,
      heartRateAdapter: HeartRateBleAdapter(bleManager: MockBleDeviceManager()),
      esp32Adapter: Esp32EnvironmentAdapter(bleManager: MockBleDeviceManager()),
      healthPlatformService: MockHealthPlatformService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TwinActivityCard(
              twinState: null,
              patientId: 'patient_test_01',
              backendService: backendService,
              sensorCoordinator: coordinator,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header has Console, BLE, and TWIN Center
    expect(find.text('Console'), findsOneWidget);
    expect(find.text('BLE'), findsOneWidget);
    expect(find.text('TWIN Center →'), findsOneWidget);

    // 2. Verify Bluetooth Devices (BLE) Section is present
    expect(find.text('Bluetooth Devices (BLE)'), findsOneWidget);
    expect(find.text('Heart Rate Monitor'), findsOneWidget);
    expect(find.text('ESP32 Climate Sensor'), findsOneWidget);
    expect(find.text('0x180D (Measurement 0x2A37)'), findsOneWidget);
    expect(find.text('0x181A (Temp & Humidity)'), findsOneWidget);

    // 3. Verify Manage button is present
    expect(find.text('Manage'), findsOneWidget);

    // 4. Verify initial DISCONNECTED status badges
    expect(find.text('DISCONNECTED'), findsNWidgets(2));

    // 5. Update coordinator status to CONNECTED and verify reactive update
    coordinator.bleHrStatusNotifier.value = BleDeviceStatus.connected;
    await tester.pumpAndSettle();

    expect(find.text('CONNECTED'), findsOneWidget);
    expect(find.text('Connected & streaming telemetry'), findsOneWidget);

    coordinator.dispose();
  });

  testWidgets('BleDeviceManagerSheet handles denied permissions and displays resolution actions', (WidgetTester tester) async {
    final backendService = MockBackendService();
    final mockBle = MockBleDeviceManager();
    // Simulate location disabled / denied
    mockBle.permissionReport = const BlePermissionReport(
      isGranted: false,
      bluetoothEnabled: true,
      locationServiceEnabled: false,
      permanentlyDenied: true,
      message: 'Location services disabled. Please enable GPS and Location in system settings.',
    );

    final coordinator = TwinSensorCoordinator(
      patientId: 'patient_test_01',
      backendService: backendService,
      heartRateAdapter: HeartRateBleAdapter(bleManager: mockBle),
      esp32Adapter: Esp32EnvironmentAdapter(bleManager: mockBle),
      healthPlatformService: MockHealthPlatformService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BleDeviceManagerSheet(coordinator: coordinator),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify modal elements
    expect(find.text('BLE Device Manager'), findsOneWidget);
    expect(find.text('Scan for Devices'), findsOneWidget);

    // 2. Tap Scan for Devices -> triggers checkAndRequestPermissions()
    await tester.tap(find.text('Scan for Devices'));
    await tester.pumpAndSettle();

    // 3. Verify error banner and action buttons are rendered
    expect(find.text('Location services disabled. Please enable GPS and Location in system settings.'), findsOneWidget);
    expect(find.text('Open App Settings'), findsOneWidget);
    expect(find.text('Enable Location Settings'), findsOneWidget);
    expect(find.text('Retry Scan'), findsOneWidget);

    // 4. Now simulate permission granted, tap Retry Scan
    mockBle.permissionReport = BlePermissionReport.ready;
    await tester.tap(find.text('Retry Scan'));
    await tester.pump();

    expect(find.text('Stop Scan'), findsOneWidget);

    coordinator.dispose();
  });
}
