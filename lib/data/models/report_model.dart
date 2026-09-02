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
  // Firebase Storage Document Metadata
  final String? documentId;
  final String? fileName;
  final String? fileType;
  final String? storagePath;
  final String? downloadUrl;
  final String? uploadedBy;
  final DateTime? uploadedAt;
  final String? documentCategory;

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
    this.documentId,
    this.fileName,
    this.fileType,
    this.storagePath,
    this.downloadUrl,
    this.uploadedBy,
    this.uploadedAt,
    this.documentCategory,
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
    String? documentId,
    String? fileName,
    String? fileType,
    String? storagePath,
    String? downloadUrl,
    String? uploadedBy,
    DateTime? uploadedAt,
    String? documentCategory,
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
      documentId: documentId ?? this.documentId,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      documentCategory: documentCategory ?? this.documentCategory,
    );
  }

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final docId = data['documentId'] as String? ?? doc.id;
    final catName = data['documentCategory'] as String? ?? data['category'] as String? ?? 'other';
    final uploadedAtDate = (data['uploadedAt'] as Timestamp?)?.toDate();

    return ReportModel(
      id: doc.id,
      patientId: data['patientId'] as String? ?? data['uploadedBy'] as String? ?? '',
      title: data['title'] as String? ?? data['fileName'] as String? ?? 'Medical Document',
      category: ReportCategory.values.firstWhere(
        (e) => e.name == catName,
        orElse: () => ReportCategory.other,
      ),
      date: (data['date'] as Timestamp?)?.toDate() ??
          uploadedAtDate ??
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
      documentId: docId,
      fileName: data['fileName'] as String?,
      fileType: data['fileType'] as String?,
      storagePath: data['storagePath'] as String?,
      downloadUrl: data['downloadUrl'] as String?,
      uploadedBy: data['uploadedBy'] as String? ?? data['patientId'] as String?,
      uploadedAt: uploadedAtDate,
      documentCategory: catName,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'documentId': documentId ?? id,
      'patientId': patientId,
      'title': title,
      'category': category.name,
      'documentCategory': documentCategory ?? category.name,
      'fileName': fileName ?? title,
      'fileType': fileType ?? 'application/pdf',
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'uploadedBy': uploadedBy ?? patientId,
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : FieldValue.serverTimestamp(),
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
      'documentId': documentId ?? id,
      'patientId': patientId,
      'title': title,
      'category': category.name,
      'documentCategory': documentCategory ?? category.name,
      'fileName': fileName,
      'fileType': fileType,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'uploadedBy': uploadedBy ?? patientId,
      'uploadedAt': uploadedAt?.toIso8601String(),
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
    final catName = json['documentCategory'] as String? ?? json['category'] as String? ?? 'other';
    return ReportModel(
      id: json['id'] as String? ?? json['documentId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? json['uploadedBy'] as String? ?? '',
      title: json['title'] as String? ?? json['fileName'] as String? ?? 'Medical Document',
      category: ReportCategory.values.firstWhere(
        (e) => e.name == catName,
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
      documentId: json['documentId'] as String?,
      fileName: json['fileName'] as String?,
      fileType: json['fileType'] as String?,
      storagePath: json['storagePath'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      uploadedBy: json['uploadedBy'] as String?,
      uploadedAt: json['uploadedAt'] != null ? DateTime.tryParse(json['uploadedAt'] as String) : null,
      documentCategory: catName,
    );
  }
}
