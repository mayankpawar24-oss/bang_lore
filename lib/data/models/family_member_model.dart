enum HydrationStatus { needed, active, done }
enum WalkingStatus { needed, active, done }
enum MedicationStatus { needed, active, done }
enum CareTaskStatus { todo, active, done }

class CareTask {
  final String id;
  final String title;
  final CareTaskStatus status;
  final String? assignedTo;

  const CareTask({
    required this.id,
    required this.title,
    required this.status,
    this.assignedTo,
  });

  CareTask copyWith({
    String? id,
    String? title,
    CareTaskStatus? status,
    String? assignedTo,
  }) {
    return CareTask(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status.name,
      'assignedTo': assignedTo,
    };
  }

  factory CareTask.fromJson(Map<String, dynamic> json) {
    return CareTask(
      id: json['id'] as String,
      title: json['title'] as String,
      status: CareTaskStatus.values.firstWhere((e) => e.name == json['status']),
      assignedTo: json['assignedTo'] as String?,
    );
  }
}

class FamilyMember {
  final String id;
  final String name;
  final String relationship;
  final int generation;
  final String? avatarUrl;
  final List<String> knownConditions;
  final List<String> familyHistory;
  final String? careNeeds;
  final List<CareTask> careTasks;
  final HydrationStatus hydration;
  final WalkingStatus walking;
  final MedicationStatus medication;
  final double? positionX;
  final double? positionY;
  final List<String> connectedToIds;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    required this.generation,
    this.avatarUrl,
    required this.knownConditions,
    required this.familyHistory,
    this.careNeeds,
    required this.careTasks,
    required this.hydration,
    required this.walking,
    required this.medication,
    this.positionX,
    this.positionY,
    this.connectedToIds = const [],
  });

  FamilyMember copyWith({
    String? id,
    String? name,
    String? relationship,
    int? generation,
    String? avatarUrl,
    List<String>? knownConditions,
    List<String>? familyHistory,
    String? careNeeds,
    List<CareTask>? careTasks,
    HydrationStatus? hydration,
    WalkingStatus? walking,
    MedicationStatus? medication,
    double? positionX,
    double? positionY,
    List<String>? connectedToIds,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      generation: generation ?? this.generation,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      knownConditions: knownConditions ?? this.knownConditions,
      familyHistory: familyHistory ?? this.familyHistory,
      careNeeds: careNeeds ?? this.careNeeds,
      careTasks: careTasks ?? this.careTasks,
      hydration: hydration ?? this.hydration,
      walking: walking ?? this.walking,
      medication: medication ?? this.medication,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      connectedToIds: connectedToIds ?? this.connectedToIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'generation': generation,
      'avatarUrl': avatarUrl,
      'knownConditions': knownConditions,
      'familyHistory': familyHistory,
      'careNeeds': careNeeds,
      'careTasks': careTasks.map((t) => t.toJson()).toList(),
      'hydration': hydration.name,
      'walking': walking.name,
      'medication': medication.name,
      'positionX': positionX,
      'positionY': positionY,
      'connectedToIds': connectedToIds,
    };
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String,
      generation: json['generation'] as int,
      avatarUrl: json['avatarUrl'] as String?,
      knownConditions: List<String>.from(json['knownConditions']),
      familyHistory: List<String>.from(json['familyHistory']),
      careNeeds: json['careNeeds'] as String?,
      careTasks: (json['careTasks'] as List).map((t) => CareTask.fromJson(t)).toList(),
      hydration: HydrationStatus.values.firstWhere((e) => e.name == json['hydration']),
      walking: WalkingStatus.values.firstWhere((e) => e.name == json['walking']),
      medication: MedicationStatus.values.firstWhere((e) => e.name == json['medication']),
      positionX: (json['positionX'] as num?)?.toDouble(),
      positionY: (json['positionY'] as num?)?.toDouble(),
      connectedToIds: json['connectedToIds'] != null ? List<String>.from(json['connectedToIds']) : [],
    );
  }
}

typedef FamilyMemberModel = FamilyMember;
