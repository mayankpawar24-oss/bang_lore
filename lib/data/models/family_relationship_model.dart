import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyRelationshipPermissions {
  final bool basicProfile;
  final bool appointments;
  final bool medications;
  final bool reports;
  final bool emergency;

  const FamilyRelationshipPermissions({
    this.basicProfile = true,
    this.appointments = true,
    this.medications = true,
    this.reports = false,
    this.emergency = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'basicProfile': basicProfile,
      'appointments': appointments,
      'medications': medications,
      'reports': reports,
      'emergency': emergency,
    };
  }

  factory FamilyRelationshipPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FamilyRelationshipPermissions();
    return FamilyRelationshipPermissions(
      basicProfile: map['basicProfile'] as bool? ?? true,
      appointments: map['appointments'] as bool? ?? true,
      medications: map['medications'] as bool? ?? true,
      reports: map['reports'] as bool? ?? false,
      emergency: map['emergency'] as bool? ?? true,
    );
  }
}

class FamilyRelationshipModel {
  final String id;
  final String ownerUid;
  final String memberUid;
  final String relationship; // 'Parent', 'Child', 'Spouse', 'Sibling', 'Grandparent', 'Grandchild', 'Other', 'Self'
  final String status; // 'pending', 'approved', 'rejected'
  final FamilyRelationshipPermissions permissions;
  final double positionX;
  final double positionY;
  final List<String> connectedToIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Embedded transient / resolved fields from member's profile
  final String? memberName;
  final String? memberPhone;
  final String? memberAbha;
  final int? memberAge;
  final String? memberAvatar;
  final String? memberHealthStatus;

  // Backwards compatibility aliases
  String get patientId => ownerUid;
  String get familyMemberId => memberUid;

  FamilyRelationshipModel({
    required this.id,
    String? ownerUid,
    String? memberUid,
    String? patientId,
    String? familyMemberId,
    required this.relationship,
    this.status = 'approved',
    this.permissions = const FamilyRelationshipPermissions(),
    this.positionX = 1200.0,
    this.positionY = 800.0,
    this.connectedToIds = const [],
    required this.createdAt,
    this.updatedAt,
    this.memberName,
    this.memberPhone,
    this.memberAbha,
    this.memberAge,
    this.memberAvatar,
    this.memberHealthStatus,
  })  : ownerUid = ownerUid ?? patientId ?? '',
        memberUid = memberUid ?? familyMemberId ?? '';

  /// Calculates sensible hierarchical coordinates relative to the patient node
  static Offset calculateSensiblePosition(String relationship, {Offset center = const Offset(1200.0, 800.0), int siblingIndex = 0}) {
    final rel = relationship.trim().toLowerCase();
    switch (rel) {
      case 'grandparent':
        return Offset(center.dx - 160.0 + (siblingIndex * 320.0), center.dy - 340.0);
      case 'parent':
      case 'father':
      case 'mother':
        return Offset(center.dx - 140.0 + (siblingIndex * 280.0), center.dy - 180.0);
      case 'spouse':
      case 'husband':
      case 'wife':
      case 'partner':
        return Offset(center.dx + 240.0, center.dy);
      case 'sibling':
      case 'brother':
      case 'sister':
        return Offset(center.dx - 240.0 - (siblingIndex * 180.0), center.dy);
      case 'child':
      case 'son':
      case 'daughter':
        return Offset(center.dx - 140.0 + (siblingIndex * 280.0), center.dy + 180.0);
      case 'grandchild':
        return Offset(center.dx - 160.0 + (siblingIndex * 320.0), center.dy + 340.0);
      case 'self':
        return center;
      default:
        return Offset(center.dx + 220.0 + (siblingIndex * 160.0), center.dy + 120.0);
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'ownerUid': ownerUid,
      'memberUid': memberUid,
      'patientId': ownerUid, // alias for backwards compatibility
      'familyMemberId': memberUid, // alias
      'relationship': relationship,
      'status': status,
      'permissions': permissions.toMap(),
      'positionX': positionX,
      'positionY': positionY,
      'connectedToIds': connectedToIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory FamilyRelationshipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final owner = (data['ownerUid'] ?? data['patientId']) as String? ?? '';
    final member = (data['memberUid'] ?? data['familyMemberId']) as String? ?? '';

    return FamilyRelationshipModel(
      id: doc.id,
      ownerUid: owner,
      memberUid: member,
      relationship: data['relationship'] as String? ?? 'Member',
      status: data['status'] as String? ?? 'approved',
      permissions: FamilyRelationshipPermissions.fromMap(data['permissions'] as Map<String, dynamic>?),
      positionX: (data['positionX'] as num?)?.toDouble() ?? 1200.0,
      positionY: (data['positionY'] as num?)?.toDouble() ?? 800.0,
      connectedToIds: (data['connectedToIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  FamilyRelationshipModel copyWith({
    String? id,
    String? ownerUid,
    String? memberUid,
    String? relationship,
    String? status,
    FamilyRelationshipPermissions? permissions,
    double? positionX,
    double? positionY,
    List<String>? connectedToIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? memberName,
    String? memberPhone,
    String? memberAbha,
    int? memberAge,
    String? memberAvatar,
    String? memberHealthStatus,
  }) {
    return FamilyRelationshipModel(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      memberUid: memberUid ?? this.memberUid,
      relationship: relationship ?? this.relationship,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      connectedToIds: connectedToIds ?? this.connectedToIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberName: memberName ?? this.memberName,
      memberPhone: memberPhone ?? this.memberPhone,
      memberAbha: memberAbha ?? this.memberAbha,
      memberAge: memberAge ?? this.memberAge,
      memberAvatar: memberAvatar ?? this.memberAvatar,
      memberHealthStatus: memberHealthStatus ?? this.memberHealthStatus,
    );
  }

  FamilyRelationshipModel copyWithResolvedData({
    String? memberName,
    String? memberPhone,
    String? memberAbha,
    int? memberAge,
    String? memberAvatar,
    String? memberHealthStatus,
  }) {
    return copyWith(
      memberName: memberName,
      memberPhone: memberPhone,
      memberAbha: memberAbha,
      memberAge: memberAge,
      memberAvatar: memberAvatar,
      memberHealthStatus: memberHealthStatus,
    );
  }
}
