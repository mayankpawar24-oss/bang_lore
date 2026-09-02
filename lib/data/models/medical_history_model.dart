import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalHistory {
  final String id;
  final String patientId;
  final String condition;
  final DateTime? diagnosedAt;
  final DateTime? resolvedAt;
  final String? notes;
  final bool isCurrent;

  const MedicalHistory({
    required this.id,
    required this.patientId,
    required this.condition,
    this.diagnosedAt,
    this.resolvedAt,
    this.notes,
    this.isCurrent = true,
  });

  MedicalHistory copyWith({
    String? id,
    String? patientId,
    String? condition,
    DateTime? diagnosedAt,
    DateTime? resolvedAt,
    String? notes,
    bool? isCurrent,
  }) {
    return MedicalHistory(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      condition: condition ?? this.condition,
      diagnosedAt: diagnosedAt ?? this.diagnosedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      notes: notes ?? this.notes,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  factory MedicalHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicalHistory(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      condition: data['condition'] as String? ?? '',
      diagnosedAt: (data['diagnosedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
      isCurrent: data['isCurrent'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'condition': condition,
      'diagnosedAt': diagnosedAt != null ? Timestamp.fromDate(diagnosedAt!) : null,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'notes': notes,
      'isCurrent': isCurrent,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'condition': condition,
        'diagnosedAt': diagnosedAt?.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'notes': notes,
        'isCurrent': isCurrent,
      };
}
