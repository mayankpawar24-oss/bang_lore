import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_model.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';

abstract class MedicationRepository {
  Future<List<Medication>> getMedications(String patientId);
  Future<void> addMedication(String patientId, Medication medication);
  Future<void> updateMedication(String patientId, Medication medication);
  Future<void> markTaken(String patientId, String medicationId);
  Future<void> markSkipped(String patientId, String medicationId);
  Future<void> markMissed(String patientId, String medicationId);
  Future<void> deleteMedication(String patientId, String medicationId);
  Stream<List<Medication>> medicationsStream(String patientId);
}

class FirebaseMedicationRepository implements MedicationRepository {
  final FirebaseFirestore _db;
  final ActivityLogService _activityLogService;

  FirebaseMedicationRepository({FirebaseFirestore? db, ActivityLogService? activityLogService})
      : _db = db ?? FirebaseFirestore.instance,
        _activityLogService = activityLogService ?? ActivityLogService(db: db);

  CollectionReference _meds(String patientId) =>
      _db.collection('patients').doc(patientId).collection('medications');

  CollectionReference get _rootMeds => _db.collection('medications');

  @override
  Stream<List<Medication>> medicationsStream(String patientId) {
    return _meds(patientId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Medication.fromFirestore(d)).toList());
  }

  @override
  Future<List<Medication>> getMedications(String patientId) async {
    final snap = await _meds(patientId).where('active', isEqualTo: true).get();
    return snap.docs.map((d) => Medication.fromFirestore(d)).toList();
  }

  @override
  Future<void> addMedication(String patientId, Medication medication) async {
    final ref = medication.id.isNotEmpty && !medication.id.startsWith('med_')
        ? _meds(patientId).doc(medication.id)
        : _meds(patientId).doc();
    final withId = medication.copyWith(id: ref.id, patientId: patientId);
    final data = {
      ...withId.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.set(ref, data, SetOptions(merge: true));
    batch.set(_rootMeds.doc(ref.id), data, SetOptions(merge: true));
    await batch.commit();

    try {
      await _activityLogService.logEvent(
        patientId: patientId,
        medicationId: ref.id,
        eventType: ActivityEventType.medicineAdded,
        title: 'Medication Added',
        description: 'Prescription added: ${medication.name} (${medication.dosage}) • ${medication.time}.',
      );
    } catch (_) {}
  }

  @override
  Future<void> updateMedication(String patientId, Medication medication) async {
    final data = medication.toFirestore();
    final batch = _db.batch();
    batch.set(_meds(patientId).doc(medication.id), data, SetOptions(merge: true));
    batch.set(_rootMeds.doc(medication.id), data, SetOptions(merge: true));
    await batch.commit();

    try {
      await _activityLogService.logEvent(
        patientId: patientId,
        medicationId: medication.id,
        eventType: ActivityEventType.medicationEdited,
        title: 'Medication Updated',
        description: 'Updated prescription: ${medication.name} (${medication.dosage}) • ${medication.time}.',
      );
    } catch (_) {}
  }

  @override
  Future<void> markTaken(String patientId, String medicationId) async {
    final updateData = {
      'isTaken': true,
      'isSkipped': false,
      'takenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.update(_meds(patientId).doc(medicationId), updateData);
    batch.update(_rootMeds.doc(medicationId), updateData);
    await batch.commit();

    try {
      await _activityLogService.logEvent(
        patientId: patientId,
        medicationId: medicationId,
        eventType: ActivityEventType.medicineTaken,
        title: 'Medication Taken',
        description: 'Marked dose as taken.',
      );
    } catch (_) {}
  }

  @override
  Future<void> markSkipped(String patientId, String medicationId) async {
    final updateData = {
      'isTaken': false,
      'isSkipped': true,
      'skippedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.update(_meds(patientId).doc(medicationId), updateData);
    batch.update(_rootMeds.doc(medicationId), updateData);
    await batch.commit();

    try {
      await _activityLogService.logEvent(
        patientId: patientId,
        medicationId: medicationId,
        eventType: ActivityEventType.medicineSkipped,
        title: 'Medication Skipped',
        description: 'Dose marked as skipped.',
      );
    } catch (_) {}
  }

  @override
  Future<void> markMissed(String patientId, String medicationId) async {
    final updateData = {
      'isTaken': false,
      'isMissed': true,
      'missedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.update(_meds(patientId).doc(medicationId), updateData);
    batch.update(_rootMeds.doc(medicationId), updateData);
    await batch.commit();

    try {
      await _activityLogService.logEvent(
        patientId: patientId,
        medicationId: medicationId,
        eventType: ActivityEventType.medicationMissed,
        title: 'Medication Missed',
        description: 'Scheduled dose was missed.',
      );
    } catch (_) {}
  }

  @override
  Future<void> deleteMedication(String patientId, String medicationId) async {
    try {
      dev.log('[MEDICATION] Deleting medication $medicationId for patient $patientId', name: 'MedicationRepository');
      final batch = _db.batch();
      batch.delete(_meds(patientId).doc(medicationId));
      batch.delete(_rootMeds.doc(medicationId));
      batch.delete(_db.collection('patients').doc(patientId).collection('reminders').doc('rem_$medicationId'));
      await batch.commit();

      try {
        await _activityLogService.logEvent(
          patientId: patientId,
          medicationId: medicationId,
          eventType: ActivityEventType.medicationDeleted,
          title: 'Medication Deleted',
          description: 'Medication reminder removed.',
        );
      } catch (_) {}
      dev.log('[MEDICATION] Successfully deleted medication and reminder for $medicationId', name: 'MedicationRepository');
    } catch (e) {
      dev.log('[MEDICATION] Error deleting medication $medicationId: $e', error: e, name: 'MedicationRepository');
      rethrow;
    }
  }
}

// Mock for fallback
class MockMedicationRepository implements MedicationRepository {
  final List<Medication> _meds = [];

  @override
  Stream<List<Medication>> medicationsStream(String patientId) => Stream.value(List.from(_meds));

  @override
  Future<List<Medication>> getMedications(String patientId) async => List.from(_meds);

  @override
  Future<void> addMedication(String patientId, Medication medication) async {
    _meds.add(medication);
  }

  @override
  Future<void> updateMedication(String patientId, Medication medication) async {
    final idx = _meds.indexWhere((m) => m.id == medication.id);
    if (idx >= 0) _meds[idx] = medication;
  }

  @override
  Future<void> markTaken(String patientId, String medicationId) async {
    final idx = _meds.indexWhere((m) => m.id == medicationId);
    if (idx >= 0) _meds[idx] = _meds[idx].copyWith(isTaken: true, isSkipped: false);
  }

  @override
  Future<void> markSkipped(String patientId, String medicationId) async {
    final idx = _meds.indexWhere((m) => m.id == medicationId);
    if (idx >= 0) _meds[idx] = _meds[idx].copyWith(isTaken: false, isSkipped: true);
  }

  @override
  Future<void> markMissed(String patientId, String medicationId) async {
    final idx = _meds.indexWhere((m) => m.id == medicationId);
    if (idx >= 0) _meds[idx] = _meds[idx].copyWith(isTaken: false);
  }

  @override
  Future<void> deleteMedication(String patientId, String medicationId) async {
    _meds.removeWhere((m) => m.id == medicationId);
  }
}
