import 'package:cloud_firestore/cloud_firestore.dart';

enum RiskLevel { low, medium, high, emergency }
enum SymptomStatus { open, reviewed, resolved }

class Symptom {
  final String id;
  final String patientId;
  final String description;
  final int severity; // 1-10
  final String? duration;
  final List<String> associatedSymptoms;
  final DateTime timestamp;
  final String? aiResponse;
  final RiskLevel? riskLevel;
  final SymptomStatus status;
  final bool sharedWithDoctor;

  const Symptom({
    required this.id,
    required this.patientId,
    required this.description,
    required this.severity,
    this.duration,
    this.associatedSymptoms = const [],
    required this.timestamp,
    this.aiResponse,
    this.riskLevel,
    this.status = SymptomStatus.open,
    this.sharedWithDoctor = false,
  });

  Symptom copyWith({
    String? id,
    String? patientId,
    String? description,
    int? severity,
    String? duration,
    List<String>? associatedSymptoms,
    DateTime? timestamp,
    String? aiResponse,
    RiskLevel? riskLevel,
    SymptomStatus? status,
    bool? sharedWithDoctor,
  }) {
    return Symptom(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      duration: duration ?? this.duration,
      associatedSymptoms: associatedSymptoms ?? this.associatedSymptoms,
      timestamp: timestamp ?? this.timestamp,
      aiResponse: aiResponse ?? this.aiResponse,
      riskLevel: riskLevel ?? this.riskLevel,
      status: status ?? this.status,
      sharedWithDoctor: sharedWithDoctor ?? this.sharedWithDoctor,
    );
  }

  factory Symptom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Symptom(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      description: data['description'] as String? ?? '',
      severity: (data['severity'] as num?)?.toInt() ?? 1,
      duration: data['duration'] as String?,
      associatedSymptoms: List<String>.from(data['associatedSymptoms'] ?? []),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aiResponse: data['aiResponse'] as String?,
      riskLevel: data['riskLevel'] != null
          ? RiskLevel.values.firstWhere(
              (e) => e.name == data['riskLevel'],
              orElse: () => RiskLevel.low,
            )
          : null,
      status: SymptomStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'open'),
        orElse: () => SymptomStatus.open,
      ),
      sharedWithDoctor: data['sharedWithDoctor'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'description': description,
      'severity': severity,
      'duration': duration,
      'associatedSymptoms': associatedSymptoms,
      'timestamp': Timestamp.fromDate(timestamp),
      'aiResponse': aiResponse,
      'riskLevel': riskLevel?.name,
      'status': status.name,
      'sharedWithDoctor': sharedWithDoctor,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
