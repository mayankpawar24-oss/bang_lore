import 'package:cloud_firestore/cloud_firestore.dart';

enum PermissionStatus { pending, approved, denied, revoked }

/// Granular access permission record — replaces old PermissionRequest
class AccessPermission {
  final String id;
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String patientName;
  final PermissionStatus status;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? expiresAt;
  /// List of permitted data types: profile, vitals, medications,
  /// appointments, medicalHistory, familyHistory, reports, aiChat
  final List<String> permissions;

  const AccessPermission({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    required this.status,
    required this.requestedAt,
    this.approvedAt,
    this.expiresAt,
    this.permissions = const ['profile'],
  });

  AccessPermission copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
    String? patientId,
    String? patientName,
    PermissionStatus? status,
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? expiresAt,
    List<String>? permissions,
  }) {
    return AccessPermission(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      permissions: permissions ?? this.permissions,
    );
  }

  bool get isActive =>
      status == PermissionStatus.approved &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  bool hasPermission(String type) => isActive && permissions.contains(type);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientId': patientId,
      'patientName': patientName,
      'status': status.name,
      'requestedAt': requestedAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'permissions': permissions,
    };
  }

  factory AccessPermission.fromJson(Map<String, dynamic> json) {
    return AccessPermission(
      id: json['id'] as String,
      doctorId: json['doctorId'] as String,
      doctorName: json['doctorName'] as String,
      patientId: json['patientId'] as String,
      patientName: json['patientName'] as String,
      status: PermissionStatus.values.firstWhere((e) => e.name == json['status']),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      approvedAt: json['approvedAt'] != null ? DateTime.tryParse(json['approvedAt'] as String) : null,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'] as String) : null,
      permissions: List<String>.from(json['permissions'] ?? ['profile']),
    );
  }

  factory AccessPermission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccessPermission(
      id: doc.id,
      doctorId: data['doctorId'] as String? ?? '',
      doctorName: data['doctorName'] as String? ?? '',
      patientId: data['patientId'] as String? ?? '',
      patientName: data['patientName'] as String? ?? '',
      status: PermissionStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'pending'),
        orElse: () => PermissionStatus.pending,
      ),
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      permissions: List<String>.from(data['permissions'] ?? ['profile']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientId': patientId,
      'patientName': patientName,
      'status': status.name,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Canonical document ID: doctorId_patientId
  static String docId(String doctorId, String patientId) => '_';
}

/// Backward-compatible alias
typedef PermissionRequest = AccessPermission;
typedef PermissionRequestModel = AccessPermission;
