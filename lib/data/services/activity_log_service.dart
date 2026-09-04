import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_log_model.dart';

class ActivityLogService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ActivityLogService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference _patientLogs(String patientId) =>
      _db.collection('patients').doc(patientId).collection('activityLogs');

  CollectionReference _doctorLogs(String doctorId) =>
      _db.collection('doctors').doc(doctorId).collection('activityLogs');

  CollectionReference get _rootLogs => _db.collection('activityLogs');

  Stream<List<ActivityLogModel>> streamLogs(String uid, {bool isDoctor = false}) {
    if (uid.isEmpty) return Stream.value([]);
    final col = isDoctor ? _doctorLogs(uid) : _patientLogs(uid);
    return col
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList());
  }

  Future<List<ActivityLogModel>> getLogs(String uid, {bool isDoctor = false}) async {
    if (uid.isEmpty) return [];
    try {
      final col = isDoctor ? _doctorLogs(uid) : _patientLogs(uid);
      final snap = await col
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      return snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();
    } catch (e) {
      dev.log('[FIRESTORE] Error reading activity logs: $e', error: e, name: 'ActivityLogService');
      return [];
    }
  }

  Future<void> logEvent({
    String? patientId,
    String? doctorId,
    String? appointmentId,
    String? medicationId,
    String? reportId,
    String? notificationType,
    String? deliveryStatus,
    required ActivityEventType eventType,
    required String title,
    required String description,
    String? actorUid,
    String? actorRole,
    String? actorName,
    Map<String, dynamic>? metadata,
  }) async {
    final effectivePatientId = patientId ?? '';
    final currentUid = _auth.currentUser?.uid ?? actorUid ?? 'system';
    final resolvedRole = actorRole ?? (currentUid == effectivePatientId ? 'patient' : (currentUid == doctorId ? 'doctor' : 'system'));
    final resolvedName = actorName ?? (_auth.currentUser?.displayName ?? 'User');

    final logId = _rootLogs.doc().id;
    final log = ActivityLogModel(
      id: logId,
      patientId: effectivePatientId,
      doctorUid: doctorId,
      appointmentId: appointmentId,
      medicationId: medicationId,
      reportId: reportId,
      notificationType: notificationType,
      deliveryStatus: deliveryStatus,
      actorUid: currentUid,
      actorRole: resolvedRole,
      actorName: resolvedName,
      eventType: eventType,
      title: title,
      description: description,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    final data = log.toFirestore();

    try {
      final batch = _db.batch();
      if (effectivePatientId.isNotEmpty) {
        batch.set(_patientLogs(effectivePatientId).doc(logId), data);
      }
      if (doctorId != null && doctorId.isNotEmpty) {
        batch.set(_doctorLogs(doctorId).doc(logId), data);
      }
      batch.set(_rootLogs.doc(logId), data);
      await batch.commit();
      dev.log('[FIRESTORE] [ACTIVITY] Logged ${eventType.name}: $title (patient: $effectivePatientId, doctor: $doctorId)', name: 'ActivityLogService');
    } catch (e) {
      dev.log('[FIRESTORE] [ACTIVITY] Failed to persist activity log: $e', error: e, name: 'ActivityLogService');
    }
  }
}
