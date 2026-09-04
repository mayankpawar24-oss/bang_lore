import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../models/twin_sensor_signals.dart';

enum HealthPlatformStatus {
  available,
  unavailable,
  permissionsRequired,
  permissionsGranted,
  permissionsDenied,
}

class HealthDataSnapshot {
  final int? stepsToday;
  final double? heartRateBpm;
  final DateTime? heartRateTimestamp;
  final bool isHeartRateStale;
  final double? sleepHoursLastNight;
  final bool hasWorkoutToday;

  const HealthDataSnapshot({
    this.stepsToday,
    this.heartRateBpm,
    this.heartRateTimestamp,
    this.isHeartRateStale = false,
    this.sleepHoursLastNight,
    this.hasWorkoutToday = false,
  });
}

/// Abstract contract for watch and platform health services (HealthKit / Health Connect).
abstract class IHealthPlatformService {
  TwinSignalSource get platformSource;
  Future<HealthPlatformStatus> checkStatus();
  Future<bool> requestPermissions();
  Future<HealthDataSnapshot> fetchSnapshot();
}

/// Production implementation interacting with Apple HealthKit or Android Health Connect.
class HealthPlatformService implements IHealthPlatformService {
  final Health _health;

  static const List<HealthDataType> _requestedTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.WORKOUT,
  ];

  HealthPlatformService({Health? health}) : _health = health ?? Health();

  @override
  TwinSignalSource get platformSource {
    if (!kIsWeb && Platform.isIOS) {
      return TwinSignalSource.healthKit;
    }
    return TwinSignalSource.healthConnect;
  }

  @override
  Future<HealthPlatformStatus> checkStatus() async {
    if (kIsWeb) return HealthPlatformStatus.unavailable;

    try {
      await _health.configure();

      // For Android Health Connect
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          return HealthPlatformStatus.unavailable;
        }
      }

      final hasPerm = await _health.hasPermissions(_requestedTypes);
      if (hasPerm == true) {
        return HealthPlatformStatus.permissionsGranted;
      }
      return HealthPlatformStatus.permissionsRequired;
    } catch (_) {
      return HealthPlatformStatus.unavailable;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      await _health.configure();
      final authorized = await _health.requestAuthorization(_requestedTypes);
      return authorized;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<HealthDataSnapshot> fetchSnapshot() async {
    if (kIsWeb) return const HealthDataSnapshot();

    try {
      await _health.configure();
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final yesterday = now.subtract(const Duration(hours: 24));

      // 1. Steps today
      int? stepsToday;
      try {
        stepsToday = await _health.getTotalStepsInInterval(startOfToday, now);
      } catch (_) {}

      // 2. Latest Heart Rate within past 24 hours
      double? hrBpm;
      DateTime? hrTime;
      bool isStale = false;

      try {
        final hrData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: yesterday,
          endTime: now,
        );
        if (hrData.isNotEmpty) {
          // Sort descending by date to find most recent
          hrData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
          final latest = hrData.first;
          if (latest.value is NumericHealthValue) {
            hrBpm = (latest.value as NumericHealthValue).numericValue.toDouble();
            hrTime = latest.dateTo;
            // Mark stale if older than 4 hours
            if (now.difference(hrTime).inHours >= 4) {
              isStale = true;
            }
          }
        }
      } catch (_) {}

      // 3. Sleep sessions in last 24h
      double? sleepHours;
      try {
        final sleepData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_SESSION],
          startTime: yesterday,
          endTime: now,
        );
        if (sleepData.isNotEmpty) {
          int totalSleepMinutes = 0;
          for (final s in sleepData) {
            totalSleepMinutes += s.dateTo.difference(s.dateFrom).inMinutes;
          }
          if (totalSleepMinutes > 0) {
            sleepHours = totalSleepMinutes / 60.0;
          }
        }
      } catch (_) {}

      // 4. Workout today
      bool hasWorkout = false;
      try {
        final workouts = await _health.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: startOfToday,
          endTime: now,
        );
        hasWorkout = workouts.isNotEmpty;
      } catch (_) {}

      return HealthDataSnapshot(
        stepsToday: stepsToday,
        heartRateBpm: hrBpm,
        heartRateTimestamp: hrTime,
        isHeartRateStale: isStale,
        sleepHoursLastNight: sleepHours,
        hasWorkoutToday: hasWorkout,
      );
    } catch (_) {
      return const HealthDataSnapshot();
    }
  }
}
