import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { appointment, medication, permission, sos, general, familyMessage, familyReminder }

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
  final String? recipientUid;
  final String? senderUid;
  final String? rawType;
  final String? relatedId;
  final String status;
  final DateTime? createdAt;
  final String? doctorName;
  final String? patientName;
  final String? requestId;
  final String? familyGroupId;
  final String? relatedMemberId;
  final String? priority; // 'critical', 'high', 'normal'
  final String? mapsUrl;
  final String? location;

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
    this.recipientUid,
    this.senderUid,
    this.rawType,
    this.relatedId,
    this.status = 'unread',
    this.createdAt,
    this.doctorName,
    this.patientName,
    this.requestId,
    this.familyGroupId,
    this.relatedMemberId,
    this.priority,
    this.mapsUrl,
    this.location,
  });

  String get notificationId => id;
  String? get recipientUserId => recipientUid;
  String? get senderUserId => senderUid;
  String get body => message;
  bool get read => isRead;
  String? get relatedEventId => relatedId ?? appointmentId ?? permissionId;
  bool get isCritical => priority == 'critical' || type == NotificationType.sos;
  String? get effectiveRequestId => requestId ?? permissionId ?? relatedId;
  String? get effectiveAppointmentId => appointmentId ?? relatedId;
  bool get isPending => status == 'pending';
  bool get isActioned => status == 'actioned' || status == 'approved';
  bool get isRejected => status == 'rejected';

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
    String? recipientUid,
    String? senderUid,
    String? rawType,
    String? relatedId,
    String? status,
    DateTime? createdAt,
    String? doctorName,
    String? patientName,
    String? requestId,
    String? familyGroupId,
    String? relatedMemberId,
    String? priority,
    String? mapsUrl,
    String? location,
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
      recipientUid: recipientUid ?? this.recipientUid,
      senderUid: senderUid ?? this.senderUid,
      rawType: rawType ?? this.rawType,
      relatedId: relatedId ?? this.relatedId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      doctorName: doctorName ?? this.doctorName,
      patientName: patientName ?? this.patientName,
      requestId: requestId ?? this.requestId,
      familyGroupId: familyGroupId ?? this.familyGroupId,
      relatedMemberId: relatedMemberId ?? this.relatedMemberId,
      priority: priority ?? this.priority,
      mapsUrl: mapsUrl ?? this.mapsUrl,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notificationId': id,
      'title': title,
      'message': message,
      'body': message,
      'timestamp': timestamp.toIso8601String(),
      'type': rawType ?? type.name,
      'isRead': isRead,
      'permissionId': permissionId,
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'patientId': patientId,
      'recipientUid': recipientUid,
      'recipientUserId': recipientUid,
      'senderUid': senderUid,
      'senderUserId': senderUid,
      'relatedId': relatedId ?? appointmentId ?? permissionId,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'doctorName': doctorName,
      'patientName': patientName,
      'requestId': requestId,
      'familyGroupId': familyGroupId,
      'relatedMemberId': relatedMemberId,
      'priority': priority,
      'mapsUrl': mapsUrl,
      'location': location,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? 'general').toLowerCase();
    NotificationType nType = NotificationType.general;
    if (typeStr.contains('appointment')) {
      nType = NotificationType.appointment;
    } else if (typeStr.contains('permission') || typeStr.contains('access')) {
      nType = NotificationType.permission;
    } else if (typeStr.contains('medication')) {
      nType = NotificationType.medication;
    } else if (typeStr.contains('sos')) {
      nType = NotificationType.sos;
    } else if (typeStr.contains('message') || typeStr.contains('chat')) {
      nType = NotificationType.familyMessage;
    } else if (typeStr.contains('remind')) {
      nType = NotificationType.familyReminder;
    }

    final parsedTimestamp = json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
        : DateTime.now();
    final parsedCreatedAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)
        : null;

    final isReadVal = json['isRead'] as bool? ?? (json['read'] as bool? ?? false);
    final statusVal = json['status'] as String? ?? (isReadVal ? 'read' : 'unread');

    return NotificationModel(
      id: json['id'] as String? ?? json['notificationId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? json['body'] as String? ?? '',
      timestamp: parsedTimestamp,
      type: nType,
      isRead: isReadVal,
      permissionId: json['permissionId'] as String?,
      appointmentId: json['appointmentId'] as String?,
      doctorId: json['doctorId'] as String?,
      patientId: json['patientId'] as String?,
      recipientUid: json['recipientUid'] as String? ?? json['recipientUserId'] as String?,
      senderUid: json['senderUid'] as String? ?? json['senderUserId'] as String?,
      rawType: json['type'] as String?,
      relatedId: json['relatedId'] as String?,
      status: statusVal,
      createdAt: parsedCreatedAt,
      doctorName: json['doctorName'] as String?,
      patientName: json['patientName'] as String?,
      requestId: json['requestId'] as String?,
      familyGroupId: json['familyGroupId'] as String?,
      relatedMemberId: json['relatedMemberId'] as String?,
      priority: json['priority'] as String?,
      mapsUrl: json['mapsUrl'] as String?,
      location: json['location'] as String?,
    );
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawTypeStr = (data['type'] as String? ?? 'general').toLowerCase();

    NotificationType nType = NotificationType.general;
    if (rawTypeStr.contains('appointment')) {
      nType = NotificationType.appointment;
    } else if (rawTypeStr.contains('permission') || rawTypeStr.contains('access')) {
      nType = NotificationType.permission;
    } else if (rawTypeStr.contains('medication')) {
      nType = NotificationType.medication;
    } else if (rawTypeStr.contains('sos')) {
      nType = NotificationType.sos;
    } else if (rawTypeStr.contains('message') || rawTypeStr.contains('chat')) {
      nType = NotificationType.familyMessage;
    } else if (rawTypeStr.contains('remind')) {
      nType = NotificationType.familyReminder;
    }

    final isReadVal = data['isRead'] as bool? ?? (data['read'] as bool? ?? false);
    final statusVal = data['status'] as String? ?? (isReadVal ? 'read' : 'unread');

    final dt = (data['timestamp'] as Timestamp?)?.toDate() ??
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final cAt = (data['createdAt'] as Timestamp?)?.toDate();

    final permId = data['permissionId'] as String? ?? data['requestId'] as String?;
    final apptId = data['appointmentId'] as String? ?? data['relatedId'] as String?;
    final reqId = data['requestId'] as String? ?? data['permissionId'] as String?;
    final relId = data['relatedId'] as String? ?? apptId ?? permId;

    return NotificationModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? data['body'] as String? ?? '',
      timestamp: dt,
      type: nType,
      isRead: isReadVal,
      permissionId: permId,
      appointmentId: apptId,
      doctorId: data['doctorId'] as String?,
      patientId: data['patientId'] as String?,
      recipientUid: data['recipientUid'] as String? ?? data['recipientUserId'] as String?,
      senderUid: data['senderUid'] as String? ?? data['senderUserId'] as String?,
      rawType: data['type'] as String?,
      relatedId: relId,
      status: statusVal,
      createdAt: cAt,
      doctorName: data['doctorName'] as String?,
      patientName: data['patientName'] as String?,
      requestId: reqId,
      familyGroupId: data['familyGroupId'] as String?,
      relatedMemberId: data['relatedMemberId'] as String?,
      priority: data['priority'] as String?,
      mapsUrl: data['mapsUrl'] as String?,
      location: data['location'] as String?,
    );
  }
}

