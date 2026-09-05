import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/sensors/models/twin_sensor_signals.dart';
import 'package:continuum_health/data/sensors/motion/activity_recognition_service.dart';
import 'package:continuum_health/data/sensors/motion/phone_motion_pipeline.dart';

void main() {
  group('ActivityRecognitionService 2.0 - Windowed Classification', () {
    test('classifies empty samples as unknown', () {
      expect(ActivityRecognitionService.classifyWindow([]), TwinActivityType.unknown);
    });

    test('classifies low variance stationary window', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final restingWindow = List.generate(
        60,
        (i) => SensorSample.fromRaw(
          timestamp: now.add(Duration(milliseconds: i * 20)),
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
      final result = ActivityRecognitionService.classifyWindowDetailed(restingWindow, cadence: 0.0);
      expect(result.activity, isIn([TwinActivityType.stationary, TwinActivityType.standing]));
      expect(result.confidence, isNot(TwinSignalConfidence.low));
    });

    test('classifies sitting posture on flat surface (gravity primarily in Z)', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final sittingWindow = List.generate(
        60,
        (i) => SensorSample.fromRaw(
          timestamp: now.add(Duration(milliseconds: i * 20)),
          ax: 0.02,
          ay: 0.02,
          az: 9.81,
          gx: 0.01,
          gy: 0.01,
          gz: 0.01,
          gravityX: 0.0,
          gravityY: 0.0,
          gravityZ: 9.81,
        ),
      );
      final result = ActivityRecognitionService.classifyWindowDetailed(sittingWindow, cadence: 0.0);
      expect(result.activity, TwinActivityType.sitting);
      expect(result.confidence, TwinSignalConfidence.medium);
    });

    test('classifies standing posture upright (gravity primarily in Y)', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final standingWindow = List.generate(
        60,
        (i) => SensorSample.fromRaw(
          timestamp: now.add(Duration(milliseconds: i * 20)),
          ax: 0.02,
          ay: 9.81,
          az: 0.02,
          gx: 0.01,
          gy: 0.01,
          gz: 0.01,
          gravityX: 0.0,
          gravityY: 9.81,
          gravityZ: 0.0,
        ),
      );
      final result = ActivityRecognitionService.classifyWindowDetailed(standingWindow, cadence: 0.0);
      expect(result.activity, TwinActivityType.standing);
      expect(result.confidence, TwinSignalConfidence.medium);
    });

    test('CRITICAL: phone swing/arm wave is strictly rejected from HIGH_ACTIVITY, WALKING, and RUNNING', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      // Simulates swinging phone in an arc: large centripetal acceleration spikes (> 20 m/s^2)
      // and high angular velocity (> 3.5 rad/s) without periodic gait cadence
      final swingWindow = List.generate(
        60,
        (i) {
          final angle = (i / 60.0) * math.pi * 2.0;
          // Centripetal acceleration spike in mid-swing
          final centripetal = 15.0 * math.sin(angle).abs();
          return SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 2.0 * math.cos(angle),
            ay: 9.81 + centripetal,
            az: 3.0 * math.sin(angle),
            gx: 3.8 * math.sin(angle),
            gy: 2.5 * math.cos(angle),
            gz: 1.5,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          );
        },
      );

      final result = ActivityRecognitionService.classifyWindowDetailed(swingWindow, cadence: 0.0);

      // Must strictly NEVER be highActivity, running, or walking!
      expect(result.activity, isNot(TwinActivityType.highActivity));
      expect(result.activity, isNot(TwinActivityType.running));
      expect(result.activity, isNot(TwinActivityType.walking));
      expect(result.activity, TwinActivityType.other);
      expect(result.rejectionReason, 'DEVICE_SWING_ROTATION_REJECTED');
      expect(result.confidence, TwinSignalConfidence.low);
    });

    test('CRITICAL: rapid phone rotation / hand twist is strictly rejected from human activities', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final rotationWindow = List.generate(
        60,
        (i) => SensorSample.fromRaw(
          timestamp: now.add(Duration(milliseconds: i * 20)),
          ax: 0.5 * math.sin(i * 0.4),
          ay: 9.81 + 1.2 * math.cos(i * 0.4),
          az: 0.3,
          gx: 4.5 * math.sin(i * 0.4),
          gy: 3.8 * math.cos(i * 0.4),
          gz: 2.0,
          gravityX: 0.0,
          gravityY: 9.81,
          gravityZ: 0.0,
        ),
      );

      final result = ActivityRecognitionService.classifyWindowDetailed(rotationWindow, cadence: 0.0);
      expect(result.activity, isNot(TwinActivityType.highActivity));
      expect(result.activity, isNot(TwinActivityType.running));
      expect(result.activity, isNot(TwinActivityType.walking));
      expect(result.activity, TwinActivityType.other);
      expect(result.rejectionReason, 'DEVICE_SWING_ROTATION_REJECTED');
    });

    test('CRITICAL: random violent shake is strictly rejected from human activity', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final randomShakeWindow = List.generate(
        60,
        (i) {
          final sign = (i % 3 == 0) ? 1.0 : -1.0;
          return SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: sign * (8.0 + (i % 5)),
            ay: 9.81 + sign * (12.0 + (i % 7)),
            az: sign * (6.0 + (i % 4)),
            gx: 5.0 * sign,
            gy: 4.0 * sign,
            gz: 3.0 * sign,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          );
        },
      );

      final result = ActivityRecognitionService.classifyWindowDetailed(randomShakeWindow, cadence: 0.0);
      expect(result.activity, isNot(TwinActivityType.highActivity));
      expect(result.activity, isNot(TwinActivityType.running));
      expect(result.activity, isNot(TwinActivityType.walking));
      expect(result.activity, TwinActivityType.other);
    });

    test('classifies sustained vigorous multi-axis body workout as highActivity when balanced', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      // Workout: high user acceleration (jumping jacks), balanced rotational ratio
      final workoutWindow = List.generate(
        60,
        (i) {
          final phase = (i / 15.0) * math.pi; // ~1.6 Hz workout rhythm
          return SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 2.5 * math.sin(phase),
            ay: 9.81 + 7.5 * math.sin(phase),
            az: 2.0 * math.cos(phase),
            gx: 1.2 * math.sin(phase),
            gy: 1.0 * math.cos(phase),
            gz: 0.6,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          );
        },
      );

      final result = ActivityRecognitionService.classifyWindowDetailed(workoutWindow, cadence: 110.0);
      expect(result.activity, TwinActivityType.highActivity);
      expect(result.confidence, TwinSignalConfidence.high);
    });

    test('classifies moderate variance walking window with periodic gait', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final walkingWindow = List.generate(
        60,
        (i) {
          final phase = (i / 15.0) * math.pi; // ~1.6 Hz (100 spm)
          return SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 0.3 * math.cos(phase),
            ay: 9.81 + 1.2 * math.sin(phase),
            az: 0.4 * math.sin(phase),
            gx: 0.3 * math.sin(phase),
            gy: 0.4 * math.cos(phase),
            gz: 0.2,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          );
        },
      );
      final result = ActivityRecognitionService.classifyWindowDetailed(walkingWindow, cadence: 100.0);
      expect(result.activity, TwinActivityType.walking);
      expect(result.confidence, TwinSignalConfidence.high);
    });

    test('classifies brisk walking window with elevated cadence', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final briskWindow = List.generate(
        60,
        (i) {
          final phase = (i / 12.0) * math.pi; // ~2.1 Hz (126 spm)
          return SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 0.4 * math.cos(phase),
            ay: 9.81 + 1.6 * math.sin(phase),
            az: 0.5 * math.sin(phase),
            gx: 0.4 * math.sin(phase),
            gy: 0.5 * math.cos(phase),
            gz: 0.2,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          );
        },
      );
      final result = ActivityRecognitionService.classifyWindowDetailed(briskWindow, cadence: 126.0);
      expect(result.activity, TwinActivityType.briskWalking);
      expect(result.confidence, TwinSignalConfidence.high);
    });

    test('classifies high dynamic running window', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final runningWindow = List.generate(
        60,
        (i) {
          final phase = (i / 10.0) * math.pi; // ~2.5 Hz (150 spm)
          return SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 1.0 * math.cos(phase),
            ay: 9.81 + 3.2 * math.sin(phase),
            az: 1.2 * math.sin(phase),
            gx: 1.2 * math.sin(phase),
            gy: 1.0 * math.cos(phase),
            gz: 0.8,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          );
        },
      );
      final result = ActivityRecognitionService.classifyWindowDetailed(runningWindow, cadence: 155.0);
      expect(result.activity, TwinActivityType.running);
      expect(result.confidence, TwinSignalConfidence.high);
    });

    test('classifies automotive low-frequency sustained vibration with zero cadence', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final carWindow = List.generate(
        60,
        (i) => SensorSample.fromRaw(
          timestamp: now.add(Duration(milliseconds: i * 20)),
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
      final result = ActivityRecognitionService.classifyWindowDetailed(carWindow, cadence: 0.0);
      expect(result.activity, TwinActivityType.automotive);
      expect(result.confidence, TwinSignalConfidence.medium);
    });

    test('classifies cycling smooth continuous angular rotation with minimal foot shock', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final cyclingWindow = List.generate(
        60,
        (i) {
          final phase = (i / 25.0) * math.pi;
          return SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 0.4 * math.sin(phase),
            ay: 9.81 + 0.5 * math.cos(phase),
            az: 0.3,
            gx: 1.1 * math.sin(phase),
            gy: 0.9 * math.cos(phase),
            gz: 0.8,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          );
        },
      );
      final result = ActivityRecognitionService.classifyWindowDetailed(cyclingWindow, cadence: 0.0);
      expect(result.activity, TwinActivityType.cycling);
      expect(result.confidence, TwinSignalConfidence.medium);
    });

    test('classifies stairs descent with asymmetric vertical landing shock', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final stairsDownWindow = List.generate(
        60,
        (i) {
          // Sharp positive impact every 15 samples (~0.75s step = 80 spm)
          final isImpact = (i % 15 == 0);
          final vertShock = isImpact ? 5.5 : -0.8;
          return SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 0.3,
            ay: 9.81 + vertShock,
            az: 0.3,
            gx: 0.4,
            gy: 0.4,
            gz: 0.2,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          );
        },
      );
      final result = ActivityRecognitionService.classifyWindowDetailed(stairsDownWindow, cadence: 75.0);
      expect(result.activity, TwinActivityType.stairsDown);
    });

    test('hysteresis state machine requires consecutive confirmations', () async {
      final service = ActivityRecognitionService(
        windowSampleCount: 10,
        hopSampleCount: 10,
      );
      final emitted = <NormalizedActivity>[];
      final sub = service.activityStream.listen(emitted.add);

      // Feed 1 window of walking
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      service.updateCadence(100.0);
      for (int i = 0; i < 10; i++) {
        service.addSample(
          SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 0.3,
            ay: 9.81 + 1.2 * (i % 2 == 0 ? 1.0 : -1.0),
            az: 0.3,
            gx: 0.3,
            gy: 0.3,
            gz: 0.2,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 15));

      // After 1 window, candidate has not met the threshold of 2 confirmations
      expect(service.currentActivity, TwinActivityType.unknown);
      expect(emitted.isEmpty, isTrue);

      // Feed 2nd window of walking
      for (int i = 10; i < 20; i++) {
        service.addSample(
          SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 0.3,
            ay: 9.81 + 1.2 * (i % 2 == 0 ? 1.0 : -1.0),
            az: 0.3,
            gx: 0.3,
            gy: 0.3,
            gz: 0.2,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 15));

      // After 2nd window, transition commits to WALKING
      expect(service.currentActivity, TwinActivityType.walking);
      expect(emitted.length, 1);
      expect(emitted.first.activity, TwinActivityType.walking);
      expect(emitted.first.evidence, isNotNull);

      await sub.cancel();
      service.dispose();
    });

    test('crosswalk debounce holds walking state during brief pedestrian pause', () async {
      final service = ActivityRecognitionService(
        windowSampleCount: 10,
        hopSampleCount: 10,
        crosswalkDebounceDuration: const Duration(seconds: 4),
      );
      final emitted = <NormalizedActivity>[];
      final sub = service.activityStream.listen(emitted.add);

      final now = DateTime(2026, 9, 5, 12, 0, 0);

      // 1. Establish Walking (2 windows)
      service.updateCadence(100.0);
      for (int i = 0; i < 20; i++) {
        service.addSample(
          SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: i * 20)),
            ax: 0.3,
            ay: 9.81 + 1.2 * (i % 2 == 0 ? 1.0 : -1.0),
            az: 0.3,
            gx: 0.3,
            gy: 0.3,
            gz: 0.2,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 15));
      expect(service.currentActivity, TwinActivityType.walking);
      expect(emitted.length, 1);

      // 2. Simulate 2 windows of stationary (standing at crosswalk, within debounce window)
      service.updateCadence(0.0);
      for (int i = 20; i < 40; i++) {
        service.addSample(
          SensorSample.fromRaw(
            timestamp: now.add(Duration(milliseconds: 500 + i * 20)),
            ax: 0.05,
            ay: 9.81,
            az: 0.05,
            gx: 0.01,
            gy: 0.01,
            gz: 0.01,
            gravityX: 0.0,
            gravityY: 9.81,
            gravityZ: 0.0,
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 15));

      // Debounce holds the walking state!
      expect(service.currentActivity, TwinActivityType.walking);
      expect(emitted.length, 1); // No flapping to stationary

      await sub.cancel();
      service.dispose();
    });

    test('reportPlatformActivity emits normalized platform signals with evidence', () async {
      final service = ActivityRecognitionService();
      final emitted = <NormalizedActivity>[];
      final sub = service.activityStream.listen(emitted.add);

      service.reportPlatformActivity(
        TwinActivityType.cycling,
        source: TwinSignalSource.phoneSensor,
        deviceId: 'CORE_MOTION_01',
        evidence: {'sensor_fusion': true, 'confidence_score': 0.95},
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(emitted.length, 1);
      expect(emitted.first.activity, TwinActivityType.cycling);
      expect(emitted.first.deviceId, 'CORE_MOTION_01');
      expect(emitted.first.evidence?['confidence_score'], 0.95);

      final twinSignal = emitted.first.toTwinSignal('pat_01', platform: 'ios');
      expect(twinSignal['activity_state'], 'CYCLING');
      expect(twinSignal['metadata']['device_platform'], 'CORE_MOTION_01');
      expect(twinSignal['metadata']['evidence']['confidence_score'], 0.95);

      await sub.cancel();
      service.dispose();
    });
  });
}
