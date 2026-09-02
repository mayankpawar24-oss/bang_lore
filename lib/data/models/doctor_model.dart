import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String hospital;
  final double rating;
  final double distance;
  final String avatarUrl;
  final String phone;
  final String about;
  final List<String> availableDays;
  final bool isAvailable;
  // Extended
  final String? licenseNumber;
  final String? uid;
  final DateTime? createdAt;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.rating,
    required this.distance,
    required this.avatarUrl,
    required this.phone,
    required this.about,
    required this.availableDays,
    required this.isAvailable,
    this.licenseNumber,
    this.uid,
    this.createdAt,
  });

  Doctor copyWith({
    String? id,
    String? name,
    String? specialty,
    String? hospital,
    double? rating,
    double? distance,
    String? avatarUrl,
    String? phone,
    String? about,
    List<String>? availableDays,
    bool? isAvailable,
    String? licenseNumber,
    String? uid,
    DateTime? createdAt,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      hospital: hospital ?? this.hospital,
      rating: rating ?? this.rating,
      distance: distance ?? this.distance,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      about: about ?? this.about,
      availableDays: availableDays ?? this.availableDays,
      isAvailable: isAvailable ?? this.isAvailable,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialty': specialty,
      'hospital': hospital,
      'rating': rating,
      'distance': distance,
      'avatarUrl': avatarUrl,
      'phone': phone,
      'about': about,
      'availableDays': availableDays,
      'isAvailable': isAvailable,
      'licenseNumber': licenseNumber,
      'uid': uid,
    };
  }

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] as String,
      name: json['name'] as String,
      specialty: json['specialty'] as String,
      hospital: json['hospital'] as String,
      rating: (json['rating'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      avatarUrl: json['avatarUrl'] as String,
      phone: json['phone'] as String,
      about: json['about'] as String,
      availableDays: List<String>.from(json['availableDays']),
      isAvailable: json['isAvailable'] as bool,
      licenseNumber: json['licenseNumber'] as String?,
      uid: json['uid'] as String?,
    );
  }

  factory Doctor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Doctor(
      id: doc.id,
      name: data['name'] as String? ?? '',
      specialty: data['specialty'] as String? ?? '',
      hospital: data['hospital'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
      avatarUrl: data['avatarUrl'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      about: data['about'] as String? ?? '',
      availableDays: List<String>.from(data['availableDays'] ?? []),
      isAvailable: data['isAvailable'] as bool? ?? true,
      licenseNumber: data['licenseNumber'] as String?,
      uid: data['uid'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid ?? id,
      'name': name,
      'specialty': specialty,
      'hospital': hospital,
      'rating': rating,
      'distance': distance,
      'avatarUrl': avatarUrl,
      'phone': phone,
      'about': about,
      'availableDays': availableDays,
      'isAvailable': isAvailable,
      'licenseNumber': licenseNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef DoctorModel = Doctor;
