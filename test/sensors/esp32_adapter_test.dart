import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/sensors/iot/esp32_constants.dart';
import 'package:continuum_health/data/sensors/iot/esp32_environment_adapter.dart';

void main() {
  group('Esp32EnvironmentAdapter & Constants', () {
    test('GATT UUID constants are documented and well-formed', () {
      expect(Esp32GattConstants.standardEnvServiceUuid.toString(),
          '0000181a-0000-1000-8000-00805f9b34fb');
      expect(Esp32GattConstants.standardTemperatureCharUuid.toString(),
          '00002a6e-0000-1000-8000-00805f9b34fb');
      expect(Esp32GattConstants.standardHumidityCharUuid.toString(),
          '00002a6f-0000-1000-8000-00805f9b34fb');
      expect(Esp32GattConstants.customEsp32ServiceUuid.toString(),
          '4fafc201-1fb5-459e-8fcc-c5c9c331914b');
    });

    test('parses standard 16-bit temperature (sint16 in 0.01 C)', () {
      // 28.40 C = 2840 (0x0B18 -> bytes: [0x18, 0x0B] little-endian)
      final bytes = [0x18, 0x0B];
      final temp = Esp32EnvironmentAdapter.parseTemperaturePayload(bytes);
      expect(temp, 28.4);

      // -5.50 C = -550 in int16
      final bdata = ByteData(2);
      bdata.setInt16(0, -550, Endian.little);
      final negBytes = bdata.buffer.asUint8List();
      final negTemp = Esp32EnvironmentAdapter.parseTemperaturePayload(negBytes);
      expect(negTemp, -5.5);
    });

    test('parses standard 16-bit humidity (uint16 in 0.01 %)', () {
      // 64.50 % = 6450 (0x1932 -> bytes: [0x32, 0x19] little-endian)
      final bytes = [0x32, 0x19];
      final hum = Esp32EnvironmentAdapter.parseHumidityPayload(bytes);
      expect(hum, 64.5);
    });

    test('parses ASCII / UTF-8 string temperature and humidity payloads', () {
      final tempUtf8 = utf8.encode('29.2');
      expect(Esp32EnvironmentAdapter.parseTemperaturePayload(tempUtf8), 29.2);

      final humUtf8 = utf8.encode('58.0');
      expect(Esp32EnvironmentAdapter.parseHumidityPayload(humUtf8), 58.0);
    });

    test('parses JSON payload from custom ESP32 firmware', () {
      final jsonBytes = utf8.encode('{"temperature": 27.8, "humidity": 62.0}');
      expect(Esp32EnvironmentAdapter.parseTemperaturePayload(jsonBytes), 27.8);
      expect(Esp32EnvironmentAdapter.parseHumidityPayload(jsonBytes), 62.0);
    });

    test('safely rejects empty and malformed payloads', () {
      expect(Esp32EnvironmentAdapter.parseTemperaturePayload([]), isNull);
      expect(Esp32EnvironmentAdapter.parseHumidityPayload([]), isNull);
      expect(Esp32EnvironmentAdapter.parseTemperaturePayload(utf8.encode('invalid_temp')), isNull);
      // Temperature out of physical bounds (> 85 C or < -40 C)
      expect(Esp32EnvironmentAdapter.parseTemperaturePayload(utf8.encode('200.0')), isNull);
      // Humidity out of physical bounds (> 100 %)
      expect(Esp32EnvironmentAdapter.parseHumidityPayload(utf8.encode('150.0')), isNull);
    });

    test('correctly decodes binary 2-byte GATT payloads with ASCII-like byte patterns', () {
      // 0x0A32 = 2610 (26.10 C) -> little-endian bytes: [0x32, 0x0A]
      // 0x32 is '2' and 0x0A is '\n' in ASCII. Must NOT decode as 2.0!
      final tempBytes = [0x32, 0x0A];
      final temp = Esp32EnvironmentAdapter.parseTemperaturePayload(tempBytes);
      expect(temp, 26.1);

      // Same byte pattern for humidity: 26.10 %
      final hum = Esp32EnvironmentAdapter.parseHumidityPayload(tempBytes);
      expect(hum, 26.1);

      // 0x0A30 = 2608 (26.08 C -> 26.1 C) -> bytes [0x30, 0x0A] ('0\n' in ASCII). Must NOT decode as 0.0!
      final temp2Bytes = [0x30, 0x0A];
      final temp2 = Esp32EnvironmentAdapter.parseTemperaturePayload(temp2Bytes);
      expect(temp2, 26.1);
    });
  });
}
