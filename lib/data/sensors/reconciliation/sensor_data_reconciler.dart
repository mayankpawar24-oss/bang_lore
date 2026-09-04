import '../models/twin_sensor_signals.dart';

/// Provenance metadata tracking signal origin and confidence.
class SignalProvenance {
  final TwinSignalSource source;
  final String? deviceId;
  final String metric;
  final double value;
  final String unit;
  final DateTime timestamp;
  final int authorityRank;

  const SignalProvenance({
    required this.source,
    this.deviceId,
    required this.metric,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.authorityRank,
  });
}

/// Source-aware reconciliation layer preventing duplicate counts or conflicting telemetry.
///
/// Hierarchy Rules:
/// - Heart Rate: BLE Sensor (rank 3) > Watch / Health Platform (rank 2) > Phone Sensor (rank 1)
/// - Steps: Watch / Health Platform (rank 3) > Phone Native Pedometer (rank 2) > Fallback Counter (rank 1)
/// - Deduplication window: suppresses redundant readings within short temporal windows.
class SensorDataReconciler {
  final Duration hrDeduplicationWindow;

  NormalizedHeartRate? _activeHeartRate;
  DateTime? _lastHeartRateAcceptedAt;
  int _activeHeartRateRank = 0;

  int _highestRecordedStepsToday = 0;
  DateTime? _lastStepTimestamp;
  TwinSignalSource _activeStepSource = TwinSignalSource.unknown;

  SensorDataReconciler({
    this.hrDeduplicationWindow = const Duration(seconds: 3),
  });

  int get currentSteps => _highestRecordedStepsToday;
  NormalizedHeartRate? get currentHeartRate => _activeHeartRate;
  TwinSignalSource get activeStepSource => _activeStepSource;
  DateTime? get lastStepTimestamp => _lastStepTimestamp;

  int _getHrSourceRank(TwinSignalSource source) {
    switch (source) {
      case TwinSignalSource.ble:
        return 3;
      case TwinSignalSource.watch:
      case TwinSignalSource.healthKit:
      case TwinSignalSource.healthConnect:
        return 2;
      case TwinSignalSource.phoneSensor:
        return 1;
      default:
        return 0;
    }
  }

  int _getStepSourceRank(TwinSignalSource source) {
    switch (source) {
      case TwinSignalSource.watch:
      case TwinSignalSource.healthKit:
      case TwinSignalSource.healthConnect:
        return 3;
      case TwinSignalSource.phoneSensor:
        return 2;
      default:
        return 1;
    }
  }

  /// Reconciles candidate heart rate signal against current active telemetry.
  ///
  /// Returns the accepted [NormalizedHeartRate] if it takes precedence, or null
  /// if superseded or deduplicated.
  NormalizedHeartRate? reconcileHeartRate(NormalizedHeartRate candidate) {
    final candidateRank = _getHrSourceRank(candidate.source);
    final now = candidate.timestamp;

    if (_activeHeartRate == null || _lastHeartRateAcceptedAt == null) {
      _activeHeartRate = candidate;
      _activeHeartRateRank = candidateRank;
      _lastHeartRateAcceptedAt = now;
      return candidate;
    }

    final elapsed = now.difference(_lastHeartRateAcceptedAt!);

    // If existing active reading is from a higher authority and recent, ignore lower authority
    if (elapsed < hrDeduplicationWindow && candidateRank < _activeHeartRateRank) {
      return null;
    }

    // Accept if higher or equal authority, or previous reading has expired
    if (candidateRank >= _activeHeartRateRank || elapsed >= hrDeduplicationWindow) {
      _activeHeartRate = candidate;
      _activeHeartRateRank = candidateRank;
      _lastHeartRateAcceptedAt = now;
      return candidate;
    }

    return null;
  }

  /// Reconciles step count signal, avoiding double-counting from multiple sensors.
  ///
  /// Takes the maximum authoritative daily cumulative steps instead of blindly summing.
  /// Returns the reconciled [NormalizedStepCount] if progress occurred, or null if redundant.
  NormalizedStepCount? reconcileSteps(NormalizedStepCount candidate) {
    final candidateRank = _getStepSourceRank(candidate.source);

    // Day rollover: reset daily accumulators if candidate is on a new calendar day
    if (_lastStepTimestamp != null) {
      final lastDate = _lastStepTimestamp!;
      final curDate = candidate.timestamp;
      if (curDate.year != lastDate.year ||
          curDate.month != lastDate.month ||
          curDate.day != lastDate.day) {
        _highestRecordedStepsToday = 0;
        _activeStepSource = TwinSignalSource.unknown;
      }
    }

    // If candidate step reading is cumulative for today
    if (candidate.isCumulative) {
      if (candidate.steps > _highestRecordedStepsToday) {
        _highestRecordedStepsToday = candidate.steps;
        _lastStepTimestamp = candidate.timestamp;
        _activeStepSource = candidate.source;
        return candidate;
      } else if (candidate.steps == _highestRecordedStepsToday &&
          candidateRank > _getStepSourceRank(_activeStepSource)) {
        // Upgrade source authority even if count is equal
        _activeStepSource = candidate.source;
      }
      return null;
    }

    // If candidate is a delta/interval (e.g. from fallback accelerometer counter)
    if (candidate.steps > 0) {
      _highestRecordedStepsToday += candidate.steps;
      _lastStepTimestamp = candidate.timestamp;
      _activeStepSource = candidate.source;

      return NormalizedStepCount(
        steps: _highestRecordedStepsToday,
        timestamp: candidate.timestamp,
        source: candidate.source,
        deviceId: candidate.deviceId,
        isCumulative: true,
        confidence: candidate.confidence,
      );
    }

    return null;
  }

  /// Seeds today's baseline steps from backend TWIN state or historical record.
  void seedDailySteps(int baselineSteps) {
    if (baselineSteps > _highestRecordedStepsToday) {
      _highestRecordedStepsToday = baselineSteps;
    }
  }

  int get currentDailySteps => _highestRecordedStepsToday;

  void resetDaily() {
    _highestRecordedStepsToday = 0;
    _lastStepTimestamp = null;
    _activeStepSource = TwinSignalSource.unknown;
    _activeHeartRate = null;
    _lastHeartRateAcceptedAt = null;
    _activeHeartRateRank = 0;
  }
}
