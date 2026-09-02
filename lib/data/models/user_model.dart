import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { patient, doctor }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.createdAt,
    this.updatedAt,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? avatarUrl,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'avatarUrl': avatarUrl,
      'phone': phone,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.values.firstWhere((e) => e.name == json['role']),
      avatarUrl: json['avatarUrl'] as String?,
      phone: json['phone'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  /// Create from Firestore document snapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == (data['role'] as String? ?? 'patient'),
        orElse: () => UserRole.patient,
      ),
      avatarUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'uid': id,
      'name': name,
      'email': email,
      'role': role.name,
      'photoUrl': avatarUrl,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Map for initial creation (includes createdAt)
  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
