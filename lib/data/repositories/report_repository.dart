import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import '../models/reminder_model.dart';
import '../models/medical_history_model.dart';

abstract class ReportRepository {
  Future<void> uploadReport(ReportModel report);
  Future<List<ReportModel>> getReports(String patientId);
  Stream<List<ReportModel>> reportsStream(String patientId);
  Future<void> deleteReport(String patientId, String reportId);
}

class FirebaseReportRepository implements ReportRepository {
  final FirebaseFirestore _db;

  FirebaseReportRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _reports(String patientId) =>
      _db.collection('patients').doc(patientId).collection('reports');

  @override
  Stream<List<ReportModel>> reportsStream(String patientId) {
    return _reports(patientId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReportModel.fromFirestore(d)).toList());
  }

  @override
  Future<List<ReportModel>> getReports(String patientId) async {
    final snap = await _reports(patientId).orderBy('date', descending: true).get();
    return snap.docs.map((d) => ReportModel.fromFirestore(d)).toList();
  }

  @override
  Future<void> uploadReport(ReportModel report) async {
    dev.log('[FIRESTORE] [REPORT] Uploading report "${report.title}" for patient ${report.patientId}', name: 'ReportRepository');
    final batch = _db.batch();
    
    // 1. Save Report Document
    final reportDocId = report.id.isNotEmpty ? report.id : _reports(report.patientId).doc().id;
    final reportRef = _reports(report.patientId).doc(reportDocId);
    final reportData = {
      ...report.copyWith(id: reportDocId).toFirestoreCreate(),
    };
    batch.set(reportRef, reportData);

    // 2. If report contains structured medical condition/diagnosis, save to medicalHistory
    if (report.title.isNotEmpty && (report.category == ReportCategory.discharge || report.category == ReportCategory.treatment || report.category == ReportCategory.emr)) {
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

    // 3. If report contains follow-up date/instruction, automatically schedule a reminder
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

    // 4. Create timeline notification for the patient
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
    dev.log('[FIRESTORE] [REPORT] Report $reportDocId persisted and synced to timeline/reminders', name: 'ReportRepository');
  }

  @override
  Future<void> deleteReport(String patientId, String reportId) async {
    await _reports(patientId).doc(reportId).delete();
  }
}
