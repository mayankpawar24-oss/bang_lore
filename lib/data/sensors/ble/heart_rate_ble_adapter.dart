import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../models/twin_sensor_signals.dart';
import 'ble_device_manager.dart';
import 'heart_rate_parser.dart';

/// Adapter for standard Bluetooth SIG Heart Rate Service (0x180D).
class HeartRateBleAdapter {
  static final Uuid heartRateServiceUuid = Uuid.parse('0000180d-0000-1000-8000-00805f9b34fb');
  static final Uuid heartRateMeasurementUuid = Uuid.parse('00002a37-0000-1000-8000-00805f9b34fb');
  static final Uuid bodySensorLocationUuid = Uuid.parse('00002a38-0000-1000-8000-00805f9b34fb');

  final IBleDeviceManager _bleManager;
  final _heartRateController = StreamController<NormalizedHeartRate>.broadcast();
  final _statusController = StreamController<BleDeviceStatus>.broadcast();
  StreamSubscription<List<int>>? _charSubscription;
  StreamSubscription<BleDeviceStatus>? _managerStatusSubscription;
  Timer? _staleTimer;

  BleDeviceStatus _effectiveStatus = BleDeviceStatus.disconnected;
  NormalizedHeartRate? _latestReading;
  String? _sensorLocation;
  DateTime? _lastReadingTime;

  HeartRateBleAdapter({IBleDeviceManager? bleManager})
      : _bleManager = bleManager ?? BleDeviceManager() {
    _effectiveStatus = _bleManager.currentStatus;
    _statusController.add(_effectiveStatus);
    _managerStatusSubscription = _bleManager.statusStream.listen(_onManagerStatusChanged);
  }

  IBleDeviceManager get bleManager => _bleManager;

  void _onManagerStatusChanged(BleDeviceStatus status) {
    if (status != BleDeviceStatus.connected && _effectiveStatus == BleDeviceStatus.stale) {
      _staleTimer?.cancel();
    }
    _updateEffectiveStatus(status);
    if (status == BleDeviceStatus.connected) {
      _resetStaleTimer();
    } else {
      _staleTimer?.cancel();
    }
  }

  void _updateEffectiveStatus(BleDeviceStatus status) {
    if (_effectiveStatus != status) {
      _effectiveStatus = status;
      if (!_statusController.isClosed) {
        _statusController.add(status);
      }
    }
  }

  void _resetStaleTimer() {
    _staleTimer?.cancel();
    // 20s watchdog: if no new reading arrives while connected, mark as stale
    _staleTimer = Timer(const Duration(seconds: 20), () {
      if (_effectiveStatus == BleDeviceStatus.connected) {
        _updateEffectiveStatus(BleDeviceStatus.stale);
      }
    });
  }

  Stream<NormalizedHeartRate> get heartRateStream => _heartRateController.stream;
  Stream<BleDeviceStatus> get statusStream => _statusController.stream;
  BleDeviceStatus get currentStatus => _effectiveStatus;
  String? get connectedDeviceId => _bleManager.connectedDeviceId;
  NormalizedHeartRate? get latestReading => _latestReading;
  String? get sensorLocation => _sensorLocation;
  DateTime? get lastReadingTime => _lastReadingTime;

  /// Scans specifically for Bluetooth devices advertising the standard Heart Rate Service (0x180D).
  Stream<DiscoveredBleDevice> scanForHeartRateMonitors({
    Duration duration = const Duration(seconds: 10),
  }) {
    return _bleManager.scanForDevices(
      serviceUuids: [heartRateServiceUuid],
      duration: duration,
    );
  }

  /// Connects to a heart rate monitor and subscribes to 0x2A37 notifications.
  Future<void> connect(String deviceId) async {
    await disconnect();
    await _bleManager.connect(deviceId);

    // Attempt to read Body Sensor Location (UUID 0x2A38) if supported by peripheral
    try {
      final locBytes = await _bleManager.readCharacteristic(
        deviceId: deviceId,
        serviceId: heartRateServiceUuid,
        characteristicId: bodySensorLocationUuid,
      );
      if (locBytes.isNotEmpty) {
        _sensorLocation = HeartRateMeasurementParser.parseBodySensorLocation(locBytes[0]);
      }
    } catch (_) {
      _sensorLocation = null;
    }

    _charSubscription = _bleManager.subscribeToCharacteristic(
      deviceId: deviceId,
      serviceId: heartRateServiceUuid,
      characteristicId: heartRateMeasurementUuid,
    ).listen(
      (bytes) {
        final parsed = HeartRateMeasurementParser.parse(
          bytes,
          deviceId: deviceId,
          sensorLocation: _sensorLocation,
          timestamp: DateTime.now(),
        );
        if (parsed != null) {
          _latestReading = parsed;
          _lastReadingTime = DateTime.now();
          if (_effectiveStatus == BleDeviceStatus.stale) {
            _updateEffectiveStatus(BleDeviceStatus.connected);
          }
          _resetStaleTimer();

          if (!_heartRateController.isClosed) {
            _heartRateController.add(parsed);
          }
        }
      },
      onError: (err) {
        _updateEffectiveStatus(BleDeviceStatus.error);
      },
    );
  }

  /// Disconnects from the current heart rate monitor.
  Future<void> disconnect() async {
    _staleTimer?.cancel();
    await _charSubscription?.cancel();
    _charSubscription = null;
    await _bleManager.disconnect();
    _updateEffectiveStatus(BleDeviceStatus.disconnected);
  }

  void dispose() {
    _staleTimer?.cancel();
    _managerStatusSubscription?.cancel();
    _charSubscription?.cancel();
    _heartRateController.close();
    _statusController.close();
    _bleManager.dispose();
  }
}
