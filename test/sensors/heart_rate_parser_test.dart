import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/sensors/ble/heart_rate_parser.dart';
import 'package:continuum_health/data/sensors/models/twin_sensor_signals.dart';

void main() {
  group('HeartRateMeasurementParser', () {
    test('rejects empty packet safely', () {
      final result = HeartRateMeasurementParser.parse([]);
      expect(result, isNull);
    });

    test('rejects truncated 8-bit packet', () {
      // flags indicate 8-bit, but no HR byte follows
      final result = HeartRateMeasurementParser.parse([0x00]);
      expect(result, isNull);
    });

    test('rejects truncated 16-bit packet', () {
      // flags indicate 16-bit, but only 1 byte follows
      final result = HeartRateMeasurementParser.parse([0x01, 0x48]);
      expect(result, isNull);
    });

    test('correctly decodes standard 8-bit heart rate packet', () {
      // Flags: 0x00 (8-bit, no contact, no energy, no RR)
      // Heart Rate: 78 BPM
      final bytes = [0x00, 78];
      final result = HeartRateMeasurementParser.parse(bytes, deviceId: 'HR-BLE-01');

      expect(result, isNotNull);
      expect(result!.bpm, 78.0);
      expect(result.source, TwinSignalSource.ble);
      expect(result.deviceId, 'HR-BLE-01');
      expect(result.sensorContact, isNull);
      expect(result.energyExpendedKj, isNull);
      expect(result.rrIntervalsMs, isEmpty);
      expect(result.confidence, TwinSignalConfidence.high);
    });

    test('correctly decodes standard 16-bit heart rate packet', () {
      // Flags: 0x01 (16-bit)
      // HR: 185 BPM = 0x00B9 -> bytes: [0xB9, 0x00]
      final bytes = [0x01, 0xB9, 0x00];
      final result = HeartRateMeasurementParser.parse(bytes);

      expect(result, isNotNull);
      expect(result!.bpm, 185.0);
    });

    test('correctly decodes sensor contact feature and status according to Bluetooth SIG', () {
      // Bluetooth SIG HRS: Bit 2 (0x04) is Support bit, Bit 1 (0x02) is Contact Detected bit

      // Flags: 0x04 (Bit 2=1, Bit 1=0: Contact supported, but NOT detected)
      // HR: 72
      final notDetected = HeartRateMeasurementParser.parse([0x04, 72]);
      expect(notDetected, isNotNull);
      expect(notDetected!.sensorContact, isFalse);
      expect(notDetected.confidence, TwinSignalConfidence.low);

      // Flags: 0x06 (Bit 2=1, Bit 1=1: Contact supported AND detected)
      // HR: 74
      final detected = HeartRateMeasurementParser.parse([0x06, 74]);
      expect(detected, isNotNull);
      expect(detected!.sensorContact, isTrue);
      expect(detected.confidence, TwinSignalConfidence.high);

      // Flags: 0x00 or 0x02 (Bit 2=0: Contact feature not supported)
      final notSupported = HeartRateMeasurementParser.parse([0x00, 70]);
      expect(notSupported, isNotNull);
      expect(notSupported!.sensorContact, isNull);
    });

    test('correctly decodes standard Body Sensor Location (0x2A38)', () {
      expect(HeartRateMeasurementParser.parseBodySensorLocation(0), 'Other');
      expect(HeartRateMeasurementParser.parseBodySensorLocation(1), 'Chest');
      expect(HeartRateMeasurementParser.parseBodySensorLocation(2), 'Wrist');
      expect(HeartRateMeasurementParser.parseBodySensorLocation(3), 'Finger');
      expect(HeartRateMeasurementParser.parseBodySensorLocation(4), 'Hand');
      expect(HeartRateMeasurementParser.parseBodySensorLocation(5), 'Ear Lobe');
      expect(HeartRateMeasurementParser.parseBodySensorLocation(6), 'Foot');
      expect(HeartRateMeasurementParser.parseBodySensorLocation(99), 'Unknown (99)');
    });

    test('correctly decodes optional energy expended field', () {
      // Flags: 0x08 (Energy expended present)
      // HR: 80
      // Energy: 512 kJ = 0x0200 -> bytes: [0x00, 0x02]
      final bytes = [0x08, 80, 0x00, 0x02];
      final result = HeartRateMeasurementParser.parse(bytes);

      expect(result, isNotNull);
      expect(result!.bpm, 80.0);
      expect(result.energyExpendedKj, 512);
    });

    test('correctly decodes optional RR intervals', () {
      // Flags: 0x10 (RR intervals present)
      // HR: 60
      // RR1: 1024 (1.0 sec = 1000 ms) = 0x0400 -> bytes: [0x00, 0x04]
      // RR2: 896 (875 ms) = 0x0380 -> bytes: [0x80, 0x03]
      final bytes = [0x10, 60, 0x00, 0x04, 0x80, 0x03];
      final result = HeartRateMeasurementParser.parse(bytes);

      expect(result, isNotNull);
      expect(result!.bpm, 60.0);
      expect(result.rrIntervalsMs.length, 2);
      expect(result.rrIntervalsMs[0], 1000.0);
      expect(result.rrIntervalsMs[1], 875.0);
    });

    test('correctly decodes complex combination packet', () {
      // Flags: 0x1F (16-bit HR, contact detected, energy present, RR present)
      // HR: 120 (0x0078) -> [0x78, 0x00]
      // Energy: 250 kJ (0x00FA) -> [0xFA, 0x00]
      // RR: 800 (781.2 ms) -> [0x20, 0x03]
      final bytes = [0x1F, 0x78, 0x00, 0xFA, 0x00, 0x20, 0x03];
      final result = HeartRateMeasurementParser.parse(
        bytes,
        deviceId: 'POLAR-H10',
        sensorLocation: 'Chest',
      );

      expect(result, isNotNull);
      expect(result!.bpm, 120.0);
      expect(result.deviceId, 'POLAR-H10');
      expect(result.sensorLocation, 'Chest');
      expect(result.sensorContact, isTrue);
      expect(result.energyExpendedKj, 250);
      expect(result.rrIntervalsMs.length, 1);
      expect(result.rrIntervalsMs[0], closeTo(781.25, 0.1));
    });

    test('safely rejects physiologically impossible heart rates', () {
      // 0 BPM
      expect(HeartRateMeasurementParser.parse([0x00, 0]), isNull);
      // > 300 BPM (e.g. 350 = 0x015E in 16-bit)
      expect(HeartRateMeasurementParser.parse([0x01, 0x5E, 0x01]), isNull);
    });

    test('safely rejects truncated energy expended and malformed RR interval packets', () {
      // Flag 0x08 indicates energy expended present (2 bytes), but only 1 byte provided
      expect(HeartRateMeasurementParser.parse([0x08, 72, 0x01]), isNull);

      // Flag 0x10 indicates RR intervals present, but 0 RR interval bytes provided
      expect(HeartRateMeasurementParser.parse([0x10, 72]), isNull);

      // Flag 0x10 indicates RR intervals, but dangling odd byte present (3 bytes instead of 2 or 4)
      expect(HeartRateMeasurementParser.parse([0x10, 72, 0x00, 0x04, 0xFF]), isNull);

      // No RR intervals flag, but unexpected extra trailing bytes present
      expect(HeartRateMeasurementParser.parse([0x00, 72, 0xFF]), isNull);
    });
  });
}
