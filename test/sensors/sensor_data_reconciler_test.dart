import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/sensors/models/twin_sensor_signals.dart';
import 'package:continuum_health/data/sensors/reconciliation/sensor_data_reconciler.dart';

void main() {
  group('SensorDataReconciler', () {
    late SensorDataReconciler reconciler;

    setUp(() {
      reconciler = SensorDataReconciler(
        hrDeduplicationWindow: const Duration(seconds: 3),
      );
    });

    test('reconciles heart rate: BLE takes precedence over phone sensor', () {
      final now = DateTime.now();

      final phoneReading = NormalizedHeartRate(
        bpm: 75.0,
        timestamp: now,
        source: TwinSignalSource.phoneSensor,
      );

      final bleReading = NormalizedHeartRate(
        bpm: 82.0,
        timestamp: now.add(const Duration(milliseconds: 500)),
        source: TwinSignalSource.ble,
      );

      // Phone accepted first
      final acceptedPhone = reconciler.reconcileHeartRate(phoneReading);
      expect(acceptedPhone, isNotNull);
      expect(acceptedPhone!.bpm, 75.0);

      // BLE arrives shortly after: overrides phone reading because BLE rank > Phone rank
      final acceptedBle = reconciler.reconcileHeartRate(bleReading);
      expect(acceptedBle, isNotNull);
      expect(acceptedBle!.bpm, 82.0);
      expect(reconciler.currentHeartRate?.bpm, 82.0);

      // Subsequent phone reading arrives within 3s: rejected because active BLE takes precedence
      final rejectedPhone = reconciler.reconcileHeartRate(
        NormalizedHeartRate(
          bpm: 74.0,
          timestamp: now.add(const Duration(seconds: 1)),
          source: TwinSignalSource.phoneSensor,
        ),
      );
      expect(rejectedPhone, isNull);
      expect(reconciler.currentHeartRate?.bpm, 82.0);
    });

    test('deduplicates step counting: never double counts between phone and watch', () {
      final now = DateTime.now();

      // 1. Phone records 2,500 steps cumulative
      final phoneSteps = NormalizedStepCount(
        steps: 2500,
        timestamp: now,
        source: TwinSignalSource.phoneSensor,
        isCumulative: true,
      );
      final res1 = reconciler.reconcileSteps(phoneSteps);
      expect(res1, isNotNull);
      expect(reconciler.currentSteps, 2500);

      // 2. HealthKit / Watch reports 2,500 steps (same or duplicate total)
      final watchDuplicate = NormalizedStepCount(
        steps: 2500,
        timestamp: now.add(const Duration(minutes: 1)),
        source: TwinSignalSource.healthKit,
        isCumulative: true,
      );
      final res2 = reconciler.reconcileSteps(watchDuplicate);
      // Not double-counted! Still 2500, but source upgraded to HealthKit
      expect(res2, isNull);
      expect(reconciler.currentSteps, 2500);
      expect(reconciler.activeStepSource, TwinSignalSource.healthKit);

      // 3. HealthKit reports 3,200 steps (actual progress)
      final watchProgress = NormalizedStepCount(
        steps: 3200,
        timestamp: now.add(const Duration(minutes: 5)),
        source: TwinSignalSource.healthKit,
        isCumulative: true,
      );
      final res3 = reconciler.reconcileSteps(watchProgress);
      expect(res3, isNotNull);
      expect(reconciler.currentSteps, 3200);

      // 4. Stale phone reading reports 2,600 steps
      final stalePhone = NormalizedStepCount(
        steps: 2600,
        timestamp: now.add(const Duration(minutes: 6)),
        source: TwinSignalSource.phoneSensor,
        isCumulative: true,
      );
      final res4 = reconciler.reconcileSteps(stalePhone);
      // Ignored because 2600 < 3200 authoritative steps
      expect(res4, isNull);
      expect(reconciler.currentSteps, 3200);
    });

    test('automatically resets step accumulators on calendar day rollover', () {
      final day1 = DateTime(2026, 9, 4, 18, 0, 0);
      final day2 = DateTime(2026, 9, 5, 8, 30, 0);

      // Day 1: 6,000 steps
      final day1Steps = NormalizedStepCount(
        steps: 6000,
        timestamp: day1,
        source: TwinSignalSource.healthKit,
        isCumulative: true,
      );
      expect(reconciler.reconcileSteps(day1Steps), isNotNull);
      expect(reconciler.currentSteps, 6000);

      // Day 2 morning: user has walked 150 steps today
      // Because timestamp is on Day 2, accumulators must rollover from 6000 down to 0,
      // and accept 150 as today's new cumulative steps.
      final day2Steps = NormalizedStepCount(
        steps: 150,
        timestamp: day2,
        source: TwinSignalSource.phoneSensor,
        isCumulative: true,
      );
      final res = reconciler.reconcileSteps(day2Steps);
      expect(res, isNotNull);
      expect(reconciler.currentSteps, 150);
      expect(reconciler.activeStepSource, TwinSignalSource.phoneSensor);
    });
  });
}
