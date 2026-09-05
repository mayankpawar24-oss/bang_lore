import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum BleDeviceStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  disconnecting,
  reconnecting,
  stale,
  error,
}

class BlePermissionReport {
  final bool isGranted;
  final bool bluetoothEnabled;
  final bool locationServiceEnabled;
  final bool permanentlyDenied;
  final String message;

  const BlePermissionReport({
    required this.isGranted,
    required this.bluetoothEnabled,
    required this.locationServiceEnabled,
    required this.permanentlyDenied,
    required this.message,
  });

  static const BlePermissionReport ready = BlePermissionReport(
    isGranted: true,
    bluetoothEnabled: true,
    locationServiceEnabled: true,
    permanentlyDenied: false,
    message: 'Ready to scan',
  );
}

class DiscoveredBleDevice {
  final String id;
  final String name;
  final int rssi;
  final List<Uuid> serviceUuids;

  const DiscoveredBleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.serviceUuids,
  });
}

/// Abstract contract for BLE operations, enabling mock testing without hardware.
abstract class IBleDeviceManager {
  Stream<BleDeviceStatus> get statusStream;
  BleDeviceStatus get currentStatus;
  String? get connectedDeviceId;
  BleStatus get bleStatus;
  Stream<BleStatus> get bleStatusStream;

  Future<BlePermissionReport> checkAndRequestPermissions();

  Stream<DiscoveredBleDevice> scanForDevices({
    List<Uuid> serviceUuids = const [],
    Duration duration = const Duration(seconds: 10),
  });

  Future<void> stopScan();

  Future<void> connect(String deviceId, {Duration timeout = const Duration(seconds: 15)});

  Future<void> disconnect();

  Stream<List<int>> subscribeToCharacteristic({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
  });

  Future<List<int>> readCharacteristic({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
  });

  void dispose();
}

/// Production implementation of [IBleDeviceManager] using [FlutterReactiveBle].
class BleDeviceManager implements IBleDeviceManager {
  final FlutterReactiveBle _ble;
  final _statusController = StreamController<BleDeviceStatus>.broadcast();
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  BleDeviceStatus _status = BleDeviceStatus.disconnected;
  String? _connectedDeviceId;
  bool _autoReconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  BleDeviceManager({FlutterReactiveBle? ble}) : _ble = ble ?? FlutterReactiveBle() {
    _statusController.add(_status);
  }

  @override
  Stream<BleDeviceStatus> get statusStream => _statusController.stream;

  @override
  BleDeviceStatus get currentStatus => _status;

  @override
  String? get connectedDeviceId => _connectedDeviceId;

  @override
  BleStatus get bleStatus => _ble.status;

  @override
  Stream<BleStatus> get bleStatusStream => _ble.statusStream;

  @override
  Future<BlePermissionReport> checkAndRequestPermissions() async {
    // 1. Check hardware BLE support
    if (_ble.status == BleStatus.unsupported) {
      return const BlePermissionReport(
        isGranted: false,
        bluetoothEnabled: false,
        locationServiceEnabled: true,
        permanentlyDenied: false,
        message: 'Bluetooth Low Energy (BLE) is not supported on this device.',
      );
    }

    // 2. Check if Bluetooth is turned off
    if (_ble.status == BleStatus.poweredOff) {
      return const BlePermissionReport(
        isGranted: false,
        bluetoothEnabled: false,
        locationServiceEnabled: true,
        permanentlyDenied: false,
        message: 'Bluetooth is turned OFF. Please enable Bluetooth in your device settings or quick settings.',
      );
    }

    // 3. Check Location Services status
    bool locServiceEnabled = true;
    try {
      locServiceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {}

    // 4. Request runtime permissions via permission_handler
    Map<Permission, PermissionStatus> statuses = {};
    try {
      statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    } catch (_) {}

    final scanStatus = statuses[Permission.bluetoothScan];
    final connectStatus = statuses[Permission.bluetoothConnect];
    final locStatus = statuses[Permission.location];

    final bool isPermDenied = (scanStatus?.isPermanentlyDenied == true) ||
        (connectStatus?.isPermanentlyDenied == true) ||
        (locStatus?.isPermanentlyDenied == true);

    if (isPermDenied) {
      return const BlePermissionReport(
        isGranted: false,
        bluetoothEnabled: true,
        locationServiceEnabled: true,
        permanentlyDenied: true,
        message: 'Bluetooth or Location permissions are permanently denied. Please tap below to open App Settings.',
      );
    }

    final bool scanGranted = scanStatus?.isGranted ?? true;
    final bool connectGranted = connectStatus?.isGranted ?? true;
    final bool locGranted = locStatus?.isGranted ?? true;

    if (!scanGranted || !connectGranted) {
      return const BlePermissionReport(
        isGranted: false,
        bluetoothEnabled: true,
        locationServiceEnabled: true,
        permanentlyDenied: false,
        message: 'Nearby device (Bluetooth Scan & Connect) permissions are required to discover peripherals.',
      );
    }

    if (!locGranted || !locServiceEnabled) {
      return BlePermissionReport(
        isGranted: false,
        bluetoothEnabled: true,
        locationServiceEnabled: locServiceEnabled,
        permanentlyDenied: false,
        message: !locServiceEnabled
            ? 'Location Services are disabled. Android requires Location to scan for Bluetooth devices. Please turn ON Location in Quick Settings.'
            : 'Location permission is required for BLE device discovery.',
      );
    }

    return BlePermissionReport.ready;
  }

  void _updateStatus(BleDeviceStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(_status);
      }
    }
  }

  @override
  Stream<DiscoveredBleDevice> scanForDevices({
    List<Uuid> serviceUuids = const [],
    Duration duration = const Duration(seconds: 10),
  }) {
    _updateStatus(BleDeviceStatus.scanning);
    final controller = StreamController<DiscoveredBleDevice>();

    // Safety checks before listening to reactive_ble
    if (_ble.status == BleStatus.poweredOff) {
      _updateStatus(BleDeviceStatus.error);
      controller.addError(Exception('Bluetooth is turned off. Please turn on Bluetooth in Settings.'));
      return controller.stream;
    }

    if (_ble.status == BleStatus.locationServicesDisabled) {
      _updateStatus(BleDeviceStatus.error);
      controller.addError(Exception('Location services are disabled. Android requires Location to scan for BLE devices.'));
      return controller.stream;
    }

    _scanSubscription?.cancel();
    _scanSubscription = _ble.scanForDevices(
      withServices: serviceUuids,
      scanMode: ScanMode.lowLatency,
    ).listen(
      (device) {
        if (!controller.isClosed) {
          controller.add(
            DiscoveredBleDevice(
              id: device.id,
              name: device.name.isNotEmpty ? device.name : 'Unknown BLE Device',
              rssi: device.rssi,
              serviceUuids: device.serviceUuids,
            ),
          );
        }
      },
      onError: (err) {
        _updateStatus(BleDeviceStatus.error);
        final errStr = err.toString();
        String userFriendly;
        if (errStr.contains('code 1') || errStr.toLowerCase().contains('bluetooth disabled')) {
          userFriendly = 'Bluetooth is disabled (code 1). Please turn on Bluetooth in Settings.';
        } else if (errStr.contains('code 3') || errStr.toLowerCase().contains('location permission') || errStr.toLowerCase().contains('location services')) {
          userFriendly = 'Location permission or service missing (code 3). Android requires Location to discover BLE devices.';
        } else {
          userFriendly = 'Bluetooth scan error: $err';
        }
        if (!controller.isClosed) controller.addError(Exception(userFriendly));
      },
      onDone: () {
        if (_status == BleDeviceStatus.scanning) {
          _updateStatus(BleDeviceStatus.disconnected);
        }
        if (!controller.isClosed) controller.close();
      },
    );

    // Auto stop after duration
    Timer(duration, () {
      stopScan();
      if (!controller.isClosed) controller.close();
    });

    return controller.stream;
  }

  @override
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_status == BleDeviceStatus.scanning) {
      _updateStatus(
        _connectedDeviceId != null
            ? BleDeviceStatus.connected
            : BleDeviceStatus.disconnected,
      );
    }
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await disconnect();
    _updateStatus(BleDeviceStatus.connecting);
    _connectedDeviceId = deviceId;
    _autoReconnect = false; // Enabled only once connection is established

    final completer = Completer<void>();

    _connectionSubscription = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: timeout,
    ).listen(
      (update) {
        switch (update.connectionState) {
          case DeviceConnectionState.connecting:
            _updateStatus(BleDeviceStatus.connecting);
            break;
          case DeviceConnectionState.connected:
            _updateStatus(BleDeviceStatus.connected);
            _autoReconnect = true;
            _reconnectAttempts = 0;
            if (!completer.isCompleted) completer.complete();
            break;
          case DeviceConnectionState.disconnecting:
            _updateStatus(BleDeviceStatus.disconnecting);
            break;
          case DeviceConnectionState.disconnected:
            _updateStatus(BleDeviceStatus.disconnected);
            if (!completer.isCompleted) {
              completer.completeError(
                TimeoutException('Connection failed or disconnected prematurely'),
              );
            }
            if (_autoReconnect && _connectedDeviceId == deviceId) {
              _scheduleReconnect(deviceId);
            }
            break;
        }
      },
      onError: (err) {
        _updateStatus(BleDeviceStatus.error);
        if (!completer.isCompleted) completer.completeError(err);
      },
    );

    return completer.future;
  }

  void _scheduleReconnect(String deviceId) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _autoReconnect = false;
      _updateStatus(BleDeviceStatus.disconnected);
      return;
    }
    _reconnectAttempts++;
    _updateStatus(BleDeviceStatus.reconnecting);
    Timer(const Duration(seconds: 3), () {
      if (_autoReconnect && _status == BleDeviceStatus.reconnecting) {
        connect(deviceId).catchError((_) {});
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectAttempts = 0;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDeviceId = null;
    _updateStatus(BleDeviceStatus.disconnected);
  }

  @override
  Stream<List<int>> subscribeToCharacteristic({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
  }) {
    final characteristic = QualifiedCharacteristic(
      characteristicId: characteristicId,
      serviceId: serviceId,
      deviceId: deviceId,
    );
    return _ble.subscribeToCharacteristic(characteristic);
  }

  @override
  Future<List<int>> readCharacteristic({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
  }) {
    final characteristic = QualifiedCharacteristic(
      characteristicId: characteristicId,
      serviceId: serviceId,
      deviceId: deviceId,
    );
    return _ble.readCharacteristic(characteristic);
  }

  @override
  void dispose() {
    _autoReconnect = false;
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _statusController.close();
  }
}
