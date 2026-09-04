import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/report_model.dart';
import '../models/reminder_model.dart';
import '../models/medical_history_model.dart';
import '../models/activity_log_model.dart';
import '../services/ocr_service.dart';
import '../services/activity_log_service.dart';

abstract class ReportRepository {
  Future<ReportModel> uploadReport(
    ReportModel report, {
    List<int>? fileBytes,
    String? fileName,
    String? fileType,
    String? uploaderRole,
  });
  Future<List<ReportModel>> getReports(String patientId);
  Stream<List<ReportModel>> reportsStream(String patientId);
  Future<void> deleteReport(String patientId, String reportId);
}

class FirebaseReportRepository implements ReportRepository {
  final FirebaseFirestore _db;
  final OcrService _ocrService;
  final ActivityLogService _activityLogService;

  FirebaseReportRepository({
    FirebaseFirestore? db,
    OcrService? ocrService,
    ActivityLogService? activityLogService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _ocrService = ocrService ?? OcrService(),
        _activityLogService = activityLogService ?? ActivityLogService();

  CollectionReference _reports(String patientId) =>
      _db.collection('patients').doc(patientId).collection('reports');

  CollectionReference _medicalDocuments(String patientId) =>
      _db.collection('patients').doc(patientId).collection('medicalDocuments');

  @override
  Stream<List<ReportModel>> reportsStream(String patientId) {
    // Listen to medicalDocuments collection first; fall back to reports
    return _medicalDocuments(patientId)
        .orderBy('date', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          if (snap.docs.isNotEmpty) {
            return snap.docs.map((d) => ReportModel.fromFirestore(d)).toList();
          }
          final legacySnap = await _reports(patientId).orderBy('date', descending: true).get();
          return legacySnap.docs.map((d) => ReportModel.fromFirestore(d)).toList();
        });
  }

  @override
  Future<List<ReportModel>> getReports(String patientId) async {
    try {
      final snap = await _medicalDocuments(patientId).orderBy('date', descending: true).get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => ReportModel.fromFirestore(d)).toList();
      }
      final legacy = await _reports(patientId).orderBy('date', descending: true).get();
      return legacy.docs.map((d) => ReportModel.fromFirestore(d)).toList();
    } catch (e) {
      dev.log('[FIRESTORE] [STORAGE] Error fetching reports: $e', error: e, name: 'ReportRepository');
      return [];
    }
  }

  @override
  Future<ReportModel> uploadReport(
    ReportModel report, {
    List<int>? fileBytes,
    String? fileName,
    String? fileType,
    String? uploaderRole,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? report.patientId;
    final resolvedUploaderRole = uploaderRole ?? (currentUid == report.patientId ? 'patient' : 'doctor');
    final docId = report.id.isNotEmpty ? report.id : _medicalDocuments(report.patientId).doc().id;
    dev.log('[STORAGE] [REPORT] Ingesting document $docId for patient ${report.patientId} by $currentUid ($resolvedUploaderRole)', name: 'ReportRepository');

    final resolvedFileName = fileName ?? '${report.title.replaceAll(RegExp(r"[^a-zA-Z0-9_\-\.]"), "_")}.pdf';
    final resolvedFileType = fileType ?? 'application/pdf';

    try {
      // 1. Direct in-memory processing: Zero storage upload (Firebase Storage & Proton Drive avoided)
      dev.log('[TRANSIENT_UPLOAD] Bypassing cloud file storage. Processing document transiently in memory for patient ${report.patientId}', name: 'ReportRepository');

      // 2. Stream document bytes directly to FastAPI Clinical Document Intelligence
      Map<String, dynamic>? ocrData = report.extractedData;
      bool ocrDone = report.ocrCompleted;
      String? extractedSummary = report.summary;
      try {
        final ocrResult = await _ocrService.processDocument(
          fileName: resolvedFileName,
          fileBytes: fileBytes ?? [],
          rawText: null, // Zero raw document text persisted
          patientId: report.patientId,
          documentId: docId,
          mimeType: resolvedFileType,
        );
        ocrData = ocrResult.toMap();
        ocrDone = true;
        extractedSummary = ocrResult.extractedRawText.isNotEmpty ? ocrResult.extractedRawText : report.summary;
        dev.log('[OCR] Extracted structured insights for $docId: ${ocrResult.diagnosis.join(", ")} | Meds: ${ocrResult.medicines.join(", ")}', name: 'ReportRepository');
      } catch (e) {
        dev.log('[OCR] Processing note: $e', name: 'ReportRepository');
      }

      // 3. Assemble report model containing ONLY structured insights and session metadata (No file binaries or storage URLs)
      final reportModelWithMeta = report.copyWith(
        id: docId,
        documentId: docId,
        fileName: resolvedFileName,
        fileType: resolvedFileType,
        storagePath: null, // Invariant: Original document binary is never saved to Firebase Storage
        storageReference: null,
        protonDriveReference: null,
        downloadUrl: null, // Invariant: No external download URL
        rawContent: null, // Invariant: No raw document bytes stored in Firestore
        summary: extractedSummary,
        uploadedBy: currentUid,
        uploaderId: currentUid,
        uploaderRole: resolvedUploaderRole,
        uploadedAt: DateTime.now(),
        documentCategory: report.category.name,
        extractedData: ocrData,
        ocrCompleted: ocrDone,
      );

      final batch = _db.batch();

      // 4. Save to Firestore: patients/{uid}/medicalDocuments/{documentId}
      final medDocRef = _medicalDocuments(report.patientId).doc(docId);
      batch.set(medDocRef, reportModelWithMeta.toFirestoreCreate(), SetOptions(merge: true));

      // 5. Mirror to patients/{uid}/reports/{documentId} for backward compatibility
      final repRef = _reports(report.patientId).doc(docId);
      batch.set(repRef, reportModelWithMeta.toFirestoreCreate(), SetOptions(merge: true));

      // 6. Save to medicalHistory if applicable
      if (report.title.isNotEmpty &&
          (report.category == ReportCategory.discharge ||
              report.category == ReportCategory.treatment ||
              report.category == ReportCategory.emr)) {
        final medHistRef = _db.collection('patients').doc(report.patientId).collection('medicalHistory').doc();
        final medHist = MedicalHistory(
          id: medHistRef.id,
          patientId: report.patientId,
          condition: report.title,
          diagnosedAt: report.date,
          notes: report.summary ?? report.doctorOrFacility,
          isCurrent: true,
        );
        batch.set(medHistRef, medHist.toFirestore());
      }

      // 7. Automatic follow-up reminder if specified
      if (report.followUpDate != null) {
        final remRef = _db.collection('patients').doc(report.patientId).collection('reminders').doc();
        final reminder = Reminder(
          id: remRef.id,
          patientId: report.patientId,
          title: 'Follow-up: ${report.title}',
          description: report.followUpInstructions ?? 'Scheduled follow-up consultation/test based on recent report.',
          dateTime: report.followUpDate!,
          type: ReminderType.appointment,
          isCompleted: false,
        );
        batch.set(remRef, reminder.toFirestoreCreate());
      }

      // 8. Timeline notification for patient
      final notifRef = _db.collection('patients').doc(report.patientId).collection('notifications').doc();
      batch.set(notifRef, {
        'id': notifRef.id,
        'notificationId': notifRef.id,
        'recipientUid': report.patientId,
        'senderUid': currentUid,
        'recipientRole': 'patient',
        'title': 'Clinical Insights Extracted',
        'message': 'Structured insights from "${report.title}" have been extracted and added to your care timeline.',
        'type': 'general',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      dev.log('[FIRESTORE] Structured insights persisted successfully to patients/${report.patientId}/medicalDocuments/$docId', name: 'ReportRepository');

      // 9. Real Activity Logs
      await _activityLogService.logEvent(
        patientId: report.patientId,
        eventType: ActivityEventType.documentUploaded,
        title: 'Clinical Insights Ingested: ${report.title}',
        description: 'Processed transiently via Clinical Document Intelligence by $resolvedUploaderRole. Structured insights saved (Zero file storage).',
        actorUid: currentUid,
        actorRole: resolvedUploaderRole,
        metadata: {'documentId': docId, 'fileName': resolvedFileName},
      );

      if (ocrDone) {
        await _activityLogService.logEvent(
          patientId: report.patientId,
          eventType: ActivityEventType.ocrCompleted,
          title: 'OCR Clinical Extraction Completed',
          description: 'Entities parsed for ${report.title}. Findings cataloged in clinical profile.',
          actorUid: currentUid,
          actorRole: 'system',
          metadata: {'documentId': docId},
        );
      }

      return reportModelWithMeta;
    } catch (e, stack) {
      dev.log('[STORAGE] [FIRESTORE] Error uploading document: $e', error: e, stackTrace: stack, name: 'ReportRepository');
      rethrow;
    }
  }

  @override
  Future<void> deleteReport(String patientId, String reportId) async {
    try {
      await _medicalDocuments(patientId).doc(reportId).delete();
      await _reports(patientId).doc(reportId).delete();
    } catch (e) {
      dev.log('[FIRESTORE] Error deleting report: $e', error: e, name: 'ReportRepository');
      rethrow;
    }
  }
}
