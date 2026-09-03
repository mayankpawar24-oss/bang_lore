import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Base URL for the Node.js backend.
/// Change this for production deployment.
/// For Android emulator: 10.0.2.2 maps to localhost on the host machine.
const String _kBackendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://10.0.2.2:3000',
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
    return _auth.currentUser?.getIdToken();
  }

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
      };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getIdToken();
    return {
      ..._jsonHeaders,
      if (token != null) 'Authorization': 'Bearer ',
    };
  }

  /// Send a message to the AI chat endpoint
  /// Returns: { answer, confidence, recommendedAction, safetyNote, chatId }
  Future<AIChatResponse> sendAIMessage({
    required String message,
    String? chatId,
  }) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('/api/ai/chat'),
          headers: headers,
          body: jsonEncode({
            'message': message,
            if (chatId != null) 'chatId': chatId,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AIChatResponse.fromJson(data);
    } else if (response.statusCode == 401) {
      throw BackendAuthException('Authentication failed. Please log in again.');
    } else if (response.statusCode == 429) {
      throw BackendRateLimitException('Too many requests. Please wait a moment.');
    } else {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw BackendException(data['error'] as String? ?? 'Server error');
    }
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
          Uri.parse('/api/ai/symptoms'),
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
      throw BackendAuthException('Authentication failed.');
    } else {
      throw BackendException('Failed to analyze symptom.');
    }
  }

  /// Export patient data as FHIR JSON
  Future<Map<String, dynamic>> exportFhir(String patientId) async {
    final headers = await _authHeaders();
    final response = await http
        .get(
          Uri.parse('/api/fhir/export/'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 403) {
      throw BackendAuthException('You do not have permission to export this data.');
    } else {
      throw BackendException('Failed to generate FHIR export.');
    }
  }

  /// Check if backend is reachable
  Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('/health'))
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

  const AIChatResponse({
    required this.answer,
    required this.confidence,
    this.recommendedAction,
    this.safetyNote,
    this.chatId,
  });

  factory AIChatResponse.fromJson(Map<String, dynamic> json) {
    return AIChatResponse(
      answer: json['answer'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'low',
      recommendedAction: json['recommendedAction'] as String?,
      safetyNote: json['safetyNote'] as String?,
      chatId: json['chatId'] as String?,
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

// ——— Exceptions ———

class BackendException implements Exception {
  final String message;
  const BackendException(this.message);
  @override
  String toString() => 'BackendException: ';
}

class BackendAuthException extends BackendException {
  const BackendAuthException(super.message);
}

class BackendRateLimitException extends BackendException {
  const BackendRateLimitException(super.message);
}
