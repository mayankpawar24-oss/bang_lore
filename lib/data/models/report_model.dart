import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportCategory {
  fhir,
  emr,
  lab,
  prescription,
  discharge,
  treatment,
  doctorNote,
  other,
}

class ReportModel {
  final String id;
  final String patientId;
  final String title;
  final ReportCategory category;
  final DateTime date;
  final String? doctorOrFacility;
  final String? summary;
  final String? rawContent;
  final Map<String, dynamic>? extractedData;
  final DateTime? followUpDate;
  final String? followUpInstructions;
  final bool sharedWithDoctor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReportModel({
    required this.id,
    required this.patientId,
    required this.title,
    required this.category,
    required this.date,
    this.doctorOrFacility,
    this.summary,
    this.rawContent,
    this.extractedData,
    this.followUpDate,
    this.followUpInstructions,
    this.sharedWithDoctor = true,
    this.createdAt,
    this.updatedAt,
  });

  ReportModel copyWith({
    String? id,
    String? patientId,
    String? title,
    ReportCategory? category,
    DateTime? date,
    String? doctorOrFacility,
    String? summary,
    String? rawContent,
    Map<String, dynamic>? extractedData,
    DateTime? followUpDate,
    String? followUpInstructions,
    bool? sharedWithDoctor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      doctorOrFacility: doctorOrFacility ?? this.doctorOrFacility,
      summary: summary ?? this.summary,
      rawContent: rawContent ?? this.rawContent,
      extractedData: extractedData ?? this.extractedData,
      followUpDate: followUpDate ?? this.followUpDate,
      followUpInstructions: followUpInstructions ?? this.followUpInstructions,
      sharedWithDoctor: sharedWithDoctor ?? this.sharedWithDoctor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReportModel(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      title: data['title'] as String? ?? 'Medical Document',
      category: ReportCategory.values.firstWhere(
        (e) => e.name == (data['category'] as String? ?? 'other'),
        orElse: () => ReportCategory.other,
      ),
      date: (data['date'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      doctorOrFacility: data['doctorOrFacility'] as String?,
      summary: data['summary'] as String?,
      rawContent: data['rawContent'] as String?,
      extractedData: data['extractedData'] as Map<String, dynamic>?,
      followUpDate: (data['followUpDate'] as Timestamp?)?.toDate(),
      followUpInstructions: data['followUpInstructions'] as String?,
      sharedWithDoctor: data['sharedWithDoctor'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'title': title,
      'category': category.name,
      'date': Timestamp.fromDate(date),
      'doctorOrFacility': doctorOrFacility,
      'summary': summary,
      'rawContent': rawContent,
      'extractedData': extractedData,
      'followUpDate': followUpDate != null ? Timestamp.fromDate(followUpDate!) : null,
      'followUpInstructions': followUpInstructions,
      'sharedWithDoctor': sharedWithDoctor,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'title': title,
      'category': category.name,
      'date': date.toIso8601String(),
      'doctorOrFacility': doctorOrFacility,
      'summary': summary,
      'rawContent': rawContent,
      'extractedData': extractedData,
      'followUpDate': followUpDate?.toIso8601String(),
      'followUpInstructions': followUpInstructions,
      'sharedWithDoctor': sharedWithDoctor,
    };
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      title: json['title'] as String? ?? 'Medical Document',
      category: ReportCategory.values.firstWhere(
        (e) => e.name == (json['category'] as String? ?? 'other'),
        orElse: () => ReportCategory.other,
      ),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      doctorOrFacility: json['doctorOrFacility'] as String?,
      summary: json['summary'] as String?,
      rawContent: json['rawContent'] as String?,
      extractedData: json['extractedData'] as Map<String, dynamic>?,
      followUpDate: json['followUpDate'] != null
          ? DateTime.tryParse(json['followUpDate'] as String)
          : null,
      followUpInstructions: json['followUpInstructions'] as String?,
      sharedWithDoctor: json['sharedWithDoctor'] as bool? ?? true,
    );
  }
}
