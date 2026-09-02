import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { appointment, medication, permission, sos, general }

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? permissionId;
  final String? appointmentId;
  final String? doctorId;
  final String? patientId;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.isRead,
    this.permissionId,
    this.appointmentId,
    this.doctorId,
    this.patientId,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationType? type,
    bool? isRead,
    String? permissionId,
    String? appointmentId,
    String? doctorId,
    String? patientId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      permissionId: permissionId ?? this.permissionId,
      appointmentId: appointmentId ?? this.appointmentId,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'isRead': isRead,
      'permissionId': permissionId,
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'patientId': patientId,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: NotificationType.values.firstWhere((e) => e.name == json['type']),
      isRead: json['isRead'] as bool,
      permissionId: json['permissionId'] as String?,
      appointmentId: json['appointmentId'] as String?,
      doctorId: json['doctorId'] as String?,
      patientId: json['patientId'] as String?,
    );
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final typeStr = (data['type'] as String? ?? 'general').toLowerCase();
    NotificationType nType = NotificationType.general;
    if (typeStr.contains('appointment')) {
      nType = NotificationType.appointment;
    } else if (typeStr.contains('permission') || typeStr.contains('access')) {
      nType = NotificationType.permission;
    } else if (typeStr.contains('medication')) {
      nType = NotificationType.medication;
    } else if (typeStr.contains('sos')) {
      nType = NotificationType.sos;
    }

    return NotificationModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      type: nType,
      isRead: data['isRead'] as bool? ?? false,
      permissionId: data['permissionId'] as String?,
      appointmentId: data['appointmentId'] as String?,
      doctorId: data['doctorId'] as String?,
      patientId: data['patientId'] as String?,
    );
  }
}
