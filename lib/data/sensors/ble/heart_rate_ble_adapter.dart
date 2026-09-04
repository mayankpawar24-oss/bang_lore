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
  StreamSubscription<List<int>>? _charSubscription;

  NormalizedHeartRate? _latestReading;
  String? _sensorLocation;

  HeartRateBleAdapter({IBleDeviceManager? bleManager})
      : _bleManager = bleManager ?? BleDeviceManager();

  Stream<NormalizedHeartRate> get heartRateStream => _heartRateController.stream;
  Stream<BleDeviceStatus> get statusStream => _bleManager.statusStream;
  BleDeviceStatus get currentStatus => _bleManager.currentStatus;
  String? get connectedDeviceId => _bleManager.connectedDeviceId;
  NormalizedHeartRate? get latestReading => _latestReading;
  String? get sensorLocation => _sensorLocation;

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
          if (!_heartRateController.isClosed) {
            _heartRateController.add(parsed);
          }
        }
      },
      onError: (err) {
        // Stream error handling
      },
    );
  }

  /// Disconnects from the current heart rate monitor.
  Future<void> disconnect() async {
    await _charSubscription?.cancel();
    _charSubscription = null;
    await _bleManager.disconnect();
  }

  void dispose() {
    _charSubscription?.cancel();
    _heartRateController.close();
    _bleManager.dispose();
  }
}
