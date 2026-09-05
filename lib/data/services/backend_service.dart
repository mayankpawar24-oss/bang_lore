import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/twin_state_model.dart';

/// Base URL for the Continuum Health FastAPI backend.
/// On Web, Desktop, and physical Android (via adb reverse tcp:8000 tcp:8000), maps to localhost:8000.
/// Override using `--dart-define=BACKEND_URL=<url>` if needed.
const String _kDefaultUrl = 'http://localhost:8000';
const String _kBackendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: _kDefaultUrl,
);

class BackendService {
  final FirebaseAuth _auth;
  final String baseUrl;

  BackendService({
    FirebaseAuth? auth,
    String? backendUrl,
  })  : _auth = auth ?? FirebaseAuth.instance,
        baseUrl = backendUrl ?? _kBackendBaseUrl;

  /// Get current user's Firebase ID token
  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {}
      return user.uid;
    }
    return 'dev-token-patient-alex';
  }

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
      };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getIdToken();
    return {
      ..._jsonHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Send a message to the AI chat endpoint with real RAG transparency & family scoping
  Future<AIChatResponse> sendAIMessage({
    required String message,
    String? chatId,
    String? targetPatientId,
  }) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/ai/chat'),
          headers: headers,
          body: jsonEncode({
            'message': message,
            if (chatId != null) 'chatId': chatId,
            if (targetPatientId != null) 'target_patient_id': targetPatientId,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AIChatResponse.fromJson(data);
    } else if (response.statusCode == 401) {
      throw const BackendAuthException('Authentication failed. Please log in again.');
    } else if (response.statusCode == 403) {
      throw const BackendAuthException('Access Denied: You are not authorized to view records for this individual.');
    } else if (response.statusCode == 429) {
      throw const BackendRateLimitException('Too many requests. Please wait a moment.');
    } else {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw BackendException(data['detail']?.toString() ?? data['error']?.toString() ?? 'Server error');
    }
  }

  /// Send voice audio bytes to the backend voice pipeline
  Future<VoiceChatResponse> sendVoiceAudio({
    String? audioBase64,
    String? transcriptHint,
    String contentType = 'audio/wav',
    String? chatId,
    String? targetPatientId,
  }) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/ai/voice'),
          headers: headers,
          body: jsonEncode({
            if (audioBase64 != null) 'audio_base64': audioBase64,
            if (transcriptHint != null) 'transcript_hint': transcriptHint,
            'content_type': contentType,
            if (chatId != null) 'chatId': chatId,
            if (targetPatientId != null) 'patientId': targetPatientId,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return VoiceChatResponse.fromJson(data);
    } else if (response.statusCode == 403) {
      throw const BackendAuthException('Voice access denied.');
    } else {
      throw const BackendException('Failed to process voice input.');
    }
  }

  /// Clinical Document Intelligence Extraction
  Future<DocumentExtractionResponse> extractDocument({
    String? documentId,
    String? patientId,
    String? textContent,
    String? base64Content,
    String? filename,
    String? mimeType,
  }) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/documents/extract'),
          headers: headers,
          body: jsonEncode({
            if (documentId != null) 'document_id': documentId,
            if (patientId != null) 'patient_id': patientId,
            if (textContent != null) 'text_content': textContent,
            if (base64Content != null) 'base64_content': base64Content,
            if (filename != null) 'filename': filename,
            if (mimeType != null) 'mime_type': mimeType,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DocumentExtractionResponse.fromJson(data);
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw const BackendAuthException('Document authorization denied.');
    } else {
      throw const BackendException('Failed to process document with Continuum AI.');
    }
  }

  /// Fetch synthesized multi-agent daily insights
  Future<MultiAgentInsightsResponse> getPatientInsights(String patientId) async {
    final headers = await _authHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/patients/$patientId/insights'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return MultiAgentInsightsResponse.fromJson(data);
    } else {
      throw const BackendException('Failed to fetch patient insights.');
    }
  }

  /// Fetch verified document details for the Document Viewer
  Future<Map<String, dynamic>> getDocumentDetail(String patientId, String documentId) async {
    final headers = await _authHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/documents/$patientId/$documentId'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw const BackendException('Failed to fetch document details.');
    }
  }

  /// Fetch patient FollowUp plans (Autonomous Loop)
  Future<List<Map<String, dynamic>>> getFollowUps(String patientId) async {
    final headers = await _authHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/patients/$patientId/follow-ups'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } else {
      return [];
    }
  }

  /// Respond to an autonomous FollowUpPlan (TAKEN, MISSED, CONFIRMED, DECLINED)
  Future<bool> respondToFollowUp(String followUpId, String responseType, {String? notes}) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/follow-ups/$followUpId/respond'),
          headers: headers,
          body: jsonEncode({
            'response_type': responseType,
            if (notes != null) 'notes': notes,
          }),
        )
        .timeout(const Duration(seconds: 15));

    return response.statusCode == 200;
  }

  /// Submit a symptom report
  Future<SymptomAnalysisResponse> submitSymptom({
    required String description,
    required int severity,
    String? duration,
    List<String> associatedSymptoms = const [],
  }) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/ai/symptoms'),
          headers: headers,
          body: jsonEncode({
            'description': description,
            'severity': severity,
            'duration': duration,
            'associatedSymptoms': associatedSymptoms,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return SymptomAnalysisResponse.fromJson(data);
    } else if (response.statusCode == 401) {
      throw const BackendAuthException('Authentication failed.');
    } else {
      throw const BackendException('Failed to analyze symptom.');
    }
  }

  /// Fetch Personal Activity & Behavior Twin state
  Future<TwinStateModel?> getTwinState(String patientId) async {
    final headers = await _authHeaders();
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/patients/$patientId/twin/state'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TwinStateModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Ingest batch of normalized activity or health signals
  Future<TwinStateModel?> sendTwinSignals(
    String patientId,
    List<Map<String, dynamic>> signals,
  ) async {
    final headers = await _authHeaders();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/patients/$patientId/twin/signals'),
            headers: headers,
            body: jsonEncode({'signals': signals}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TwinStateModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Respond to a proactive TWIN recommendation (ACCEPTED / DISMISSED)
  Future<TwinStateModel?> respondToTwinRecommendation(
    String patientId,
    String recommendationId,
    String action, {
    String? notes,
  }) async {
    final headers = await _authHeaders();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/patients/$patientId/twin/recommendations/$recommendationId/respond'),
            headers: headers,
            body: jsonEncode({
              'action': action,
              if (notes != null) 'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TwinStateModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Configure personalized daily step goal
  Future<TwinStateModel?> setTwinStepGoal(String patientId, int stepGoal) async {
    final headers = await _authHeaders();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/patients/$patientId/twin/step-goal'),
            headers: headers,
            body: jsonEncode({'step_goal': stepGoal}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TwinStateModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Fetch 7-stage explainable Decision Trace for a recommendation
  Future<TwinDecisionTraceModel?> getTwinDecisionTrace(
    String patientId,
    String recommendationId,
  ) async {
    final headers = await _authHeaders();
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/patients/$patientId/twin/recommendations/$recommendationId/trace'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TwinDecisionTraceModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Fetch persistent behavioral memory and learned patterns
  Future<TwinBehavioralMemoryModel?> getTwinBehavioralMemory(
    String patientId,
  ) async {
    final headers = await _authHeaders();
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/patients/$patientId/twin/memory'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TwinBehavioralMemoryModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Update clinical and care context for the TWIN engine
  Future<TwinStateModel?> updateTwinCareContext(
    String patientId,
    Map<String, dynamic> careContext,
  ) async {
    final headers = await _authHeaders();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/patients/$patientId/twin/care-context'),
            headers: headers,
            body: jsonEncode(careContext),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TwinStateModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Trigger a controlled TWIN scenario across real event bus and autonomous engines
  Future<TwinScenarioResult> triggerTwinScenario({
    required String patientId,
    required String scenarioName,
    Map<String, dynamic>? params,
  }) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/patients/$patientId/twin/scenarios/$scenarioName'),
          headers: headers,
          body: jsonEncode(params ?? {}),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TwinScenarioResult.fromJson(data);
    } else {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw BackendException(
        data['detail']?.toString() ?? 'Failed to trigger scenario $scenarioName',
      );
    }
  }

  /// Retrieve technical scenario and event pipeline traces
  Future<List<Map<String, dynamic>>> getTwinScenarioTraces(String patientId) async {
    final headers = await _authHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/patients/$patientId/twin/scenarios/traces'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Manually trigger a DurableScheduler scan-and-claim cycle
  Future<Map<String, dynamic>> triggerDurableScheduler(String patientId) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/patients/$patientId/twin/scenarios/trigger-scheduler'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw BackendException(
        data['detail']?.toString() ?? 'Failed to run scheduler cycle',
      );
    }
  }

  /// Retrieve active notifications dispatched by NotificationEngine
  Future<List<TwinInAppNotification>> getActiveNotifications(String patientId) async {
    final headers = await _authHeaders();
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/patients/$patientId/twin/scenarios/notifications'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((e) => TwinInAppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Acknowledge an active in-app notification
  Future<bool> acknowledgeNotification({
    required String patientId,
    required String notificationId,
  }) async {
    final headers = await _authHeaders();
    try {
      final response = await http
          .post(
            Uri.parse(
              '$baseUrl/api/patients/$patientId/twin/scenarios/notifications/$notificationId/ack',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  /// Record adherence event into canonical event bus
  Future<bool> recordAdherenceEvent({
    required String patientId,
    required String medicationName,
    required String status, // TAKEN, MISSED
  }) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/v1/patients/$patientId/events'),
          headers: headers,
          body: jsonEncode({
            'event_type': status == 'TAKEN' ? 'MEDICATION_TAKEN' : 'MEDICATION_MISSED',
            'source': 'PATIENT_APP',
            'producer': 'flutter_app',
            'idempotency_key': 'adh_${DateTime.now().millisecondsSinceEpoch}',
            'payload': {
              'medication_name': medicationName,
              'status': status,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));

    return response.statusCode == 200;
  }

  /// Export patient data as FHIR JSON
  Future<Map<String, dynamic>> exportFhir(String patientId) async {
    final headers = await _authHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/fhir/export/$patientId'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 403) {
      throw const BackendAuthException('You do not have permission to export this data.');
    } else {
      throw const BackendException('Failed to generate FHIR export.');
    }
  }

  /// Check if backend is reachable
  Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ——— Response Models ———

class AIChatResponse {
  final String answer;
  final String confidence;
  final String? recommendedAction;
  final String? safetyNote;
  final String? chatId;
  final String riskTier;
  final bool isEmergency;
  final List<String> clarifyingQuestions;
  final List<String> recordFacts;
  final List<String> possibleConnections;
  final List<String> uncertainties;
  final String? nextStep;
  final List<String> evidenceSources;
  final List<Map<String, dynamic>> retrievedDocuments;
  final List<String> patientFactsUsed;
  final List<String> graphEvidence;

  const AIChatResponse({
    required this.answer,
    required this.confidence,
    this.recommendedAction,
    this.safetyNote,
    this.chatId,
    this.riskTier = 'routine',
    this.isEmergency = false,
    this.clarifyingQuestions = const [],
    this.recordFacts = const [],
    this.possibleConnections = const [],
    this.uncertainties = const [],
    this.nextStep,
    this.evidenceSources = const [],
    this.retrievedDocuments = const [],
    this.patientFactsUsed = const [],
    this.graphEvidence = const [],
  });

  factory AIChatResponse.fromJson(Map<String, dynamic> json) {
    return AIChatResponse(
      answer: json['answer'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'low',
      recommendedAction: json['recommendedAction'] as String?,
      safetyNote: json['safetyNote'] as String?,
      chatId: json['chatId'] as String?,
      riskTier: json['riskTier'] as String? ?? 'routine',
      isEmergency: json['isEmergency'] as bool? ?? false,
      clarifyingQuestions: List<String>.from(json['clarifyingQuestions'] ?? []),
      recordFacts: List<String>.from(json['recordFacts'] ?? []),
      possibleConnections: List<String>.from(json['possibleConnections'] ?? []),
      uncertainties: List<String>.from(json['uncertainties'] ?? []),
      nextStep: json['nextStep'] as String?,
      evidenceSources: List<String>.from(json['evidenceSources'] ?? []),
      retrievedDocuments: (json['retrievedDocuments'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      patientFactsUsed: List<String>.from(json['patientFactsUsed'] ?? []),
      graphEvidence: List<String>.from(json['graphEvidence'] ?? []),
    );
  }
}

class VoiceChatResponse extends AIChatResponse {
  final String transcript;
  final String detectedLanguage;
  final String? audioBase64;

  const VoiceChatResponse({
    required super.answer,
    required super.confidence,
    super.recommendedAction,
    super.safetyNote,
    super.chatId,
    super.riskTier = 'routine',
    super.isEmergency = false,
    super.clarifyingQuestions = const [],
    super.recordFacts = const [],
    super.possibleConnections = const [],
    super.uncertainties = const [],
    super.nextStep,
    super.evidenceSources = const [],
    super.retrievedDocuments = const [],
    super.patientFactsUsed = const [],
    super.graphEvidence = const [],
    required this.transcript,
    this.detectedLanguage = 'en',
    this.audioBase64,
  });

  factory VoiceChatResponse.fromJson(Map<String, dynamic> json) {
    final base = AIChatResponse.fromJson(json);
    return VoiceChatResponse(
      answer: base.answer,
      confidence: base.confidence,
      recommendedAction: base.recommendedAction,
      safetyNote: base.safetyNote,
      chatId: base.chatId,
      riskTier: base.riskTier,
      isEmergency: base.isEmergency,
      clarifyingQuestions: base.clarifyingQuestions,
      recordFacts: base.recordFacts,
      possibleConnections: base.possibleConnections,
      uncertainties: base.uncertainties,
      nextStep: base.nextStep,
      evidenceSources: base.evidenceSources,
      retrievedDocuments: base.retrievedDocuments,
      patientFactsUsed: base.patientFactsUsed,
      graphEvidence: base.graphEvidence,
      transcript: json['transcript'] as String? ?? '',
      detectedLanguage: json['detected_language'] as String? ?? 'en',
      audioBase64: json['audio_base64'] as String?,
    );
  }
}

class SymptomAnalysisResponse {
  final String analysis;
  final String riskLevel;
  final String? recommendedAction;

  const SymptomAnalysisResponse({
    required this.analysis,
    required this.riskLevel,
    this.recommendedAction,
  });

  factory SymptomAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return SymptomAnalysisResponse(
      analysis: json['analysis'] as String? ?? '',
      riskLevel: json['riskLevel'] as String? ?? 'low',
      recommendedAction: json['recommendedAction'] as String?,
    );
  }
}

class MedicationDetailModel {
  final String? nameRaw;
  final String? nameNormalized;
  final String? doseRaw;
  final String? doseNormalized;
  final String? frequencyRaw;
  final String? frequencyNormalized;
  final String? route;
  final double confidence;
  final bool requiresHumanReview;
  final String? sourceSpan;
  final String? unknownReason;

  const MedicationDetailModel({
    this.nameRaw,
    this.nameNormalized,
    this.doseRaw,
    this.doseNormalized,
    this.frequencyRaw,
    this.frequencyNormalized,
    this.route,
    this.confidence = 0.9,
    this.requiresHumanReview = false,
    this.sourceSpan,
    this.unknownReason,
  });

  factory MedicationDetailModel.fromJson(Map<String, dynamic> json) {
    return MedicationDetailModel(
      nameRaw: json['name_raw'] as String?,
      nameNormalized: json['name_normalized'] as String?,
      doseRaw: json['dose_raw'] as String?,
      doseNormalized: json['dose_normalized'] as String?,
      frequencyRaw: json['frequency_raw'] as String?,
      frequencyNormalized: json['frequency_normalized'] as String?,
      route: json['route'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.9,
      requiresHumanReview: json['requires_human_review'] as bool? ?? false,
      sourceSpan: json['source_span'] as String?,
      unknownReason: json['unknown_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name_raw': nameRaw,
        'name_normalized': nameNormalized,
        'dose_raw': doseRaw,
        'dose_normalized': doseNormalized,
        'frequency_raw': frequencyRaw,
        'frequency_normalized': frequencyNormalized,
        'route': route,
        'confidence': confidence,
        'requires_human_review': requiresHumanReview,
        'source_span': sourceSpan,
        'unknown_reason': unknownReason,
      };
}

class DocumentExtractionResponse {
  final String documentId;
  final String? patientId;
  final String outcome;
  final String? reviewReason;
  final String extractedSummary;
  final String documentType;
  final List<String> conditions;
  final List<String> medications;
  final List<MedicationDetailModel> medicationsDetail;
  final List<String> appointments;
  final List<String> warningSigns;
  final List<String> followUp;
  final List<String> uncertainties;
  final List<int> sourcePages;
  final Map<String, dynamic> provenance;
  final String modelId;
  final String message;

  const DocumentExtractionResponse({
    required this.documentId,
    this.patientId,
    required this.outcome,
    this.reviewReason,
    required this.extractedSummary,
    this.documentType = 'GENERAL_CLINICAL',
    this.conditions = const [],
    this.medications = const [],
    this.medicationsDetail = const [],
    this.appointments = const [],
    this.warningSigns = const [],
    this.followUp = const [],
    this.uncertainties = const [],
    this.sourcePages = const [1],
    this.provenance = const {},
    required this.modelId,
    required this.message,
  });

  factory DocumentExtractionResponse.fromJson(Map<String, dynamic> json) {
    return DocumentExtractionResponse(
      documentId: json['document_id'] as String? ?? '',
      patientId: json['patient_id'] as String?,
      outcome: json['outcome'] as String? ?? 'EXTRACTED',
      reviewReason: json['review_reason'] as String?,
      extractedSummary: json['extracted_summary'] as String? ?? '',
      documentType: json['document_type'] as String? ?? 'GENERAL_CLINICAL',
      conditions: List<String>.from(json['conditions'] ?? []),
      medications: List<String>.from(json['medications'] ?? []),
      medicationsDetail: (json['medications_detail'] as List<dynamic>?)
              ?.map((e) => MedicationDetailModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      appointments: List<String>.from(json['appointments'] ?? []),
      warningSigns: List<String>.from(json['warning_signs'] ?? []),
      followUp: List<String>.from(json['follow_up'] ?? []),
      uncertainties: List<String>.from(json['uncertainties'] ?? []),
      sourcePages: List<int>.from(json['source_pages'] ?? [1]),
      provenance: Map<String, dynamic>.from(json['provenance'] ?? {}),
      modelId: json['model_id'] as String? ?? 'gemini-3.1-flash-lite',
      message: json['message'] as String? ?? '',
    );
  }
}

class AgentInsightItem {
  final String agentName;
  final String insight;
  final String severity; // info, warning, critical

  const AgentInsightItem({
    required this.agentName,
    required this.insight,
    required this.severity,
  });

  factory AgentInsightItem.fromJson(Map<String, dynamic> json) {
    return AgentInsightItem(
      agentName: json['agentName'] as String? ?? '',
      insight: json['insight'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
    );
  }

  String get summary => insight;
  double get confidence => severity == 'critical' ? 0.95 : (severity == 'warning' ? 0.88 : 0.92);
}

class CareActionItem {
  final String action;
  final String reason;
  final String target; // patient, doctor, family

  const CareActionItem({
    required this.action,
    required this.reason,
    required this.target,
  });

  factory CareActionItem.fromJson(Map<String, dynamic> json) {
    return CareActionItem(
      action: json['action'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      target: json['target'] as String? ?? 'patient',
    );
  }
}

class MultiAgentInsightsResponse {
  final String patientId;
  final String correlationId;
  final List<AgentInsightItem> insights;
  final List<CareActionItem> actions;
  final String headline;
  final String? traditionalNuskha;

  const MultiAgentInsightsResponse({
    required this.patientId,
    required this.correlationId,
    this.insights = const [],
    this.actions = const [],
    required this.headline,
    this.traditionalNuskha,
  });

  AgentInsightItem? get oracle => insights.where((i) => i.agentName.toUpperCase().contains('ORACLE') || i.agentName.toUpperCase().contains('RISK')).firstOrNull;
  AgentInsightItem? get adherence => insights.where((i) => i.agentName.toUpperCase().contains('ADHERENCE') || i.agentName.toUpperCase().contains('MEDICATION')).firstOrNull;
  AgentInsightItem? get twin => insights.where((i) => i.agentName.toUpperCase().contains('TWIN') || i.agentName.toUpperCase().contains('RECOVERY')).firstOrNull;
  AgentInsightItem? get navigator => insights.where((i) => i.agentName.toUpperCase().contains('NAVIGATOR') || i.agentName.toUpperCase().contains('DECISION') || i.agentName.toUpperCase().contains('COORDINATION')).firstOrNull;
  AgentInsightItem? get escalate => insights.where((i) => i.agentName.toUpperCase().contains('ESCALATE') || i.agentName.toUpperCase().contains('SENTINEL') || i.agentName.toUpperCase().contains('SAFETY')).firstOrNull;

  List<String> get synthesizedActions => actions.map((a) => a.action).toList();
  String get trajectoryStatus => escalate != null && (escalate!.severity == 'critical' || escalate!.severity == 'warning') ? 'ATTENTION' : 'STABLE';

  factory MultiAgentInsightsResponse.fromJson(Map<String, dynamic> json) {
    return MultiAgentInsightsResponse(
      patientId: json['patient_id'] as String? ?? '',
      correlationId: json['correlation_id'] as String? ?? '',
      insights: (json['insights'] as List<dynamic>?)
              ?.map((e) => AgentInsightItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      actions: (json['actions'] as List<dynamic>?)
              ?.map((e) => CareActionItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      headline: json['headline'] as String? ?? '',
      traditionalNuskha: json['traditionalNuskha'] as String?,
    );
  }
}

// ——— Exceptions ———

class BackendException implements Exception {
  final String message;
  const BackendException(this.message);
  @override
  String toString() => 'BackendException: $message';
}

class BackendAuthException extends BackendException {
  const BackendAuthException(super.message);
}

class BackendRateLimitException extends BackendException {
  const BackendRateLimitException(super.message);
}
