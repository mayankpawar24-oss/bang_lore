import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String id;
  final String name;
  final String dosage;
  final String time;
  final bool isTaken;
  final bool isSkipped;
  final bool isMissed;
  final DateTime date;
  // Extended
  final String? patientId;
  final String? frequency;
  final List<String> times;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? stock;
  final bool active;
  final DateTime? takenAt;
  final DateTime? skippedAt;
  final DateTime? missedAt;
  final String? notes;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.isTaken,
    this.isSkipped = false,
    this.isMissed = false,
    required this.date,
    this.patientId,
    this.frequency,
    this.times = const [],
    this.startDate,
    this.endDate,
    this.stock,
    this.active = true,
    this.takenAt,
    this.skippedAt,
    this.missedAt,
    this.notes,
  });

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? time,
    bool? isTaken,
    bool? isSkipped,
    bool? isMissed,
    DateTime? date,
    String? patientId,
    String? frequency,
    List<String>? times,
    DateTime? startDate,
    DateTime? endDate,
    int? stock,
    bool? active,
    DateTime? takenAt,
    DateTime? skippedAt,
    DateTime? missedAt,
    String? notes,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      isTaken: isTaken ?? this.isTaken,
      isSkipped: isSkipped ?? this.isSkipped,
      isMissed: isMissed ?? this.isMissed,
      date: date ?? this.date,
      patientId: patientId ?? this.patientId,
      frequency: frequency ?? this.frequency,
      times: times ?? this.times,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      stock: stock ?? this.stock,
      active: active ?? this.active,
      takenAt: takenAt ?? this.takenAt,
      skippedAt: skippedAt ?? this.skippedAt,
      missedAt: missedAt ?? this.missedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'time': time,
      'isTaken': isTaken,
      'isSkipped': isSkipped,
      'isMissed': isMissed,
      'date': date.toIso8601String(),
      'patientId': patientId,
      'frequency': frequency,
      'times': times,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'stock': stock,
      'active': active,
      'takenAt': takenAt?.toIso8601String(),
      'skippedAt': skippedAt?.toIso8601String(),
      'missedAt': missedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      time: json['time'] as String,
      isTaken: json['isTaken'] as bool? ?? false,
      isSkipped: json['isSkipped'] as bool? ?? false,
      isMissed: json['isMissed'] as bool? ?? false,
      date: DateTime.parse(json['date'] as String),
      patientId: json['patientId'] as String?,
      frequency: json['frequency'] as String?,
      times: List<String>.from(json['times'] ?? []),
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
      stock: json['stock'] as int?,
      active: json['active'] as bool? ?? true,
      takenAt: json['takenAt'] != null ? DateTime.tryParse(json['takenAt'] as String) : null,
      skippedAt: json['skippedAt'] != null ? DateTime.tryParse(json['skippedAt'] as String) : null,
      missedAt: json['missedAt'] != null ? DateTime.tryParse(json['missedAt'] as String) : null,
      notes: json['notes'] as String?,
    );
  }

  factory Medication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Medication(
      id: doc.id,
      name: data['name'] as String? ?? '',
      dosage: data['dosage'] as String? ?? '',
      time: data['time'] as String? ?? '',
      isTaken: data['isTaken'] as bool? ?? false,
      isSkipped: data['isSkipped'] as bool? ?? false,
      isMissed: data['isMissed'] as bool? ?? false,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      patientId: data['patientId'] as String?,
      frequency: data['frequency'] as String?,
      times: List<String>.from(data['times'] ?? []),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      stock: (data['stock'] as num?)?.toInt(),
      active: data['active'] as bool? ?? true,
      takenAt: (data['takenAt'] as Timestamp?)?.toDate(),
      skippedAt: (data['skippedAt'] as Timestamp?)?.toDate(),
      missedAt: (data['missedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'dosage': dosage,
      'time': time,
      'isTaken': isTaken,
      'isSkipped': isSkipped,
      'isMissed': isMissed,
      'date': Timestamp.fromDate(date),
      'patientId': patientId,
      'frequency': frequency,
      'times': times,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'stock': stock,
      'active': active,
      'takenAt': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
      'skippedAt': skippedAt != null ? Timestamp.fromDate(skippedAt!) : null,
      'missedAt': missedAt != null ? Timestamp.fromDate(missedAt!) : null,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef MedicationModel = Medication;
