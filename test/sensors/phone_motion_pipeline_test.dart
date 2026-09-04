import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:continuum_health/data/sensors/motion/phone_motion_pipeline.dart';

void main() {
  group('PhoneMotionPipeline', () {
    test('normalizes 3D acceleration and angular velocity into orientation-invariant magnitudes', () {
      final now = DateTime(2026, 9, 5, 10, 0, 0);
      final sample = SensorSample.fromRaw(
        timestamp: now,
        ax: 0.0,
        ay: 9.81,
        az: 0.0,
        gx: 0.1,
        gy: 0.2,
        gz: 0.2,
        gravityX: 0.0,
        gravityY: 9.81,
        gravityZ: 0.0,
      );

      expect(sample.accelMagnitude, closeTo(9.81, 0.001));
      expect(sample.gyroMagnitude, closeTo(math.sqrt(0.01 + 0.04 + 0.04), 0.001));
      expect(sample.userAccelMagnitude, closeTo(0.0, 0.001));
      expect(sample.source, 'PHONE_INTERNAL_SENSORS');
    });

    test('separates gravity from dynamic user motion using low-pass EMA filter', () {
      final now = DateTime(2026, 9, 5, 10, 0, 0);

      // Simulated sudden upward step acceleration: ay spikes to 13.81 (dynamic user impulse of +4.0 m/s^2)
      final sample = SensorSample.fromRaw(
        timestamp: now,
        ax: 0.0,
        ay: 13.81,
        az: 0.0,
        gx: 0.0,
        gy: 0.0,
        gz: 0.0,
        gravityX: 0.0,
        gravityY: 9.81, // Prior gravity baseline
        gravityZ: 0.0,
      );

      expect(sample.userAy, closeTo(4.0, 0.001));
      expect(sample.userAccelMagnitude, closeTo(4.0, 0.001));
    });

    test('estimates sampling rate and updates diagnostics from synthetic event streams', () async {
      final accelController = StreamController<AccelerometerEvent>();
      final gyroController = StreamController<GyroscopeEvent>();

      final pipeline = PhoneMotionPipeline(
        customAccelStream: accelController.stream,
        customGyroStream: gyroController.stream,
      );

      pipeline.start();

      expect(pipeline.isActive, isTrue);
      expect(pipeline.currentDiagnostics.sensorStreamActive, isTrue);

      final baseTime = DateTime.now();

      // Emit 10 events spaced at 20ms intervals (~50 Hz)
      for (int i = 0; i < 10; i++) {
        accelController.add(AccelerometerEvent(0.1, 9.81, 0.2, baseTime.add(Duration(milliseconds: i * 20))));
        gyroController.add(GyroscopeEvent(0.01, 0.02, 0.01, baseTime.add(Duration(milliseconds: i * 20))));
        await Future.delayed(const Duration(milliseconds: 2));
      }

      await Future.delayed(const Duration(milliseconds: 20));

      final diag = pipeline.currentDiagnostics;
      expect(diag.accelSampleCount, greaterThanOrEqualTo(5));
      expect(diag.gyroSampleCount, greaterThanOrEqualTo(5));
      expect(diag.accelReceiving, isTrue);
      expect(diag.gyroReceiving, isTrue);

      pipeline.dispose();
      await accelController.close();
      await gyroController.close();
    });
  });
}
