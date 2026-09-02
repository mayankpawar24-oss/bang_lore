import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_model.dart';
import '../models/permission_request_model.dart';

abstract class PatientRepository {
  Future<List<Patient>> getPatients();
  Future<Patient> getPatientById(String id);
  Future<List<Patient>> getActivePatients();
  Future<List<Patient>> searchPatients(String query);
  Future<void> updatePatient(Patient patient);
  Future<AccessPermission> requestAccess(String doctorId, String patientId, {List<String> permissions});
  Future<void> approveAccess(String permissionId, {List<String>? permissions});
  Future<void> denyAccess(String permissionId);
  Future<void> revokeAccess(String permissionId);
  Future<List<AccessPermission>> getPendingRequests(String patientId);
  Future<bool> isAuthorized(String doctorId, String patientId);
  Future<AccessPermission?> getPermission(String doctorId, String patientId);
  Stream<Patient?> patientStream(String patientId);
  Stream<List<Patient>> patientsStream();
  Stream<List<AccessPermission>> pendingRequestsStream(String patientId);
}

class FirebasePatientRepository implements PatientRepository {
  final FirebaseFirestore _db;

  FirebasePatientRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _patients => _db.collection('patients');
  CollectionReference get _permissions => _db.collection('accessPermissions');

  @override
  Stream<Patient?> patientStream(String patientId) {
    return _patients.doc(patientId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Patient.fromFirestore(doc);
    });
  }

  @override
  Stream<List<Patient>> patientsStream() {
    return _patients.snapshots().map((snap) => snap.docs.map((d) => Patient.fromFirestore(d)).toList());
  }

  @override
  Stream<List<AccessPermission>> pendingRequestsStream(String patientId) {
    return _permissions
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AccessPermission.fromFirestore(d))
            .toList());
  }

  @override
  Future<List<Patient>> getPatients() async {
    final snap = await _patients.limit(50).get();
    return snap.docs.map((d) => Patient.fromFirestore(d)).toList();
  }

  @override
  Future<Patient> getPatientById(String id) async {
    final doc = await _patients.doc(id).get();
    if (!doc.exists) throw Exception('Patient not found: ');
    return Patient.fromFirestore(doc);
  }

  @override
  Future<List<Patient>> getActivePatients() async {
    final snap = await _patients
        .where('status', whereIn: ['attention', 'critical'])
        .get();
    return snap.docs.map((d) => Patient.fromFirestore(d)).toList();
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    final all = await getPatients();
    final q = query.toLowerCase();
    return all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.condition.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<void> updatePatient(Patient patient) async {
    await _patients.doc(patient.id).set(
          patient.toFirestore(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<AccessPermission> requestAccess(
    String doctorId,
    String patientId, {
    List<String> permissions = const ['profile'],
  }) async {
    final docId = AccessPermission.docId(doctorId, patientId);
    // Check if patient exists
    final patientDoc = await _patients.doc(patientId).get();
    final patientName = patientDoc.exists
        ? (patientDoc.data() as Map<String, dynamic>)['name'] as String? ?? ''
        : patientId;
    // Get doctor name from doctors collection
    final doctorDoc = await _db.collection('doctors').doc(doctorId).get();
    final doctorName = doctorDoc.exists
        ? (doctorDoc.data() as Map<String, dynamic>)['name'] as String? ?? ''
        : doctorId;

    final perm = AccessPermission(
      id: docId,
      doctorId: doctorId,
      doctorName: doctorName,
      patientId: patientId,
      patientName: patientName,
      status: PermissionStatus.pending,
      requestedAt: DateTime.now(),
      permissions: permissions,
    );
    await _permissions.doc(docId).set(perm.toFirestore());
    // Notify patient
    await _db
        .collection('patients')
        .doc(patientId)
        .collection('notifications')
        .add({
      'title': 'Access Request',
      'message': '${doctorName.isNotEmpty ? "Dr. $doctorName" : "A doctor"} requested access to your health records.',
      'type': 'access_request',
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientId': patientId,
      'patientName': patientName,
      'permissionId': docId,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return perm;
  }

  @override
  Future<void> approveAccess(String permissionId,
      {List<String>? permissions}) async {
    final data = {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (permissions != null) data['permissions'] = permissions as dynamic;
    await _permissions.doc(permissionId).update(data);
    // Notify doctor
    final permDoc = await _permissions.doc(permissionId).get();
    if (permDoc.exists) {
      final perm = AccessPermission.fromFirestore(permDoc);
      await _db
          .collection('doctors')
          .doc(perm.doctorId)
          .collection('notifications')
          .add({
        'title': 'Access Approved',
        'message': '${perm.patientName.isNotEmpty ? perm.patientName : "Patient"} approved your access request.',
        'type': 'access_approved',
        'patientId': perm.patientId,
        'patientName': perm.patientName,
        'doctorId': perm.doctorId,
        'permissionId': permissionId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> denyAccess(String permissionId) async {
    await _permissions.doc(permissionId).update({
      'status': 'denied',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final permDoc = await _permissions.doc(permissionId).get();
    if (permDoc.exists) {
      final perm = AccessPermission.fromFirestore(permDoc);
      await _db
          .collection('doctors')
          .doc(perm.doctorId)
          .collection('notifications')
          .add({
        'title': 'Access Declined',
        'message': '${perm.patientName.isNotEmpty ? perm.patientName : "Patient"} declined your access request.',
        'type': 'access_denied',
        'patientId': perm.patientId,
        'patientName': perm.patientName,
        'doctorId': perm.doctorId,
        'permissionId': permissionId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> revokeAccess(String permissionId) async {
    await _permissions.doc(permissionId).update({
      'status': 'revoked',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final permDoc = await _permissions.doc(permissionId).get();
    if (permDoc.exists) {
      final perm = AccessPermission.fromFirestore(permDoc);
      await _db
          .collection('doctors')
          .doc(perm.doctorId)
          .collection('notifications')
          .add({
        'title': 'Access Revoked',
        'message': '${perm.patientName.isNotEmpty ? perm.patientName : "Patient"} revoked access to their health records.',
        'type': 'access_revoked',
        'patientId': perm.patientId,
        'patientName': perm.patientName,
        'doctorId': perm.doctorId,
        'permissionId': permissionId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<List<AccessPermission>> getPendingRequests(String patientId) async {
    final snap = await _permissions
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.map((d) => AccessPermission.fromFirestore(d)).toList();
  }

  @override
  Future<bool> isAuthorized(String doctorId, String patientId) async {
    final perm = await getPermission(doctorId, patientId);
    return perm?.isActive ?? false;
  }

  @override
  Future<AccessPermission?> getPermission(
      String doctorId, String patientId) async {
    final docId = AccessPermission.docId(doctorId, patientId);
    final doc = await _permissions.doc(docId).get();
    if (!doc.exists) return null;
    return AccessPermission.fromFirestore(doc);
  }
}
