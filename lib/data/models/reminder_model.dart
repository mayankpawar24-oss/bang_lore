import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderType { medicine, medication, hydration, walking, familyTask, appointment, custom }

class Reminder {
  final String id;
  final String title;
  final String? description;
  final ReminderType type;
  final DateTime dateTime;
  final bool isCompleted;
  final String? assignedBy;
  final String? assignedTo;
  // Extended & Target-Specific Fields
  final String? patientId;
  final String? createdBy;
  final String? targetUid;
  final String? creatorUid;
  final String? familyId;
  final String? medicineName;
  final String? dosage;
  final String? reminderTime;
  final String? frequency;
  final String status; // 'pending', 'completed', 'missed', 'skipped'
  final bool telegramEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final bool? isMissed;
  final String? targetPatientName;

  String? get createdByUserId => creatorUid ?? createdBy;
  String? get targetUserId => targetUid ?? patientId;

  const Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.dateTime,
    required this.isCompleted,
    this.assignedBy,
    this.assignedTo,
    this.patientId,
    this.createdBy,
    this.targetUid,
    this.creatorUid,
    this.familyId,
    this.medicineName,
    this.dosage,
    this.reminderTime,
    this.frequency,
    this.status = 'pending',
    this.telegramEnabled = true,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.isMissed,
    this.targetPatientName,
  });

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    ReminderType? type,
    DateTime? dateTime,
    bool? isCompleted,
    String? assignedBy,
    String? assignedTo,
    String? patientId,
    String? createdBy,
    String? targetUid,
    String? creatorUid,
    String? familyId,
    String? medicineName,
    String? dosage,
    String? reminderTime,
    String? frequency,
    String? status,
    bool? telegramEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool? isMissed,
    String? targetPatientName,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      dateTime: dateTime ?? this.dateTime,
      isCompleted: isCompleted ?? this.isCompleted,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedTo: assignedTo ?? this.assignedTo,
      patientId: patientId ?? this.patientId,
      createdBy: createdBy ?? this.createdBy,
      targetUid: targetUid ?? this.targetUid,
      creatorUid: creatorUid ?? this.creatorUid,
      familyId: familyId ?? this.familyId,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      reminderTime: reminderTime ?? this.reminderTime,
      frequency: frequency ?? this.frequency,
      status: status ?? this.status,
      telegramEnabled: telegramEnabled ?? this.telegramEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      isMissed: isMissed ?? this.isMissed,
      targetPatientName: targetPatientName ?? this.targetPatientName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'dateTime': dateTime.toIso8601String(),
      'isCompleted': isCompleted,
      'assignedBy': assignedBy,
      'assignedTo': assignedTo,
      'patientId': patientId ?? targetUid,
      'targetUid': targetUid ?? patientId,
      'targetUserId': targetUid ?? patientId,
      'createdBy': createdBy ?? creatorUid ?? assignedBy,
      'creatorUid': creatorUid ?? createdBy ?? assignedBy,
      'createdByUserId': creatorUid ?? createdBy ?? assignedBy,
      'familyId': familyId,
      'medicineName': medicineName,
      'dosage': dosage,
      'reminderTime': reminderTime,
      'frequency': frequency,
      'status': status,
      'telegramEnabled': telegramEnabled,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final tUid = json['targetUserId'] as String? ?? json['targetUid'] as String? ?? json['patientId'] as String?;
    final cUid = json['createdByUserId'] as String? ?? json['creatorUid'] as String? ?? json['createdBy'] as String? ?? json['assignedBy'] as String?;
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: ReminderType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ReminderType.custom,
      ),
      dateTime: DateTime.parse(json['dateTime'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      assignedBy: json['assignedBy'] as String?,
      assignedTo: json['assignedTo'] as String?,
      patientId: tUid,
      targetUid: tUid,
      createdBy: cUid,
      creatorUid: cUid,
      familyId: json['familyId'] as String?,
      medicineName: json['medicineName'] as String?,
      dosage: json['dosage'] as String?,
      reminderTime: json['reminderTime'] as String?,
      frequency: json['frequency'] as String?,
      status: json['status'] as String? ?? 'pending',
      telegramEnabled: json['telegramEnabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final isDone = data['isCompleted'] as bool? ?? (data['status'] == 'completed');
    final tUid = data['targetUserId'] as String? ?? data['targetUid'] as String? ?? data['patientId'] as String?;
    final cUid = data['createdByUserId'] as String? ?? data['creatorUid'] as String? ?? data['createdBy'] as String? ?? data['assignedBy'] as String?;

    return Reminder(
      id: doc.id,
      title: data['title'] as String? ?? data['medicineName'] as String? ?? 'Reminder',
      description: data['description'] as String?,
      type: ReminderType.values.firstWhere(
        (e) => e.name == (data['type'] as String? ?? 'custom'),
        orElse: () => ReminderType.custom,
      ),
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? (data['reminderTime'] is Timestamp ? (data['reminderTime'] as Timestamp).toDate() : DateTime.now()),
      isCompleted: isDone,
      assignedBy: data['assignedBy'] as String? ?? cUid,
      assignedTo: data['assignedTo'] as String? ?? tUid,
      patientId: tUid,
      targetUid: tUid,
      createdBy: cUid,
      creatorUid: cUid,
      familyId: data['familyId'] as String?,
      medicineName: data['medicineName'] as String?,
      dosage: data['dosage'] as String?,
      reminderTime: data['reminderTime'] is String ? data['reminderTime'] as String? : null,
      frequency: data['frequency'] as String?,
      status: data['status'] as String? ?? (isDone ? 'completed' : 'pending'),
      telegramEnabled: data['telegramEnabled'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      isMissed: data['isMissed'] as bool? ?? (data['status'] == 'missed'),
    );
  }

  Map<String, dynamic> toFirestore() {
    final tUid = targetUid ?? patientId;
    final cUid = creatorUid ?? createdBy ?? assignedBy;
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'dateTime': Timestamp.fromDate(dateTime),
      'isCompleted': isCompleted,
      'assignedBy': assignedBy ?? cUid,
      'assignedTo': assignedTo ?? tUid,
      'patientId': tUid,
      'targetUid': tUid,
      'targetUserId': tUid,
      'createdBy': cUid,
      'creatorUid': cUid,
      'createdByUserId': cUid,
      'familyId': familyId,
      'medicineName': medicineName ?? title,
      'dosage': dosage,
      'reminderTime': reminderTime ?? Timestamp.fromDate(dateTime),
      'frequency': frequency ?? 'Daily',
      'status': isCompleted ? 'completed' : (isMissed == true ? 'missed' : status),
      'telegramEnabled': telegramEnabled,
      'isMissed': isMissed ?? false,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
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

typedef ReminderModel = Reminder;
