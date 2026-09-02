import 'package:cloud_firestore/cloud_firestore.dart';

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
  // Extended fields
  final String? phone;
  final String? bloodGroup;
  final String? address;
  final String? emergencyContact;
  final DateTime? dateOfBirth;
  final List<String> medicalHistory;
  final String? fcmToken;

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
    this.phone,
    this.bloodGroup,
    this.address,
    this.emergencyContact,
    this.dateOfBirth,
    this.medicalHistory = const [],
    this.fcmToken,
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
    String? phone,
    String? bloodGroup,
    String? address,
    String? emergencyContact,
    DateTime? dateOfBirth,
    List<String>? medicalHistory,
    String? fcmToken,
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
      phone: phone ?? this.phone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      fcmToken: fcmToken ?? this.fcmToken,
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
      'phone': phone,
      'bloodGroup': bloodGroup,
      'address': address,
      'emergencyContact': emergencyContact,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'medicalHistory': medicalHistory,
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      name: json['name'] as String,
      age: (json['age'] as num?)?.toInt() ?? 0,
      condition: json['condition'] as String? ?? '',
      status: json['status'] as String? ?? 'stable',
      medicationAdherence: (json['medicationAdherence'] as num?)?.toDouble() ?? 0.0,
      avatarUrl: json['avatarUrl'] as String?,
      connectedDoctorId: json['connectedDoctorId'] as String?,
      vitals: json['vitals'] as Map<String, dynamic>?,
      conditions: List<String>.from(json['conditions'] ?? []),
      isAuthorized: json['isAuthorized'] as bool? ?? false,
      phone: json['phone'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
      address: json['address'] as String?,
      emergencyContact: json['emergencyContact'] as String?,
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.tryParse(json['dateOfBirth'] as String) : null,
      medicalHistory: List<String>.from(json['medicalHistory'] ?? []),
    );
  }

  factory Patient.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Patient(
      id: doc.id,
      name: data['name'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      condition: data['condition'] as String? ?? '',
      status: data['status'] as String? ?? 'stable',
      medicationAdherence: (data['medicationAdherence'] as num?)?.toDouble() ?? 0.0,
      avatarUrl: data['avatarUrl'] as String?,
      connectedDoctorId: data['connectedDoctorId'] as String?,
      vitals: data['vitals'] as Map<String, dynamic>?,
      conditions: List<String>.from(data['conditions'] ?? []),
      isAuthorized: data['isAuthorized'] as bool? ?? false,
      phone: data['phone'] as String?,
      bloodGroup: data['bloodGroup'] as String?,
      address: data['address'] as String?,
      emergencyContact: data['emergencyContact'] as String?,
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate(),
      medicalHistory: List<String>.from(data['medicalHistory'] ?? []),
      fcmToken: data['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
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
      'phone': phone,
      'bloodGroup': bloodGroup,
      'address': address,
      'emergencyContact': emergencyContact,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'medicalHistory': medicalHistory,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef PatientModel = Patient;
