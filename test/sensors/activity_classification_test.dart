import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/sensors/models/twin_sensor_signals.dart';
import 'package:continuum_health/data/sensors/motion/activity_recognition_service.dart';

void main() {
  group('ActivityRecognitionService - Windowed Classification', () {
    test('classifies empty samples as unknown', () {
      expect(ActivityRecognitionService.classifyWindow([]), TwinActivityType.unknown);
    });

    test('classifies low variance stationary window', () {
      // User sitting still: user accelerometer near 0 (gravitational offset removed)
      final restingWindow = List.generate(25, (i) => 0.05 + 0.02 * (i % 3));
      final result = ActivityRecognitionService.classifyWindow(restingWindow);
      expect(result, TwinActivityType.stationary);
    });

    test('classifies moderate variance walking window', () {
      // User walking: rhythmic user acceleration between 0.2 and 1.8 m/s^2
      final walkingWindow = List.generate(25, (i) => 0.8 + 0.6 * (i % 2 == 0 ? 1 : -1));
      final result = ActivityRecognitionService.classifyWindow(walkingWindow);
      expect(result, TwinActivityType.walking);
    });

    test('classifies high variance running window', () {
      // User running: dynamic energy
      final runningWindow = List.generate(25, (i) => 2.0 + 2.0 * (i % 2 == 0 ? 1 : -1));
      final result = ActivityRecognitionService.classifyWindow(runningWindow);
      expect(result, TwinActivityType.running);
    });

    test('classifies extreme variance as highActivity', () {
      // Vigorous sprinting / intense aerobic exercise: large acceleration spikes > 8.0 m/s^2
      final extremeWindow = List.generate(25, (i) => 5.0 + 4.5 * (i % 2 == 0 ? 1 : -1));
      final result = ActivityRecognitionService.classifyWindow(extremeWindow);
      expect(result, TwinActivityType.highActivity);
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
