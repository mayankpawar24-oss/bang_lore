import '../models/twin_sensor_signals.dart';

/// Standard Bluetooth SIG Heart Rate Measurement (UUID 0x2A37) parser.
///
/// Implements standard GATT Heart Rate Service (0x180D) packet decoding
/// strictly conforming to Bluetooth Core Specification Supplement (CSS)
/// and Heart Rate Profile (HRP) specifications.
class HeartRateMeasurementParser {
  const HeartRateMeasurementParser();

  /// Decodes raw BLE notification bytes from characteristic 0x2A37.
  ///
  /// Returns [NormalizedHeartRate] if valid, or null if the packet is empty,
  /// truncated, or malformed.
  static NormalizedHeartRate? parse(
    List<int> bytes, {
    String? deviceId,
    String? sensorLocation,
    DateTime? timestamp,
  }) {
    if (bytes.isEmpty) return null;

    final flags = bytes[0];
    final is16Bit = (flags & 0x01) != 0;
    // Bluetooth SIG HRS 0x2A37: Bit 2 is Support bit (0x04), Bit 1 is Status/Detected bit (0x02)
    final contactSupported = (flags & 0x04) != 0;
    final contactDetected = (flags & 0x02) != 0;
    final hasEnergyExpended = (flags & 0x08) != 0;
    final hasRrIntervals = (flags & 0x10) != 0;

    int offset = 1;
    final int hrValue;

    if (is16Bit) {
      if (bytes.length < offset + 2) return null;
      hrValue = bytes[offset] | (bytes[offset + 1] << 8);
      offset += 2;
    } else {
      if (bytes.length < offset + 1) return null;
      hrValue = bytes[offset];
      offset += 1;
    }

    // Physiological plausibility boundary for real humans
    if (hrValue <= 0 || hrValue > 255 && !is16Bit || hrValue > 300) {
      return null;
    }

    bool? sensorContact;
    if (contactSupported) {
      sensorContact = contactDetected;
    }

    int? energyExpended;
    if (hasEnergyExpended) {
      if (bytes.length < offset + 2) return null;
      energyExpended = bytes[offset] | (bytes[offset + 1] << 8);
      offset += 2;
    }

    final rrIntervals = <double>[];
    if (hasRrIntervals) {
      final remaining = bytes.length - offset;
      if (remaining < 2 || remaining % 2 != 0) return null;
      while (offset + 1 < bytes.length) {
        final rawRr = bytes[offset] | (bytes[offset + 1] << 8);
        // Standard resolution: 1/1024 seconds converted to milliseconds
        final rrMs = (rawRr * 1000.0) / 1024.0;
        rrIntervals.add(double.parse(rrMs.toStringAsFixed(1)));
        offset += 2;
      }
    } else {
      // If no RR intervals, no trailing bytes should remain
      if (offset != bytes.length) return null;
    }

    final confidence = (sensorContact == false)
        ? TwinSignalConfidence.low
        : TwinSignalConfidence.high;

    return NormalizedHeartRate(
      bpm: hrValue.toDouble(),
      timestamp: timestamp ?? DateTime.now(),
      source: TwinSignalSource.ble,
      deviceId: deviceId,
      sensorLocation: sensorLocation,
      sensorContact: sensorContact,
      energyExpendedKj: energyExpended,
      rrIntervalsMs: rrIntervals,
      confidence: confidence,
    );
  }

  /// Parses standard Bluetooth SIG Body Sensor Location (UUID 0x2A38).
  static String? parseBodySensorLocation(int locationByte) {
    switch (locationByte) {
      case 0:
        return 'Other';
      case 1:
        return 'Chest';
      case 2:
        return 'Wrist';
      case 3:
        return 'Finger';
      case 4:
        return 'Hand';
      case 5:
        return 'Ear Lobe';
      case 6:
        return 'Foot';
      default:
        return 'Unknown ($locationByte)';
    }
  }
}
