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

class TwinBehaviorPatternModel {
  final String patternId;
  final String patternType;
  final String description;
  final double confidence;
  final int supportCount;
  final int? timeWindowStartHour;
  final int? timeWindowEndHour;
  final double? acceptanceRate;
  final Map<String, dynamic> metadata;

  const TwinBehaviorPatternModel({
    required this.patternId,
    required this.patternType,
    required this.description,
    required this.confidence,
    this.supportCount = 1,
    this.timeWindowStartHour,
    this.timeWindowEndHour,
    this.acceptanceRate,
    this.metadata = const {},
  });

  factory TwinBehaviorPatternModel.fromJson(Map<String, dynamic> json) {
    return TwinBehaviorPatternModel(
      patternId: json['pattern_id'] as String? ?? '',
      patternType: json['pattern_type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      supportCount: json['support_count'] as int? ?? 1,
      timeWindowStartHour: json['time_window_start_hour'] as int?,
      timeWindowEndHour: json['time_window_end_hour'] as int?,
      acceptanceRate: (json['acceptance_rate'] as num?)?.toDouble(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : const {},
    );
  }
}

class TwinBehavioralMemoryModel {
  final String patientId;
  final List<TwinBehaviorPatternModel> patterns;
  final int totalRecommendationsCreated;
  final int totalRecommendationsAccepted;
  final int totalRecommendationsDismissed;
  final int totalRecommendationsCompleted;
  final int consecutiveDismissals;
  final List<int> preferredHours;
  final List<int> suppressedHours;
  final DateTime? lastIntervenedAt;
  final DateTime? lastDismissedAt;

  const TwinBehavioralMemoryModel({
    required this.patientId,
    this.patterns = const [],
    this.totalRecommendationsCreated = 0,
    this.totalRecommendationsAccepted = 0,
    this.totalRecommendationsDismissed = 0,
    this.totalRecommendationsCompleted = 0,
    this.consecutiveDismissals = 0,
    this.preferredHours = const [],
    this.suppressedHours = const [],
    this.lastIntervenedAt,
    this.lastDismissedAt,
  });

  double get acceptanceRate {
    final total = totalRecommendationsAccepted + totalRecommendationsDismissed;
    if (total == 0) return 0.0;
    return ((totalRecommendationsAccepted / total) * 100).roundToDouble() / 100;
  }

  double get completionRate {
    if (totalRecommendationsAccepted == 0) return 0.0;
    return ((totalRecommendationsCompleted / totalRecommendationsAccepted) * 100).roundToDouble() / 100;
  }

  factory TwinBehavioralMemoryModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TwinBehavioralMemoryModel(patientId: '');
    }
    final patList = <TwinBehaviorPatternModel>[];
    if (json['patterns'] is List) {
      for (final p in json['patterns'] as List) {
        if (p is Map<String, dynamic>) {
          patList.add(TwinBehaviorPatternModel.fromJson(p));
        }
      }
    }
    return TwinBehavioralMemoryModel(
      patientId: json['patient_id'] as String? ?? '',
      patterns: patList,
      totalRecommendationsCreated: json['total_recommendations_created'] as int? ?? 0,
      totalRecommendationsAccepted: json['total_recommendations_accepted'] as int? ?? 0,
      totalRecommendationsDismissed: json['total_recommendations_dismissed'] as int? ?? 0,
      totalRecommendationsCompleted: json['total_recommendations_completed'] as int? ?? 0,
      consecutiveDismissals: json['consecutive_dismissals'] as int? ?? 0,
      preferredHours: (json['preferred_hours'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      suppressedHours: (json['suppressed_hours'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      lastIntervenedAt: json['last_intervened_at'] != null
          ? DateTime.tryParse(json['last_intervened_at'].toString())
          : null,
      lastDismissedAt: json['last_dismissed_at'] != null
          ? DateTime.tryParse(json['last_dismissed_at'].toString())
          : null,
    );
  }
}

class TwinDecisionTraceModel {
  final String traceId;
  final String recommendationId;
  final String patientId;
  final DateTime timestamp;
  final Map<String, dynamic> observedSignals;
  final Map<String, dynamic> careContext;
  final String whyNow;
  final String decision;
  final String actionPrompt;
  final String expectedOutcome;
  final String? outcomeObserved;
  final String? learningDelta;

  const TwinDecisionTraceModel({
    required this.traceId,
    required this.recommendationId,
    required this.patientId,
    required this.timestamp,
    required this.observedSignals,
    required this.careContext,
    required this.whyNow,
    required this.decision,
    required this.actionPrompt,
    required this.expectedOutcome,
    this.outcomeObserved,
    this.learningDelta,
  });

  factory TwinDecisionTraceModel.fromJson(Map<String, dynamic> json) {
    return TwinDecisionTraceModel(
      traceId: json['trace_id'] as String? ?? '',
      recommendationId: json['recommendation_id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      observedSignals: json['observed_signals'] is Map<String, dynamic>
          ? json['observed_signals'] as Map<String, dynamic>
          : const {},
      careContext: json['care_context'] is Map<String, dynamic>
          ? json['care_context'] as Map<String, dynamic>
          : const {},
      whyNow: json['why_now'] as String? ?? '',
      decision: json['decision'] as String? ?? '',
      actionPrompt: json['action_prompt'] as String? ?? '',
      expectedOutcome: json['expected_outcome'] as String? ?? '',
      outcomeObserved: json['outcome_observed'] as String?,
      learningDelta: json['learning_delta'] as String?,
    );
  }
}

class TwinCareContextModel {
  final List<String> activeMedications;
  final List<Map<String, dynamic>> upcomingAppointments;
  final List<String> careGaps;
  final String? recoveryTrajectory;
  final String? riskLevel;

  const TwinCareContextModel({
    this.activeMedications = const [],
    this.upcomingAppointments = const [],
    this.careGaps = const [],
    this.recoveryTrajectory,
    this.riskLevel,
  });

  factory TwinCareContextModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TwinCareContextModel();
    return TwinCareContextModel(
      activeMedications: (json['active_medications'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      upcomingAppointments: (json['upcoming_appointments'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [],
      careGaps: (json['care_gaps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      recoveryTrajectory: json['recovery_trajectory'] as String?,
      riskLevel: json['risk_level'] as String?,
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
  final TwinBehavioralMemoryModel? behavioralMemory;
  final TwinCareContextModel? careContext;
  final TwinDecisionTraceModel? latestTrace;

  const TwinStateModel({
    required this.patientId,
    required this.updatedAt,
    required this.activitySummary,
    required this.latestHealthSignals,
    required this.baselines,
    required this.activeRecommendations,
    required this.recentUserReportedStates,
    this.behavioralMemory,
    this.careContext,
    this.latestTrace,
  });

  double? get heartRate => latestHealthSignals['heart_rate']?.value;
  double? get spo2 => latestHealthSignals['spo2']?.value;
  double? get temperature => latestHealthSignals['temperature']?.value;
  double? get humidity => latestHealthSignals['humidity']?.value;

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

    final mem = json['behavioral_memory'] != null
        ? TwinBehavioralMemoryModel.fromJson(
            json['behavioral_memory'] as Map<String, dynamic>?)
        : null;

    final care = json['care_context'] != null
        ? TwinCareContextModel.fromJson(
            json['care_context'] as Map<String, dynamic>?)
        : null;

    final trace = json['latest_trace'] != null
        ? TwinDecisionTraceModel.fromJson(
            json['latest_trace'] as Map<String, dynamic>)
        : null;

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
      behavioralMemory: mem,
      careContext: care,
      latestTrace: trace,
    );
  }
}

class TwinPipelineStage {
  final String stage;
  final String status;
  final String detail;
  final String timestamp;

  const TwinPipelineStage({
    required this.stage,
    required this.status,
    required this.detail,
    required this.timestamp,
  });

  factory TwinPipelineStage.fromJson(Map<String, dynamic> json) {
    return TwinPipelineStage(
      stage: json['stage'] as String? ?? '',
      status: json['status'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

class TwinScenarioResult {
  final String scenario;
  final String patientId;
  final String correlationId;
  final String? eventId;
  final String? recommendationId;
  final String? followUpId;
  final String? notificationId;
  final String status;
  final String summary;
  final List<TwinPipelineStage> pipelineStages;
  final Map<String, dynamic> technicalTrace;
  final List<Map<String, dynamic>> suppressionReasons;
  final TwinStateModel? twinState;

  const TwinScenarioResult({
    required this.scenario,
    required this.patientId,
    required this.correlationId,
    this.eventId,
    this.recommendationId,
    this.followUpId,
    this.notificationId,
    required this.status,
    required this.summary,
    this.pipelineStages = const [],
    this.technicalTrace = const {},
    this.suppressionReasons = const [],
    this.twinState,
  });

  factory TwinScenarioResult.fromJson(Map<String, dynamic> json) {
    return TwinScenarioResult(
      scenario: json['scenario'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      correlationId: json['correlation_id'] as String? ?? '',
      eventId: json['event_id'] as String?,
      recommendationId: json['recommendation_id'] as String?,
      followUpId: json['follow_up_id'] as String?,
      notificationId: json['notification_id'] as String?,
      status: json['status'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      pipelineStages: (json['pipeline_stages'] as List<dynamic>?)
              ?.map((e) =>
                  TwinPipelineStage.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      technicalTrace: json['technical_trace'] != null
          ? Map<String, dynamic>.from(json['technical_trace'] as Map)
          : {},
      suppressionReasons: (json['suppression_reasons'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      twinState: json['twin_state'] != null
          ? TwinStateModel.fromJson(
              Map<String, dynamic>.from(json['twin_state'] as Map))
          : null,
    );
  }
}

class TwinInAppNotification {
  final String notificationId;
  final String? followUpId;
  final String title;
  final String body;
  final String type;
  final String dispatchedAt;

  const TwinInAppNotification({
    required this.notificationId,
    this.followUpId,
    required this.title,
    required this.body,
    required this.type,
    required this.dispatchedAt,
  });

  factory TwinInAppNotification.fromJson(Map<String, dynamic> json) {
    return TwinInAppNotification(
      notificationId: json['notification_id'] as String? ?? '',
      followUpId: json['follow_up_id'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'GENERAL',
      dispatchedAt: json['dispatched_at'] as String? ?? '',
    );
  }
}