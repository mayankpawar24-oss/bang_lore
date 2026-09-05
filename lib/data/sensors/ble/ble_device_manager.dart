import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

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
        if (!controller.isClosed) controller.addError(err);
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
