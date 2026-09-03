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
  final String? phoneNumber;
  final String? email;
  final String? abhaId;
  final String? bloodGroup;
  final String? address;
  final String? emergencyContact;
  final DateTime? dateOfBirth;
  final List<String> medicalHistory;
  final String? fcmToken;
  final DateTime? admittedAt;
  final DateTime? dischargedAt;

  bool get isAdmitted => status.toLowerCase() == 'admitted';

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
    this.phoneNumber,
    this.email,
    this.abhaId,
    this.bloodGroup,
    this.address,
    this.emergencyContact,
    this.dateOfBirth,
    this.medicalHistory = const [],
    this.fcmToken,
    this.admittedAt,
    this.dischargedAt,
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
    String? phoneNumber,
    String? email,
    String? abhaId,
    String? bloodGroup,
    String? address,
    String? emergencyContact,
    DateTime? dateOfBirth,
    List<String>? medicalHistory,
    String? fcmToken,
    DateTime? admittedAt,
    DateTime? dischargedAt,
  }) {
    final effectivePhone = phone ?? phoneNumber ?? this.phone ?? this.phoneNumber;
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
      phone: effectivePhone,
      phoneNumber: phoneNumber ?? effectivePhone,
      email: email ?? this.email,
      abhaId: abhaId ?? this.abhaId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      fcmToken: fcmToken ?? this.fcmToken,
      admittedAt: admittedAt ?? this.admittedAt,
      dischargedAt: dischargedAt ?? this.dischargedAt,
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
      'phone': phone ?? phoneNumber,
      'phoneNumber': phoneNumber ?? phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (abhaId != null && abhaId!.isNotEmpty) 'abhaId': abhaId,
      'bloodGroup': bloodGroup,
      'address': address,
      'emergencyContact': emergencyContact,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'medicalHistory': medicalHistory,
      'admittedAt': admittedAt?.toIso8601String(),
      'dischargedAt': dischargedAt?.toIso8601String(),
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    final p = (json['phoneNumber'] as String?) ?? (json['phone'] as String?);
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
      phone: p,
      phoneNumber: p,
      email: json['email'] as String?,
      abhaId: json['abhaId'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
      address: json['address'] as String?,
      emergencyContact: json['emergencyContact'] as String?,
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.tryParse(json['dateOfBirth'] as String) : null,
      medicalHistory: List<String>.from(json['medicalHistory'] ?? []),
      admittedAt: json['admittedAt'] != null ? DateTime.tryParse(json['admittedAt'] as String) : null,
      dischargedAt: json['dischargedAt'] != null ? DateTime.tryParse(json['dischargedAt'] as String) : null,
    );
  }

  factory Patient.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final p = (data['phoneNumber'] as String?) ?? (data['phone'] as String?);
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
      phone: p,
      phoneNumber: p,
      email: data['email'] as String?,
      abhaId: data['abhaId'] as String?,
      bloodGroup: data['bloodGroup'] as String?,
      address: data['address'] as String?,
      emergencyContact: data['emergencyContact'] as String?,
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate(),
      medicalHistory: List<String>.from(data['medicalHistory'] ?? []),
      fcmToken: data['fcmToken'] as String?,
      admittedAt: (data['admittedAt'] as Timestamp?)?.toDate(),
      dischargedAt: (data['dischargedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final p = phoneNumber ?? phone;
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
      'phone': p,
      'phoneNumber': p,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (abhaId != null && abhaId!.isNotEmpty) 'abhaId': abhaId,
      'bloodGroup': bloodGroup,
      'address': address,
      'emergencyContact': emergencyContact,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'medicalHistory': medicalHistory,
      if (admittedAt != null) 'admittedAt': Timestamp.fromDate(admittedAt!),
      if (dischargedAt != null) 'dischargedAt': Timestamp.fromDate(dischargedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef PatientModel = Patient;
