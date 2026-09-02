import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String id;
  final String name;
  final String dosage;
  final String time;
  final bool isTaken;
  final DateTime date;
  // Extended
  final String? patientId;
  final String? frequency;
  final List<String> times;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? stock;
  final bool active;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.isTaken,
    required this.date,
    this.patientId,
    this.frequency,
    this.times = const [],
    this.startDate,
    this.endDate,
    this.stock,
    this.active = true,
  });

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? time,
    bool? isTaken,
    DateTime? date,
    String? patientId,
    String? frequency,
    List<String>? times,
    DateTime? startDate,
    DateTime? endDate,
    int? stock,
    bool? active,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      isTaken: isTaken ?? this.isTaken,
      date: date ?? this.date,
      patientId: patientId ?? this.patientId,
      frequency: frequency ?? this.frequency,
      times: times ?? this.times,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      stock: stock ?? this.stock,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'time': time,
      'isTaken': isTaken,
      'date': date.toIso8601String(),
      'patientId': patientId,
      'frequency': frequency,
      'times': times,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'stock': stock,
      'active': active,
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      time: json['time'] as String,
      isTaken: json['isTaken'] as bool,
      date: DateTime.parse(json['date'] as String),
      patientId: json['patientId'] as String?,
      frequency: json['frequency'] as String?,
      times: List<String>.from(json['times'] ?? []),
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
      stock: json['stock'] as int?,
      active: json['active'] as bool? ?? true,
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
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      patientId: data['patientId'] as String?,
      frequency: data['frequency'] as String?,
      times: List<String>.from(data['times'] ?? []),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      stock: (data['stock'] as num?)?.toInt(),
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'dosage': dosage,
      'time': time,
      'isTaken': isTaken,
      'date': Timestamp.fromDate(date),
      'patientId': patientId,
      'frequency': frequency,
      'times': times,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'stock': stock,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef MedicationModel = Medication;
