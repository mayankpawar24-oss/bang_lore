import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityEventType {
  patientCreated,
  patientUpdated,
  documentUploaded,
  documentViewed,
  ocrCompleted,
  aiInsightGenerated,
  appointmentRequested,
  appointmentApproved,
  appointmentRejected,
  appointmentCancelled,
  appointmentCompleted,
  appointmentMissed,
  profileAccessRequested,
  profileAccessApproved,
  profileAccessRejected,
  accessRequested,
  accessApproved,
  accessRejected,
  admissionChanged,
  admission,
  discharge,
  medicineAdded,
  medicationEdited,
  medicationDeleted,
  medicineTaken,
  medicineSkipped,
  medicationMissed,
  reminderCreated,
  reminderCompleted,
  reminderMissed,
  telegramLinked,
  telegramUnlinked,
  notificationSent,
  notificationFailed,
  chatStarted,
  chatAccessGranted,
  chatAccessDenied,
  familyMemberAdded,
  familyMemberRemoved,
  general,
}

class ActivityLogModel {
  final String id;
  final String patientId;
  final String actorUid;
  final String actorRole; // 'patient' | 'doctor' | 'system'
  final String actorName;
  final ActivityEventType eventType;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? doctorUid;
  final String? appointmentId;
  final String? medicationId;
  final String? reportId;
  final String? notificationType;
  final String? deliveryStatus; // 'sent' | 'failed' | 'pending'
  final Map<String, dynamic>? metadata;

  const ActivityLogModel({
    required this.id,
    required this.patientId,
    required this.actorUid,
    required this.actorRole,
    required this.actorName,
    required this.eventType,
    required this.title,
    required this.description,
    required this.timestamp,
    this.doctorUid,
    this.appointmentId,
    this.medicationId,
    this.reportId,
    this.notificationType,
    this.deliveryStatus,
    this.metadata,
  });

  String get eventId => id;
  String get patientUid => patientId;

  factory ActivityLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final eventName = (data['eventType'] as String? ?? 'general').toLowerCase();

    ActivityEventType type = ActivityEventType.general;
    for (final val in ActivityEventType.values) {
      if (val.name.toLowerCase() == eventName) {
        type = val;
        break;
      }
    }

    final ts = (data['timestamp'] as Timestamp?)?.toDate() ??
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();

    return ActivityLogModel(
      id: doc.id,
      patientId: data['patientUid'] as String? ?? data['patientId'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      actorRole: data['actorRole'] as String? ?? 'patient',
      actorName: data['actorName'] as String? ?? 'User',
      eventType: type,
      title: data['title'] as String? ?? 'Activity',
      description: data['description'] as String? ?? '',
      timestamp: ts,
      doctorUid: data['doctorUid'] as String?,
      appointmentId: data['appointmentId'] as String?,
      medicationId: data['medicationId'] as String?,
      reportId: data['reportId'] as String?,
      notificationType: data['notificationType'] as String?,
      deliveryStatus: data['deliveryStatus'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'eventId': id,
      'patientId': patientId,
      'patientUid': patientId,
      'actorUid': actorUid,
      'actorRole': actorRole,
      'actorName': actorName,
      'eventType': eventType.name,
      'title': title,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(timestamp),
      if (doctorUid != null) 'doctorUid': doctorUid,
      if (appointmentId != null) 'appointmentId': appointmentId,
      if (medicationId != null) 'medicationId': medicationId,
      if (reportId != null) 'reportId': reportId,
      if (notificationType != null) 'notificationType': notificationType,
      if (deliveryStatus != null) 'deliveryStatus': deliveryStatus,
      'metadata': metadata ?? {},
    };
  }
}
