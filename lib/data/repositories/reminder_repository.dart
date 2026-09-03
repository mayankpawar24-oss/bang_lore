import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';

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
  FirebaseReminderRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _reminders(String patientId) =>
      _db.collection('patients').doc(patientId).collection('reminders');

  @override
  Stream<List<Reminder>> remindersStream(String patientId) {
    return _reminders(patientId)
        .orderBy('dateTime')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Reminder.fromFirestore(d)).toList());
  }

  @override
  Future<List<Reminder>> getReminders(String userId) async {
    final snap = await _reminders(userId).orderBy('dateTime').get();
    return snap.docs.map((d) => Reminder.fromFirestore(d)).toList();
  }

  @override
  Future<void> addReminder(String patientId, Reminder reminder) async {
    final ref = reminder.id.isNotEmpty && !reminder.id.startsWith('rem_')
        ? _reminders(patientId).doc(reminder.id)
        : _reminders(patientId).doc();
    final withId = reminder.copyWith(id: ref.id);
    await ref.set({
      ...withId.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateReminder(String patientId, Reminder reminder) async {
    await _reminders(patientId).doc(reminder.id).set(
          reminder.toFirestore(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> completeReminder(String patientId, String reminderId) async {
    await _reminders(patientId).doc(reminderId).update({
      'isCompleted': true,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteReminder(String patientId, String reminderId) async {
    await _reminders(patientId).doc(reminderId).delete();
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
    if (idx >= 0) _reminders[idx] = _reminders[idx].copyWith(isCompleted: true);
  }

  @override
  Future<void> deleteReminder(String patientId, String reminderId) async {
    _reminders.removeWhere((r) => r.id == reminderId);
  }
}
