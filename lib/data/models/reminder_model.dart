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

  const Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.dateTime,
    required this.isCompleted,
    this.assignedBy,
    this.assignedTo,
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
    );
  }
}

typedef ReminderModel = Reminder;
