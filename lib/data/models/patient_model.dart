class Patient {
  final String id;
  final String name;
  final int age;
  final String condition;
  final String status;
  final double medicationAdherence;
  final String? avatarUrl;
  final String? connectedDoctorId;
  final Map<String, dynamic>? vitals;
  final List<String> conditions;
  final bool isAuthorized;

  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.condition,
    required this.status,
    required this.medicationAdherence,
    this.avatarUrl,
    this.connectedDoctorId,
    this.vitals,
    required this.conditions,
    required this.isAuthorized,
  });

  Patient copyWith({
    String? id,
    String? name,
    int? age,
    String? condition,
    String? status,
    double? medicationAdherence,
    String? avatarUrl,
    String? connectedDoctorId,
    Map<String, dynamic>? vitals,
    List<String>? conditions,
    bool? isAuthorized,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      condition: condition ?? this.condition,
      status: status ?? this.status,
      medicationAdherence: medicationAdherence ?? this.medicationAdherence,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      connectedDoctorId: connectedDoctorId ?? this.connectedDoctorId,
      vitals: vitals ?? this.vitals,
      conditions: conditions ?? this.conditions,
      isAuthorized: isAuthorized ?? this.isAuthorized,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'condition': condition,
      'status': status,
      'medicationAdherence': medicationAdherence,
      'avatarUrl': avatarUrl,
      'connectedDoctorId': connectedDoctorId,
      'vitals': vitals,
      'conditions': conditions,
      'isAuthorized': isAuthorized,
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      condition: json['condition'] as String,
      status: json['status'] as String,
      medicationAdherence: (json['medicationAdherence'] as num).toDouble(),
      avatarUrl: json['avatarUrl'] as String?,
      connectedDoctorId: json['connectedDoctorId'] as String?,
      vitals: json['vitals'] as Map<String, dynamic>?,
      conditions: List<String>.from(json['conditions']),
      isAuthorized: json['isAuthorized'] as bool,
    );
  }
}

typedef PatientModel = Patient;
