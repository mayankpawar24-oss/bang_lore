import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../ble/ble_device_manager.dart';
import '../models/twin_sensor_signals.dart';
import 'esp32_constants.dart';

/// Adapter for ESP32 Environmental IoT Sensor over BLE GATT.
class Esp32EnvironmentAdapter {
  final IBleDeviceManager _bleManager;
  final _environmentController = StreamController<NormalizedEnvironment>.broadcast();

  StreamSubscription<List<int>>? _tempSubscription;
  StreamSubscription<List<int>>? _humSubscription;

  double? _latestTemperature;
  double? _latestHumidity;

  Esp32EnvironmentAdapter({IBleDeviceManager? bleManager})
      : _bleManager = bleManager ?? BleDeviceManager();

  Stream<NormalizedEnvironment> get environmentStream => _environmentController.stream;
  Stream<BleDeviceStatus> get statusStream => _bleManager.statusStream;
  BleDeviceStatus get currentStatus => _bleManager.currentStatus;
  String? get connectedDeviceId => _bleManager.connectedDeviceId;

  double? get latestTemperature => _latestTemperature;
  double? get latestHumidity => _latestHumidity;

  /// Scans for ESP32 devices advertising standard or custom environmental services.
  Stream<DiscoveredBleDevice> scanForEsp32Sensors({
    Duration duration = const Duration(seconds: 10),
  }) {
    return _bleManager.scanForDevices(
      serviceUuids: [
        Esp32GattConstants.standardEnvServiceUuid,
        Esp32GattConstants.customEsp32ServiceUuid,
      ],
      duration: duration,
    );
  }

  /// Connects to the ESP32 device and subscribes to environmental telemetry.
  Future<void> connect(String deviceId, {bool useCustomUuids = false}) async {
    await disconnect();
    await _bleManager.connect(deviceId);

    final serviceUuid = useCustomUuids
        ? Esp32GattConstants.customEsp32ServiceUuid
        : Esp32GattConstants.standardEnvServiceUuid;
    final tempCharUuid = useCustomUuids
        ? Esp32GattConstants.customTemperatureCharUuid
        : Esp32GattConstants.standardTemperatureCharUuid;
    final humCharUuid = useCustomUuids
        ? Esp32GattConstants.customHumidityCharUuid
        : Esp32GattConstants.standardHumidityCharUuid;

    // Subscribe to Temperature
    _tempSubscription = _bleManager.subscribeToCharacteristic(
      deviceId: deviceId,
      serviceId: serviceUuid,
      characteristicId: tempCharUuid,
    ).listen(
      (bytes) {
        final val = parseTemperaturePayload(bytes);
        if (val != null) {
          _latestTemperature = val;
          final signal = NormalizedEnvironment(
            metric: 'temperature',
            value: val,
            unit: '°C',
            timestamp: DateTime.now(),
            source: TwinSignalSource.esp32,
            deviceId: deviceId,
          );
          if (!_environmentController.isClosed) {
            _environmentController.add(signal);
          }
        }
      },
      onError: (_) {},
    );

    // Subscribe to Humidity
    _humSubscription = _bleManager.subscribeToCharacteristic(
      deviceId: deviceId,
      serviceId: serviceUuid,
      characteristicId: humCharUuid,
    ).listen(
      (bytes) {
        final val = parseHumidityPayload(bytes);
        if (val != null) {
          _latestHumidity = val;
          final signal = NormalizedEnvironment(
            metric: 'humidity',
            value: val,
            unit: '%',
            timestamp: DateTime.now(),
            source: TwinSignalSource.esp32,
            deviceId: deviceId,
          );
          if (!_environmentController.isClosed) {
            _environmentController.add(signal);
          }
        }
      },
      onError: (_) {},
    );
  }

  /// Parses raw byte payload into temperature in Celsius.
  static double? parseTemperaturePayload(List<int> bytes) {
    if (bytes.isEmpty) return null;

    // 1. Standard Bluetooth SIG sint16 (exactly 2 bytes, 0.01 °C resolution)
    if (bytes.length == 2) {
      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      final rawSint16 = byteData.getInt16(0, Endian.little);
      final temp = rawSint16 / 100.0;
      if (temp >= -40.0 && temp <= 85.0) {
        return double.parse(temp.toStringAsFixed(1));
      }
    }

    // 2. ASCII / UTF-8 string or JSON (for payloads > 2 bytes)
    if (bytes.length > 2) {
      try {
        final str = utf8.decode(bytes).trim();
        if (str.startsWith('{') && str.endsWith('}')) {
          final decoded = jsonDecode(str) as Map<String, dynamic>;
          if (decoded.containsKey('temperature')) {
            final t = (decoded['temperature'] as num?)?.toDouble();
            if (t != null && t >= -40.0 && t <= 85.0) return t;
          }
        }
        final parsedNum = double.tryParse(str);
        if (parsedNum != null && parsedNum >= -40.0 && parsedNum <= 85.0) {
          return parsedNum;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Parses raw byte payload into relative humidity in %.
  static double? parseHumidityPayload(List<int> bytes) {
    if (bytes.isEmpty) return null;

    // 1. Standard Bluetooth SIG uint16 (exactly 2 bytes, 0.01 % resolution)
    if (bytes.length == 2) {
      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      final rawUint16 = byteData.getUint16(0, Endian.little);
      final hum = rawUint16 / 100.0;
      if (hum >= 0.0 && hum <= 100.0) {
        return double.parse(hum.toStringAsFixed(1));
      }
    }

    // 2. ASCII / UTF-8 string or JSON (for payloads > 2 bytes)
    if (bytes.length > 2) {
      try {
        final str = utf8.decode(bytes).trim();
        if (str.startsWith('{') && str.endsWith('}')) {
          final decoded = jsonDecode(str) as Map<String, dynamic>;
          if (decoded.containsKey('humidity')) {
            final h = (decoded['humidity'] as num?)?.toDouble();
            if (h != null && h >= 0.0 && h <= 100.0) return h;
          }
        }
        final parsedNum = double.tryParse(str);
        if (parsedNum != null && parsedNum >= 0.0 && parsedNum <= 100.0) {
          return parsedNum;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Disconnects from the ESP32.
  Future<void> disconnect() async {
    await _tempSubscription?.cancel();
    _tempSubscription = null;
    await _humSubscription?.cancel();
    _humSubscription = null;
    await _bleManager.disconnect();
  }

  void dispose() {
    _tempSubscription?.cancel();
    _humSubscription?.cancel();
    _environmentController.close();
    _bleManager.dispose();
  }
}
