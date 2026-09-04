import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// Single configuration and constants location for ESP32 Environmental GATT Services.
class Esp32GattConstants {
  const Esp32GattConstants._();

  /// Standard Bluetooth SIG Environmental Sensing Service (UUID 0x181A)
  static final Uuid standardEnvServiceUuid =
      Uuid.parse('0000181a-0000-1000-8000-00805f9b34fb');

  /// Standard Temperature Characteristic (UUID 0x2A6E, sint16 in 0.01 °C)
  static final Uuid standardTemperatureCharUuid =
      Uuid.parse('00002a6e-0000-1000-8000-00805f9b34fb');

  /// Standard Humidity Characteristic (UUID 0x2A6F, uint16 in 0.01 %)
  static final Uuid standardHumidityCharUuid =
      Uuid.parse('00002a6f-0000-1000-8000-00805f9b34fb');

  /// Custom ESP32 MicroPython / Arduino Demonstration Service UUID
  static final Uuid customEsp32ServiceUuid =
      Uuid.parse('4fafc201-1fb5-459e-8fcc-c5c9c331914b');

  /// Custom Temperature Characteristic UUID (UTF-8 / Float representation)
  static final Uuid customTemperatureCharUuid =
      Uuid.parse('beb5483e-36e1-4688-b7f5-ea07361b26a8');

  /// Custom Humidity Characteristic UUID (UTF-8 / Float representation)
  static final Uuid customHumidityCharUuid =
      Uuid.parse('beb5483f-36e1-4688-b7f5-ea07361b26a8');
}
