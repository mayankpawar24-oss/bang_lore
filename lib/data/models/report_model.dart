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
  // Document Metadata & Storage
  final String? documentId;
  final String? fileName;
  final String? fileType;
  final String? storagePath;
  final String? storageReference;
  final String? protonDriveReference;
  final String? downloadUrl;
  final String? uploadedBy;
  final String? uploaderId;
  final String? uploaderRole;
  final DateTime? uploadedAt;
  final String? documentCategory;
  final bool ocrCompleted;

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
    this.storageReference,
    this.protonDriveReference,
    this.downloadUrl,
    this.uploadedBy,
    this.uploaderId,
    this.uploaderRole,
    this.uploadedAt,
    this.documentCategory,
    this.ocrCompleted = false,
  });

  String? get fileUrl => downloadUrl ?? storagePath;

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
    String? storageReference,
    String? protonDriveReference,
    String? downloadUrl,
    String? uploadedBy,
    String? uploaderId,
    String? uploaderRole,
    DateTime? uploadedAt,
    String? documentCategory,
    bool? ocrCompleted,
  }) {
    final effectiveUploaderId = uploaderId ?? uploadedBy ?? this.uploaderId ?? this.uploadedBy;
    final effectiveStorageRef = storageReference ?? storagePath ?? this.storageReference ?? this.storagePath;
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
      storagePath: effectiveStorageRef,
      storageReference: effectiveStorageRef,
      protonDriveReference: protonDriveReference ?? this.protonDriveReference,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      uploadedBy: effectiveUploaderId,
      uploaderId: effectiveUploaderId,
      uploaderRole: uploaderRole ?? this.uploaderRole,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      documentCategory: documentCategory ?? this.documentCategory,
      ocrCompleted: ocrCompleted ?? this.ocrCompleted,
    );
  }

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final docId = data['documentId'] as String? ?? doc.id;
    final catName = data['documentCategory'] as String? ?? data['category'] as String? ?? 'other';
    final uploadedAtDate = (data['uploadedAt'] as Timestamp?)?.toDate();
    final uploader = data['uploaderId'] as String? ?? data['uploadedBy'] as String? ?? data['patientId'] as String?;
    final sRef = data['storageReference'] as String? ?? data['storagePath'] as String?;

    return ReportModel(
      id: doc.id,
      patientId: data['patientId'] as String? ?? uploader ?? '',
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
      storagePath: sRef,
      storageReference: sRef,
      protonDriveReference: data['protonDriveReference'] as String?,
      downloadUrl: data['downloadUrl'] as String?,
      uploadedBy: uploader,
      uploaderId: uploader,
      uploaderRole: data['uploaderRole'] as String?,
      uploadedAt: uploadedAtDate,
      documentCategory: catName,
      ocrCompleted: data['ocrCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    final sRef = storageReference ?? storagePath;
    final uploader = uploaderId ?? uploadedBy ?? patientId;
    return {
      'documentId': documentId ?? id,
      'patientId': patientId,
      'uploaderId': uploader,
      'uploaderRole': uploaderRole ?? 'patient',
      'title': title,
      'category': category.name,
      'documentCategory': documentCategory ?? category.name,
      'fileName': fileName ?? title,
      'fileType': fileType ?? 'application/pdf',
      'storagePath': sRef,
      'storageReference': sRef,
      'protonDriveReference': protonDriveReference,
      'downloadUrl': downloadUrl,
      'uploadedBy': uploader,
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : FieldValue.serverTimestamp(),
      'date': Timestamp.fromDate(date),
      'doctorOrFacility': doctorOrFacility,
      'summary': summary,
      'rawContent': rawContent,
      'extractedData': extractedData,
      'ocrCompleted': ocrCompleted,
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
    final sRef = storageReference ?? storagePath;
    final uploader = uploaderId ?? uploadedBy ?? patientId;
    return {
      'id': id,
      'documentId': documentId ?? id,
      'patientId': patientId,
      'uploaderId': uploader,
      'uploaderRole': uploaderRole,
      'title': title,
      'category': category.name,
      'documentCategory': documentCategory ?? category.name,
      'fileName': fileName,
      'fileType': fileType,
      'storagePath': sRef,
      'storageReference': sRef,
      'protonDriveReference': protonDriveReference,
      'downloadUrl': downloadUrl,
      'uploadedBy': uploader,
      'uploadedAt': uploadedAt?.toIso8601String(),
      'date': date.toIso8601String(),
      'doctorOrFacility': doctorOrFacility,
      'summary': summary,
      'rawContent': rawContent,
      'extractedData': extractedData,
      'ocrCompleted': ocrCompleted,
      'followUpDate': followUpDate?.toIso8601String(),
      'followUpInstructions': followUpInstructions,
      'sharedWithDoctor': sharedWithDoctor,
    };
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final catName = json['documentCategory'] as String? ?? json['category'] as String? ?? 'other';
    final uploader = json['uploaderId'] as String? ?? json['uploadedBy'] as String? ?? json['patientId'] as String?;
    final sRef = json['storageReference'] as String? ?? json['storagePath'] as String?;
    return ReportModel(
      id: json['id'] as String? ?? json['documentId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? uploader ?? '',
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
      storagePath: sRef,
      storageReference: sRef,
      protonDriveReference: json['protonDriveReference'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      uploadedBy: uploader,
      uploaderId: uploader,
      uploaderRole: json['uploaderRole'] as String?,
      uploadedAt: json['uploadedAt'] != null ? DateTime.tryParse(json['uploadedAt'] as String) : null,
      documentCategory: catName,
      ocrCompleted: json['ocrCompleted'] as bool? ?? false,
    );
  }
}
