import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityEventType {
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
  medicineTaken,
  medicineSkipped,
  reminderCreated,
  reminderCompleted,
  reminderMissed,
  chatStarted,
  chatAccessGranted,
  chatAccessDenied,
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
    this.metadata,
  });

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
      patientId: data['patientId'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      actorRole: data['actorRole'] as String? ?? 'patient',
      actorName: data['actorName'] as String? ?? 'User',
      eventType: type,
      title: data['title'] as String? ?? 'Activity',
      description: data['description'] as String? ?? '',
      timestamp: ts,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'patientId': patientId,
      'actorUid': actorUid,
      'actorRole': actorRole,
      'actorName': actorName,
      'eventType': eventType.name,
      'title': title,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(timestamp),
      'metadata': metadata ?? {},
    };
  }
}
