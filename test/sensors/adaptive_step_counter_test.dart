import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/sensors/pedometer/adaptive_step_counter.dart';

void main() {
  group('AdaptivePeakValleyStepCounter', () {
    late AdaptivePeakValleyStepCounter counter;

    setUp(() {
      counter = AdaptivePeakValleyStepCounter();
    });

    test('orientation tolerance: Euclidean norm invariant under device rotation', () {
      final sampleTime = DateTime(2026, 9, 4, 12, 0, 0);
      final flat = AccelerometerSample(x: 0, y: 0, z: 9.81, timestamp: sampleTime);
      final portrait = AccelerometerSample(x: 0, y: 9.81, z: 0, timestamp: sampleTime);
      final landscape = AccelerometerSample(x: 9.81, y: 0, z: 0, timestamp: sampleTime);

      expect(flat.magnitude, closeTo(9.81, 0.001));
      expect(portrait.magnitude, closeTo(9.81, 0.001));
      expect(landscape.magnitude, closeTo(9.81, 0.001));
    });

    test('stationary noise suppression: counts zero steps during resting periods', () {
      final baseTime = DateTime(2026, 9, 4, 12, 0, 0);

      // Feed 100 samples with low sensor jitter around 1g (9.81 m/s^2 +/- 0.15)
      for (int i = 0; i < 100; i++) {
        final jitter = 0.15 * math.sin(i.toDouble());
        final sample = AccelerometerSample(
          x: 0.1,
          y: 0.1,
          z: 9.81 + jitter,
          timestamp: baseTime.add(Duration(milliseconds: i * 50)),
        );
        final res = counter.processSample(sample);
        expect(res.isStep, isFalse);
      }

      expect(counter.totalSteps, 0);
    });

    test('detects rhythmic walking steps from synthetic walking sequence', () {
      final baseTime = DateTime(2026, 9, 4, 12, 0, 0);
      final int sampleRateHz = 20; // 50ms per sample
      final double stepFrequencyHz = 1.8; // ~108 steps per minute (~555ms per step)
      final int totalSeconds = 6;

      int stepsDetected = 0;
      final totalSamples = totalSeconds * sampleRateHz;

      for (int i = 0; i < totalSamples; i++) {
        final tSeconds = i / sampleRateHz;
        // Human walking produces ~2.5 m/s^2 dynamic swing around 1g
        final zAccel = 9.81 + 2.4 * math.sin(2 * math.pi * stepFrequencyHz * tSeconds);

        final sample = AccelerometerSample(
          x: 0.5,
          y: 0.5,
          z: zAccel,
          timestamp: baseTime.add(Duration(milliseconds: (tSeconds * 1000).toInt())),
        );

        final res = counter.processSample(sample);
        if (res.isStep) {
          stepsDetected++;
          expect(res.confidence, greaterThanOrEqualTo(0.6));
        }
      }

      // Expected ~ 6s * 1.8 steps/s = 10-11 steps
      expect(stepsDetected, inInclusiveRange(9, 11));
      expect(counter.totalSteps, stepsDetected);
    });

    test('rejects high frequency vibration (false peak suppression via temporal constraints)', () {
      final baseTime = DateTime(2026, 9, 4, 12, 0, 0);

      // High-frequency vibration: 12 Hz (period = 83ms < 220ms minimum step interval)
      int vibrationSteps = 0;
      for (int i = 0; i < 100; i++) {
        final tSeconds = i * 0.02; // 50 Hz sampling
        final zAccel = 9.81 + 2.0 * math.sin(2 * math.pi * 12.0 * tSeconds);

        final sample = AccelerometerSample(
          x: 0,
          y: 0,
          z: zAccel,
          timestamp: baseTime.add(Duration(milliseconds: (tSeconds * 1000).toInt())),
        );

        final res = counter.processSample(sample);
        if (res.isStep) vibrationSteps++;
      }

      // Should suppress almost all oscillations because period (83ms) < 220ms
      expect(vibrationSteps, lessThanOrEqualTo(1));
    });

    test('recovers from pause after peak without getting stuck in valley-search', () {
      final baseTime = DateTime(2026, 9, 4, 12, 0, 0);

      // Fill window with baseline
      for (int i = 0; i < 40; i++) {
        counter.processSample(
          AccelerometerSample(
            x: 0,
            y: 0,
            z: 9.81,
            timestamp: baseTime.add(Duration(milliseconds: i * 20)),
          ),
        );
      }

      // Step 1 peak occurs, but no valley follows (user stops or pauses)
      counter.processSample(
        AccelerometerSample(
          x: 0,
          y: 0,
          z: 14.0,
          timestamp: baseTime.add(const Duration(milliseconds: 900)),
        ),
      );
      // Drops below peak threshold into valley-searching mode
      counter.processSample(
        AccelerometerSample(
          x: 0,
          y: 0,
          z: 10.0,
          timestamp: baseTime.add(const Duration(milliseconds: 1000)),
        ),
      );

      // Now 3 seconds elapse (exceeds maxStepIntervalMs of 2000ms)
      final pauseTime = baseTime.add(const Duration(milliseconds: 4000));

      // User resumes walking: 2 seconds of walking at 1.8 Hz
      int stepsAfterPause = 0;
      for (int i = 0; i < 40; i++) {
        final tSeconds = i / 20.0;
        final zAccel = 9.81 + 2.5 * math.sin(2 * math.pi * 1.8 * tSeconds);
        final sample = AccelerometerSample(
          x: 0.5,
          y: 0.5,
          z: zAccel,
          timestamp: pauseTime.add(Duration(milliseconds: (tSeconds * 1000).toInt())),
        );
        final res = counter.processSample(sample);
        if (res.isStep) stepsAfterPause++;
      }

      // Step counter successfully resumed counting after pause timeout
      expect(stepsAfterPause, greaterThanOrEqualTo(2));
      expect(counter.totalSteps, stepsAfterPause);
    });
  });
}
