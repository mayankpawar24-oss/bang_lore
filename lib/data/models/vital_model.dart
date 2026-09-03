import 'package:cloud_firestore/cloud_firestore.dart';

class Vital {
  final String id;
  final String patientId;
  final int? heartRate;
  final int? systolic;
  final int? diastolic;
  final int? spo2;
  final double? weight;
  final double? temperature;
  final String? notes;
  final DateTime recordedAt;

  const Vital({
    required this.id,
    required this.patientId,
    this.heartRate,
    this.systolic,
    this.diastolic,
    this.spo2,
    this.weight,
    this.temperature,
    this.notes,
    required this.recordedAt,
  });

  Vital copyWith({
    String? id,
    String? patientId,
    int? heartRate,
    int? systolic,
    int? diastolic,
    int? spo2,
    double? weight,
    double? temperature,
    String? notes,
    DateTime? recordedAt,
  }) {
    return Vital(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      heartRate: heartRate ?? this.heartRate,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      spo2: spo2 ?? this.spo2,
      weight: weight ?? this.weight,
      temperature: temperature ?? this.temperature,
      notes: notes ?? this.notes,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  factory Vital.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vital(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      heartRate: (data['heartRate'] as num?)?.toInt(),
      systolic: (data['systolic'] as num?)?.toInt(),
      diastolic: (data['diastolic'] as num?)?.toInt(),
      spo2: (data['spo2'] as num?)?.toInt(),
      weight: (data['weight'] as num?)?.toDouble(),
      temperature: (data['temperature'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
      recordedAt: (data['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'heartRate': heartRate,
      'systolic': systolic,
      'diastolic': diastolic,
      'spo2': spo2,
      'weight': weight,
      'temperature': temperature,
      'notes': notes,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'heartRate': heartRate,
        'systolic': systolic,
        'diastolic': diastolic,
        'spo2': spo2,
        'weight': weight,
        'temperature': temperature,
        'notes': notes,
        'recordedAt': recordedAt.toIso8601String(),
      };

  String get bloodPressure =>
      (systolic != null && diastolic != null) ? '/' : '--/--';
}

typedef VitalModel = Vital;
