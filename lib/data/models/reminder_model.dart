import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderType { medicine, hydration, walking, familyTask, appointment, custom }

class Reminder {
  final String id;
  final String title;
  final String? description;
  final ReminderType type;
  final DateTime dateTime;
  final bool isCompleted;
  final String? assignedBy;
  final String? assignedTo;
  // Extended
  final String? patientId;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final bool? isMissed;

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
    this.createdAt,
    this.completedAt,
    this.isMissed,
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
    DateTime? createdAt,
    DateTime? completedAt,
    bool? isMissed,
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
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      isMissed: isMissed ?? this.isMissed,
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
      'patientId': patientId,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: ReminderType.values.firstWhere((e) => e.name == json['type']),
      dateTime: DateTime.parse(json['dateTime'] as String),
      isCompleted: json['isCompleted'] as bool,
      assignedBy: json['assignedBy'] as String?,
      assignedTo: json['assignedTo'] as String?,
      patientId: json['patientId'] as String?,
    );
  }

  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reminder(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      type: ReminderType.values.firstWhere(
        (e) => e.name == (data['type'] as String? ?? 'custom'),
        orElse: () => ReminderType.custom,
      ),
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCompleted: data['isCompleted'] as bool? ?? false,
      assignedBy: data['assignedBy'] as String?,
      assignedTo: data['assignedTo'] as String?,
      patientId: data['patientId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      isMissed: data['isMissed'] as bool?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'dateTime': Timestamp.fromDate(dateTime),
      'isCompleted': isCompleted,
      'assignedBy': assignedBy,
      'assignedTo': assignedTo,
      'patientId': patientId,
      'isMissed': isMissed,
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
