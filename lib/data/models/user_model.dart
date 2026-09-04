import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { patient, doctor }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final String? phone;
  final String? phoneNumber;
  final String? abhaId;
  final String? telegramChatId;
  final bool telegramConnected;
  final String? familyId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get uid => id;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.phoneNumber,
    this.abhaId,
    this.telegramChatId,
    this.telegramConnected = false,
    this.familyId,
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
    String? phoneNumber,
    String? abhaId,
    String? telegramChatId,
    bool? telegramConnected,
    String? familyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final effectivePhone = phone ?? phoneNumber ?? this.phone ?? this.phoneNumber;
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: effectivePhone,
      phoneNumber: phoneNumber ?? effectivePhone,
      abhaId: abhaId ?? this.abhaId,
      telegramChatId: telegramChatId ?? this.telegramChatId,
      telegramConnected: telegramConnected ?? this.telegramConnected,
      familyId: familyId ?? this.familyId,
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
      'phone': phone ?? phoneNumber,
      'phoneNumber': phoneNumber ?? phone,
      if (abhaId != null && abhaId!.isNotEmpty) 'abhaId': abhaId,
      'telegramChatId': telegramChatId,
      'telegramConnected': telegramConnected,
      if (familyId != null) 'familyId': familyId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final p = (json['phoneNumber'] as String?) ?? (json['phone'] as String?);
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String? ?? '',
      role: UserRole.values.firstWhere((e) => e.name == json['role']),
      avatarUrl: json['avatarUrl'] as String?,
      phone: p,
      phoneNumber: p,
      abhaId: json['abhaId'] as String?,
      telegramChatId: json['telegramChatId'] as String?,
      telegramConnected: json['telegramConnected'] as bool? ?? false,
      familyId: json['familyId'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  /// Create from Firestore document snapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final p = (data['phoneNumber'] as String?) ?? (data['phone'] as String?);
    return UserModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == (data['role'] as String? ?? 'patient'),
        orElse: () => UserRole.patient,
      ),
      avatarUrl: data['photoUrl'] as String?,
      phone: p,
      phoneNumber: p,
      abhaId: data['abhaId'] as String?,
      telegramChatId: data['telegramChatId'] as String?,
      telegramConnected: data['telegramConnected'] as bool? ?? false,
      familyId: data['familyId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    final p = phoneNumber ?? phone;
    return {
      'uid': id,
      'name': name,
      if (email.isNotEmpty) 'email': email,
      'role': role.name,
      'photoUrl': avatarUrl,
      'phone': p,
      'phoneNumber': p,
      if (abhaId != null && abhaId!.isNotEmpty) 'abhaId': abhaId,
      'telegramChatId': telegramChatId,
      'telegramConnected': telegramConnected,
      if (familyId != null) 'familyId': familyId,
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
