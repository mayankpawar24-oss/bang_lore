import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/report_model.dart';
import '../models/reminder_model.dart';
import '../models/medical_history_model.dart';

abstract class ReportRepository {
  Future<ReportModel> uploadReport(
    ReportModel report, {
    List<int>? fileBytes,
    String? fileName,
    String? fileType,
  });
  Future<List<ReportModel>> getReports(String patientId);
  Stream<List<ReportModel>> reportsStream(String patientId);
  Future<void> deleteReport(String patientId, String reportId);
}

class FirebaseReportRepository implements ReportRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  FirebaseReportRepository({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

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
  }) async {
    final docId = report.id.isNotEmpty ? report.id : _medicalDocuments(report.patientId).doc().id;
    dev.log('[STORAGE] [REPORT] Ingesting document $docId for patient ${report.patientId}', name: 'ReportRepository');

    String? storagePath;
    String? downloadUrl;
    final resolvedFileName = fileName ?? '${report.title.replaceAll(RegExp(r"[^a-zA-Z0-9_\-\.]"), "_")}.pdf';
    final resolvedFileType = fileType ?? 'application/pdf';

    try {
      // 1. Upload to Firebase Storage if fileBytes provided
      if (fileBytes != null && fileBytes.isNotEmpty) {
        storagePath = 'patients/${report.patientId}/medicalDocuments/$docId/$resolvedFileName';
        dev.log('[STORAGE] Uploading bytes to $storagePath (${fileBytes.length} bytes)', name: 'ReportRepository');
        
        final storageRef = _storage.ref(storagePath);
        final metadata = SettableMetadata(
          contentType: resolvedFileType,
          customMetadata: {
            'documentId': docId,
            'patientId': report.patientId,
            'category': report.category.name,
            'uploadedBy': report.patientId,
          },
        );

        final uploadTask = await storageRef.putData(Uint8List.fromList(fileBytes), metadata);
        downloadUrl = await uploadTask.ref.getDownloadURL();
        dev.log('[STORAGE] File uploaded successfully. Download URL obtained: $downloadUrl', name: 'ReportRepository');
      }

      final reportModelWithMeta = report.copyWith(
        id: docId,
        documentId: docId,
        fileName: resolvedFileName,
        fileType: resolvedFileType,
        storagePath: storagePath,
        downloadUrl: downloadUrl,
        uploadedBy: report.patientId,
        uploadedAt: DateTime.now(),
        documentCategory: report.category.name,
      );

      final batch = _db.batch();

      // 2. Save to Firestore: patients/{uid}/medicalDocuments/{documentId}
      final medDocRef = _medicalDocuments(report.patientId).doc(docId);
      batch.set(medDocRef, reportModelWithMeta.toFirestoreCreate(), SetOptions(merge: true));

      // 3. Mirror to patients/{uid}/reports/{documentId} for backward compatibility
      final repRef = _reports(report.patientId).doc(docId);
      batch.set(repRef, reportModelWithMeta.toFirestoreCreate(), SetOptions(merge: true));

      // 4. Save to medicalHistory if applicable
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

      // 5. Automatic follow-up reminder if specified
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

      // 6. Timeline notification for patient
      final notifRef = _db.collection('patients').doc(report.patientId).collection('notifications').doc();
      batch.set(notifRef, {
        'title': 'Health Record Uploaded',
        'message': 'Your "${report.title}" has been safely encrypted and synced to your health timeline.',
        'type': 'general',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      dev.log('[FIRESTORE] Document metadata persisted successfully to patients/${report.patientId}/medicalDocuments/$docId', name: 'ReportRepository');
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
