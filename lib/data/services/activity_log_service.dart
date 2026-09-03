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

  CollectionReference _logs(String patientId) =>
      _db.collection('patients').doc(patientId).collection('activityLogs');

  Stream<List<ActivityLogModel>> streamLogs(String patientId) {
    if (patientId.isEmpty) return Stream.value([]);
    return _logs(patientId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList());
  }

  Future<List<ActivityLogModel>> getLogs(String patientId) async {
    if (patientId.isEmpty) return [];
    try {
      final snap = await _logs(patientId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();
    } catch (e) {
      dev.log('[FIRESTORE] Error reading activity logs: $e', error: e, name: 'ActivityLogService');
      return [];
    }
  }

  Future<void> logEvent({
    required String patientId,
    required ActivityEventType eventType,
    required String title,
    required String description,
    String? actorUid,
    String? actorRole,
    String? actorName,
    Map<String, dynamic>? metadata,
  }) async {
    if (patientId.isEmpty) return;

    final currentUid = _auth.currentUser?.uid ?? actorUid ?? 'system';
    final resolvedRole = actorRole ?? (currentUid == patientId ? 'patient' : 'doctor');
    final resolvedName = actorName ?? (_auth.currentUser?.displayName ?? 'User');

    final docRef = _logs(patientId).doc();
    final log = ActivityLogModel(
      id: docRef.id,
      patientId: patientId,
      actorUid: currentUid,
      actorRole: resolvedRole,
      actorName: resolvedName,
      eventType: eventType,
      title: title,
      description: description,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    try {
      await docRef.set(log.toFirestore());
      dev.log('[FIRESTORE] [ACTIVITY] Logged ${eventType.name} for patient $patientId: $title', name: 'ActivityLogService');
    } catch (e) {
      dev.log('[FIRESTORE] [ACTIVITY] Failed to persist activity log: $e', error: e, name: 'ActivityLogService');
    }
  }
}
