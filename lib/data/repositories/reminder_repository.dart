import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';

abstract class ReminderRepository {
  Future<List<Reminder>> getReminders(String userId);
  Future<void> addReminder(String patientId, Reminder reminder);
  Future<void> updateReminder(String patientId, Reminder reminder);
  Future<void> completeReminder(String patientId, String reminderId);
  Future<void> deleteReminder(String patientId, String reminderId);
  Stream<List<Reminder>> remindersStream(String patientId);
}

class FirebaseReminderRepository implements ReminderRepository {
  final FirebaseFirestore _db;
  final ActivityLogService? _activityLogService;

  FirebaseReminderRepository({
    FirebaseFirestore? db,
    ActivityLogService? activityLogService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _activityLogService = activityLogService;

  CollectionReference _reminders(String patientId) =>
      _db.collection('patients').doc(patientId).collection('reminders');

  @override
  Stream<List<Reminder>> remindersStream(String patientId) {
    if (patientId.isEmpty) return Stream.value([]);
    return _reminders(patientId)
        .orderBy('dateTime')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Reminder.fromFirestore(d)).toList());
  }

  @override
  Future<List<Reminder>> getReminders(String userId) async {
    if (userId.isEmpty) return [];
    final snap = await _reminders(userId).orderBy('dateTime').get();
    return snap.docs.map((d) => Reminder.fromFirestore(d)).toList();
  }

  @override
  Future<void> addReminder(String patientId, Reminder reminder) async {
    final targetPatientId = (reminder.patientId != null && reminder.patientId!.isNotEmpty)
        ? reminder.patientId!
        : patientId;
    final creatorId = reminder.createdBy ?? patientId;

    final docId = reminder.id.isNotEmpty && !reminder.id.startsWith('rem_')
        ? reminder.id
        : 'rem_${DateTime.now().millisecondsSinceEpoch}';

    final withIds = reminder.copyWith(
      id: docId,
      patientId: targetPatientId,
      createdBy: creatorId,
    );

    final batch = _db.batch();

    // 1. Root /reminders/{id} document
    final rootRef = _db.collection('reminders').doc(docId);
    batch.set(rootRef, withIds.toFirestoreCreate());

    // 2. Subcollection /patients/{targetPatientId}/reminders/{id}
    final patientRef = _reminders(targetPatientId).doc(docId);
    batch.set(patientRef, withIds.toFirestoreCreate());

    await batch.commit();

    // 3. Log event
    try {
      final isForFamily = targetPatientId != creatorId;
      await _activityLogService?.logEvent(
        patientId: targetPatientId,
        eventType: ActivityEventType.medicineAdded,
        title: isForFamily ? 'Reminder Created for Family Member' : 'Medication Reminder Created',
        description: isForFamily
            ? 'Created reminder: ${reminder.medicineName ?? reminder.title} for family member.'
            : 'Created reminder: ${reminder.medicineName ?? reminder.title}.',
        actorUid: creatorId,
        actorRole: 'patient',
        metadata: {
          'reminderId': docId,
          'targetPatientId': targetPatientId,
          'isForFamily': isForFamily,
        },
      );
    } catch (e) {
      dev.log('Activity log failed: $e', name: 'FirebaseReminderRepository');
    }
  }

  @override
  Future<void> updateReminder(String patientId, Reminder reminder) async {
    final targetPatientId = reminder.patientId ?? patientId;
    final batch = _db.batch();
    batch.set(_db.collection('reminders').doc(reminder.id), reminder.toFirestore(), SetOptions(merge: true));
    batch.set(_reminders(targetPatientId).doc(reminder.id), reminder.toFirestore(), SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<void> completeReminder(String patientId, String reminderId) async {
    final updateData = {
      'isCompleted': true,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.update(_db.collection('reminders').doc(reminderId), updateData);
    batch.update(_reminders(patientId).doc(reminderId), updateData);
    await batch.commit();

    try {
      await _activityLogService?.logEvent(
        patientId: patientId,
        eventType: ActivityEventType.medicineTaken,
        title: 'Medication Reminder Completed',
        description: 'Dose marked as taken.',
        actorUid: patientId,
        actorRole: 'patient',
        metadata: {'reminderId': reminderId},
      );
    } catch (_) {}
  }

  @override
  Future<void> deleteReminder(String patientId, String reminderId) async {
    final batch = _db.batch();
    batch.delete(_db.collection('reminders').doc(reminderId));
    batch.delete(_reminders(patientId).doc(reminderId));
    await batch.commit();
  }
}

// Mock for fallback
class MockReminderRepository implements ReminderRepository {
  final List<Reminder> _reminders = [];

  @override
  Stream<List<Reminder>> remindersStream(String patientId) => Stream.value(List.from(_reminders));

  @override
  Future<List<Reminder>> getReminders(String userId) async => List.from(_reminders);

  @override
  Future<void> addReminder(String patientId, Reminder reminder) async {
    _reminders.add(reminder);
  }

  @override
  Future<void> updateReminder(String patientId, Reminder reminder) async {
    final idx = _reminders.indexWhere((r) => r.id == reminder.id);
    if (idx >= 0) _reminders[idx] = reminder;
  }

  @override
  Future<void> completeReminder(String patientId, String reminderId) async {
    final idx = _reminders.indexWhere((r) => r.id == reminderId);
    if (idx >= 0) {
      _reminders[idx] = _reminders[idx].copyWith(isCompleted: true);
    }
  }

  @override
  Future<void> deleteReminder(String patientId, String reminderId) async {
    _reminders.removeWhere((r) => r.id == reminderId);
  }
}
