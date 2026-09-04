class TwinRecommendationModel {
  final String recommendationId;
  final String patientId;
  final String reason;
  final List<String> evidenceReferences;
  final List<String> sourceSignals;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? followUpPlanId;
  final String? personalizedText;

  const TwinRecommendationModel({
    required this.recommendationId,
    required this.patientId,
    required this.reason,
    required this.evidenceReferences,
    required this.sourceSignals,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.followUpPlanId,
    this.personalizedText,
  });

  factory TwinRecommendationModel.fromJson(Map<String, dynamic> json) {
    return TwinRecommendationModel(
      recommendationId: json['recommendation_id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      evidenceReferences: (json['evidence_references'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      sourceSignals: (json['source_signals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      priority: json['priority'] as String? ?? 'STANDARD',
      status: json['status'] as String? ?? 'PROPOSED',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      followUpPlanId: json['follow_up_plan_id'] as String?,
      personalizedText: json['personalized_text'] as String?,
    );
  }
}

class TwinBaselinesModel {
  final double? restingHeartRate;
  final int? typicalSedentaryDurationMinutes;
  final int? typicalDailySteps;
  final int sampleCount;
  final String completeness;

  const TwinBaselinesModel({
    this.restingHeartRate,
    this.typicalSedentaryDurationMinutes,
    this.typicalDailySteps,
    this.sampleCount = 0,
    this.completeness = 'UNKNOWN',
  });

  factory TwinBaselinesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TwinBaselinesModel();
    return TwinBaselinesModel(
      restingHeartRate: (json['resting_heart_rate'] as num?)?.toDouble(),
      typicalSedentaryDurationMinutes:
          json['typical_sedentary_duration_minutes'] as int?,
      typicalDailySteps: json['typical_daily_steps'] as int?,
      sampleCount: json['sample_count'] as int? ?? 0,
      completeness: json['completeness'] as String? ?? 'UNKNOWN',
    );
  }
}

class TwinActivitySummaryModel {
  final String currentActivity;
  final DateTime? activityStartedAt;
  final int currentDurationMinutes;
  final int? stepsToday;
  final int? stepGoal;
  final int? remainingSteps;
  final bool isSedentary;
  final int sedentaryDurationMinutes;

  const TwinActivitySummaryModel({
    this.currentActivity = 'UNKNOWN',
    this.activityStartedAt,
    this.currentDurationMinutes = 0,
    this.stepsToday,
    this.stepGoal,
    this.remainingSteps,
    this.isSedentary = false,
    this.sedentaryDurationMinutes = 0,
  });

  factory TwinActivitySummaryModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TwinActivitySummaryModel();
    return TwinActivitySummaryModel(
      currentActivity: json['current_activity'] as String? ?? 'UNKNOWN',
      activityStartedAt: json['activity_started_at'] != null
          ? DateTime.tryParse(json['activity_started_at'].toString())
          : null,
      currentDurationMinutes: json['current_duration_minutes'] as int? ?? 0,
      stepsToday: json['steps_today'] as int?,
      stepGoal: json['step_goal'] as int?,
      remainingSteps: json['remaining_steps'] as int?,
      isSedentary: json['is_sedentary'] as bool? ?? false,
      sedentaryDurationMinutes: json['sedentary_duration_minutes'] as int? ?? 0,
    );
  }
}

class TwinHealthSignalModel {
  final String metric;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String source;
  final String? deviceType;
  final String confidence;

  const TwinHealthSignalModel({
    required this.metric,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
    this.deviceType,
    this.confidence = 'HIGH',
  });

  factory TwinHealthSignalModel.fromJson(Map<String, dynamic> json) {
    return TwinHealthSignalModel(
      metric: json['metric'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      source: json['source'] as String? ?? 'UNKNOWN',
      deviceType: json['device_type'] as String?,
      confidence: json['confidence'] as String? ?? 'HIGH',
    );
  }
}

class TwinStateModel {
  final String patientId;
  final DateTime updatedAt;
  final TwinActivitySummaryModel activitySummary;
  final Map<String, TwinHealthSignalModel> latestHealthSignals;
  final TwinBaselinesModel baselines;
  final List<TwinRecommendationModel> activeRecommendations;
  final List<String> recentUserReportedStates;

  const TwinStateModel({
    required this.patientId,
    required this.updatedAt,
    required this.activitySummary,
    required this.latestHealthSignals,
    required this.baselines,
    required this.activeRecommendations,
    required this.recentUserReportedStates,
  });

  factory TwinStateModel.fromJson(Map<String, dynamic> json) {
    final healthMap = <String, TwinHealthSignalModel>{};
    if (json['latest_health_signals'] is Map<String, dynamic>) {
      final m = json['latest_health_signals'] as Map<String, dynamic>;
      m.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          healthMap[k] = TwinHealthSignalModel.fromJson(v);
        }
      });
    }

    final recList = <TwinRecommendationModel>[];
    if (json['active_recommendations'] is List) {
      for (final item in json['active_recommendations'] as List) {
        if (item is Map<String, dynamic>) {
          recList.add(TwinRecommendationModel.fromJson(item));
        }
      }
    }

    final userReports = (json['recent_user_reported_states'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return TwinStateModel(
      patientId: json['patient_id'] as String? ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      activitySummary: TwinActivitySummaryModel.fromJson(
          json['activity_summary'] as Map<String, dynamic>?),
      latestHealthSignals: healthMap,
      baselines: TwinBaselinesModel.fromJson(
          json['baselines'] as Map<String, dynamic>?),
      activeRecommendations: recList,
      recentUserReportedStates: userReports,
    );
  }
}