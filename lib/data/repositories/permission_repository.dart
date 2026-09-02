import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/permission_request_model.dart';

class FirebasePermissionRepository {
  final FirebaseFirestore _db;
  FirebasePermissionRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _permissions => _db.collection('accessPermissions');

  Stream<AccessPermission?> permissionStream(String doctorId, String patientId) {
    final docId = AccessPermission.docId(doctorId, patientId);
    return _permissions.doc(docId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AccessPermission.fromFirestore(doc);
    });
  }

  Stream<List<AccessPermission>> doctorPermissionsStream(String doctorId) {
    return _permissions
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AccessPermission.fromFirestore(d))
            .where((p) => p.isActive)
            .toList());
  }

  Stream<List<AccessPermission>> patientPermissionsStream(String patientId) {
    return _permissions
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AccessPermission.fromFirestore(d)).toList());
  }

  Future<List<AccessPermission>> getApprovedPatientsForDoctor(String doctorId) async {
    final snap = await _permissions
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'approved')
        .get();
    return snap.docs
        .map((d) => AccessPermission.fromFirestore(d))
        .where((p) => p.isActive)
        .toList();
  }

  Future<void> updatePermissions(String permissionId, List<String> permissions) async {
    await _permissions.doc(permissionId).update({
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
