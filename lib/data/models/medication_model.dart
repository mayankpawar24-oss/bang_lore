class Medication {
  final String id;
  final String name;
  final String dosage;
  final String time;
  final bool isTaken;
  final DateTime date;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.isTaken,
    required this.date,
  });

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? time,
    bool? isTaken,
    DateTime? date,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      isTaken: isTaken ?? this.isTaken,
      date: date ?? this.date,
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
    );
  }
}

typedef MedicationModel = Medication;
