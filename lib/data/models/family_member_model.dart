import 'package:cloud_firestore/cloud_firestore.dart';

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
  // Extended
  final String? gender;
  final int? birthYear;
  final String? notes;
  final List<String> parentIds;

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
    this.gender,
    this.birthYear,
    this.notes,
    this.parentIds = const [],
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
    String? gender,
    int? birthYear,
    String? notes,
    List<String>? parentIds,
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
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      notes: notes ?? this.notes,
      parentIds: parentIds ?? this.parentIds,
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
      'gender': gender,
      'birthYear': birthYear,
      'notes': notes,
      'parentIds': parentIds,
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
      gender: json['gender'] as String?,
      birthYear: json['birthYear'] as int?,
      notes: json['notes'] as String?,
      parentIds: json['parentIds'] != null ? List<String>.from(json['parentIds']) : [],
    );
  }

  factory FamilyMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyMember(
      id: doc.id,
      name: data['name'] as String? ?? '',
      relationship: data['relationship'] as String? ?? '',
      generation: (data['generation'] as num?)?.toInt() ?? 0,
      avatarUrl: data['avatarUrl'] as String?,
      knownConditions: List<String>.from(data['knownConditions'] ?? []),
      familyHistory: List<String>.from(data['familyHistory'] ?? []),
      careNeeds: data['careNeeds'] as String?,
      careTasks: (data['careTasks'] as List<dynamic>? ?? [])
          .map((t) => CareTask.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList(),
      hydration: HydrationStatus.values.firstWhere(
        (e) => e.name == (data['hydration'] as String? ?? 'done'),
        orElse: () => HydrationStatus.done,
      ),
      walking: WalkingStatus.values.firstWhere(
        (e) => e.name == (data['walking'] as String? ?? 'done'),
        orElse: () => WalkingStatus.done,
      ),
      medication: MedicationStatus.values.firstWhere(
        (e) => e.name == (data['medication'] as String? ?? 'done'),
        orElse: () => MedicationStatus.done,
      ),
      positionX: (data['positionX'] as num?)?.toDouble(),
      positionY: (data['positionY'] as num?)?.toDouble(),
      connectedToIds: List<String>.from(data['connectedToIds'] ?? []),
      gender: data['gender'] as String?,
      birthYear: (data['birthYear'] as num?)?.toInt(),
      notes: data['notes'] as String?,
      parentIds: List<String>.from(data['parentIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
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
      'gender': gender,
      'birthYear': birthYear,
      'notes': notes,
      'parentIds': parentIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef FamilyMemberModel = FamilyMember;
