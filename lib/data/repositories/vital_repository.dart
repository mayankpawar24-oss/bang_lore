import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vital_model.dart';

class FirebaseVitalRepository {
  final FirebaseFirestore _db;
  FirebaseVitalRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _vitals(String patientId) =>
      _db.collection('patients').doc(patientId).collection('vitals');

  Stream<List<Vital>> vitalsStream(String patientId) {
    return _vitals(patientId)
        .orderBy('recordedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Vital.fromFirestore(d)).toList());
  }

  Future<List<Vital>> getVitals(String patientId, {int limit = 20}) async {
    final snap = await _vitals(patientId)
        .orderBy('recordedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => Vital.fromFirestore(d)).toList();
  }

  Future<Vital?> getLatestVital(String patientId) async {
    final snap = await _vitals(patientId)
        .orderBy('recordedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Vital.fromFirestore(snap.docs.first);
  }

  Future<void> addVital(String patientId, Vital vital) async {
    final ref = _vitals(patientId).doc();
    await ref.set(vital.toFirestore());
    // Also update the patient's vitals snapshot
    final vitalsMap = <String, dynamic>{};
    if (vital.heartRate != null) vitalsMap['hr'] = vital.heartRate;
    if (vital.spo2 != null) vitalsMap['spo2'] = vital.spo2;
    if (vital.weight != null) vitalsMap['weight'] = vital.weight;
    if (vital.systolic != null && vital.diastolic != null) {
      vitalsMap['bp'] = '/';
    }
    if (vitalsMap.isNotEmpty) {
      await _db.collection('patients').doc(patientId).update({
        'vitals': vitalsMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
