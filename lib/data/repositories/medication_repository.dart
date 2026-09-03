import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_model.dart';

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
  FirebaseMedicationRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _meds(String patientId) =>
      _db.collection('patients').doc(patientId).collection('medications');

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
    await ref.set({
      ...withId.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateMedication(String patientId, Medication medication) async {
    await _meds(patientId).doc(medication.id).set(
          medication.toFirestore(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> markTaken(String patientId, String medicationId) async {
    await _meds(patientId).doc(medicationId).update({
      'isTaken': true,
      'isSkipped': false,
      'takenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markSkipped(String patientId, String medicationId) async {
    await _meds(patientId).doc(medicationId).update({
      'isTaken': false,
      'isSkipped': true,
      'skippedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markMissed(String patientId, String medicationId) async {
    await _meds(patientId).doc(medicationId).update({
      'isTaken': false,
      'isMissed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteMedication(String patientId, String medicationId) async {
    try {
      dev.log('[MEDICATION] Deleting medication $medicationId for patient $patientId', name: 'MedicationRepository');
      await _meds(patientId).doc(medicationId).delete();
      await _db.collection('patients').doc(patientId).collection('reminders').doc('rem_$medicationId').delete().catchError((_) {});
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
