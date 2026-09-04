import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/sensors/models/twin_sensor_signals.dart';
import 'package:continuum_health/data/sensors/motion/activity_recognition_service.dart';
import 'package:continuum_health/data/sensors/motion/phone_motion_pipeline.dart';

void main() {
  group('ActivityRecognitionService - Windowed Classification', () {
    test('classifies empty samples as unknown', () {
      expect(ActivityRecognitionService.classifyWindow([]), TwinActivityType.unknown);
    });

    test('classifies low variance stationary window', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final restingWindow = List.generate(
        30,
        (i) => SensorSample.fromRaw(
          timestamp: now.add(Duration(milliseconds: i * 50)),
          ax: 0.05 + 0.01 * (i % 2),
          ay: 9.81 + 0.02 * (i % 2),
          az: 0.05,
          gx: 0.01,
          gy: 0.01,
          gz: 0.01,
          gravityX: 0.0,
          gravityY: 9.81,
          gravityZ: 0.0,
        ),
      );
      final result = ActivityRecognitionService.classifyWindow(restingWindow, cadence: 0.0);
      expect(result, TwinActivityType.stationary);
    });

    test('classifies moderate variance walking window', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final walkingWindow = List.generate(
        30,
        (i) => SensorSample.fromRaw(
          timestamp: now.add(Duration(milliseconds: i * 50)),
          ax: 0.2,
          ay: 9.81 + 1.0 * (i % 2 == 0 ? 1.0 : -1.0),
          az: 0.3,
          gx: 0.3,
          gy: 0.4,
          gz: 0.2,
          gravityX: 0.0,
          gravityY: 9.81,
          gravityZ: 0.0,
        ),
      );
      final result = ActivityRecognitionService.classifyWindow(walkingWindow, cadence: 100.0);
      expect(result, TwinActivityType.walking);
    });

    test('classifies high dynamic running window', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final runningWindow = List.generate(
        30,
        (i) => SensorSample.fromRaw(
          timestamp: now.add(Duration(milliseconds: i * 50)),
          ax: 1.0,
          ay: 9.81 + 2.8 * (i % 2 == 0 ? 1.0 : -1.0),
          az: 1.2,
          gx: 1.5,
          gy: 1.2,
          gz: 0.8,
          gravityX: 0.0,
          gravityY: 9.81,
          gravityZ: 0.0,
        ),
      );
      final result = ActivityRecognitionService.classifyWindow(runningWindow, cadence: 160.0);
      expect(result, TwinActivityType.running);
    });

    test('classifies automotive low-frequency sustained vibration with zero cadence', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final carWindow = List.generate(
        30,
        (i) => SensorSample.fromRaw(
          timestamp: now.add(Duration(milliseconds: i * 50)),
          ax: 0.1,
          ay: 9.81 + 0.3 * (i % 2 == 0 ? 1.0 : -1.0),
          az: 0.1,
          gx: 0.05,
          gy: 0.05,
          gz: 0.05,
          gravityX: 0.0,
          gravityY: 9.81,
          gravityZ: 0.0,
        ),
      );
      final result = ActivityRecognitionService.classifyWindow(carWindow, cadence: 0.0);
      expect(result, TwinActivityType.automotive);
    });

    test('reportPlatformActivity emits normalized platform signals', () async {
      final service = ActivityRecognitionService();
      final emitted = <NormalizedActivity>[];
      final sub = service.activityStream.listen(emitted.add);

      service.reportPlatformActivity(
        TwinActivityType.cycling,
        source: TwinSignalSource.phoneSensor,
        deviceId: 'CORE_MOTION_01',
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(emitted.length, 1);
      expect(emitted.first.activity, TwinActivityType.cycling);
      expect(emitted.first.deviceId, 'CORE_MOTION_01');

      final twinSignal = emitted.first.toTwinSignal('pat_01', platform: 'ios');
      expect(twinSignal['activity_state'], 'CYCLING');
      expect(twinSignal['metadata']['device_platform'], 'CORE_MOTION_01');

      await sub.cancel();
      service.dispose();
    });
  });
}
