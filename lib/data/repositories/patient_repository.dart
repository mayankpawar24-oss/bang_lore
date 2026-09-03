import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_model.dart';
import '../models/permission_request_model.dart';
import '../services/awesome_notification_service.dart';

abstract class PatientRepository {
  Future<List<Patient>> getPatients();
  Future<Patient> getPatientById(String id);
  Future<List<Patient>> getActivePatients();
  Future<List<Patient>> searchPatients(String query);
  Future<void> updatePatient(Patient patient);
  Future<AccessPermission> requestAccess(String doctorId, String patientId, {List<String> permissions});
  Future<void> approveAccess(String permissionId, {List<String>? permissions, String? notificationId});
  Future<void> denyAccess(String permissionId, {String? notificationId});
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
  Future<AccessPermission> requestAccess(String doctorId, String patientId,
      {List<String> permissions = const [
        'profile',
        'vitals',
        'medications',
        'appointments',
        'medicalHistory',
        'familyHistory',
        'reports',
        'aiChat',
      ]}) async {
    final docId = AccessPermission.docId(doctorId, patientId);
    dev.log('[ACCESS] Requesting access doctor: $doctorId, patient: $patientId, docId: $docId', name: 'PatientRepository');

    // Check if patient exists in patients or users
    String patientName = '';
    try {
      final patientDoc = await _patients.doc(patientId).get();
      if (patientDoc.exists && patientDoc.data() != null) {
        patientName = (patientDoc.data() as Map<String, dynamic>)['name'] as String? ?? '';
      }
      if (patientName.isEmpty) {
        final userDoc = await _db.collection('users').doc(patientId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          patientName = data['name'] as String? ?? '';
        }
      }
    } catch (e) {
      dev.log('[ACCESS] [FIRESTORE] Error reading patient name: $e', name: 'PatientRepository');
    }
    if (patientName.isEmpty) patientName = 'Patient';

    // Get doctor name from doctors or users
    String doctorName = '';
    try {
      final doctorDoc = await _db.collection('doctors').doc(doctorId).get();
      if (doctorDoc.exists && doctorDoc.data() != null) {
        final data = doctorDoc.data() as Map<String, dynamic>;
        doctorName = data['name'] as String? ?? '';
      }
      if (doctorName.isEmpty) {
        final userDoc = await _db.collection('users').doc(doctorId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          doctorName = data['name'] as String? ?? '';
        }
      }
    } catch (e) {
      dev.log('[ACCESS] [FIRESTORE] Error reading doctor name: $e', name: 'PatientRepository');
    }
    if (doctorName.isEmpty) doctorName = 'Doctor';

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

    // 1. Store under deterministic user-owned path: patients/{patientId}/accessRequests/{requestId}
    dev.log('[ACCESS] [FIRESTORE] Writing patients/$patientId/accessRequests/$docId', name: 'PatientRepository');
    try {
      await _patients.doc(patientId).collection('accessRequests').doc(docId).set({
        'requestId': docId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'patientId': patientId,
        'patientName': patientName,
        'status': 'pending',
        'permissions': permissions,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      dev.log('[ACCESS] [FIRESTORE] Note on accessRequests write: $e', name: 'PatientRepository');
    }

    // 2. Canonical permission document: accessPermissions/{docId}
    dev.log('[ACCESS] [FIRESTORE] Writing accessPermissions/$docId', name: 'PatientRepository');
    await _permissions.doc(docId).set({
      ...perm.toFirestore(),
      'requestId': docId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Create ONLY the patient's notification: patients/{patientId}/notifications/{notifId}
    dev.log('[NOTIFICATION] Notifying patient at patients/$patientId/notifications', name: 'PatientRepository');
    try {
      final pNotifRef = _db.collection('patients').doc(patientId).collection('notifications').doc();
      await pNotifRef.set({
        'id': pNotifRef.id,
        'notificationId': pNotifRef.id,
        'recipientUid': patientId,
        'senderUid': doctorId,
        'type': 'profile_access_request',
        'title': 'Profile Access Request',
        'message': '${doctorName.isNotEmpty ? "Dr. $doctorName" : "A doctor"} requested access to your health records.',
        'requestId': docId,
        'permissionId': docId,
        'relatedId': docId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'patientId': patientId,
        'patientName': patientName,
        'status': 'pending',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      dev.log('[NOTIFICATION] [FIRESTORE] Exception writing patient notification: $e', name: 'PatientRepository');
      rethrow;
    }

    try {
      await AwesomeNotificationService.showAccessRequestNotification(
        id: docId.hashCode,
        doctorName: doctorName.isNotEmpty ? "Dr. $doctorName" : "A doctor",
        requestId: docId,
      );
    } catch (e) {
      dev.log('[AWESOME NOTIFICATION] Access request trigger error: $e', name: 'PatientRepository');
    }

    return perm;
  }

  @override
  Future<void> approveAccess(String permissionId,
      {List<String>? permissions, String? notificationId}) async {
    dev.log('[ACCESS] [FIRESTORE] Approving permission: accessPermissions/$permissionId', name: 'PatientRepository');

    // Extract doctorId and patientId
    String doctorId = '';
    String patientId = '';
    String patientName = '';
    if (permissionId.contains('_')) {
      final parts = permissionId.split('_');
      doctorId = parts.first;
      patientId = parts.sublist(1).join('_');
    }

    final permDoc = await _permissions.doc(permissionId).get();
    if (permDoc.exists) {
      final data = permDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        doctorId = data['doctorId'] as String? ?? doctorId;
        patientId = data['patientId'] as String? ?? patientId;
        patientName = data['patientName'] as String? ?? '';
      }
    }

    final updateData = <String, dynamic>{
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (permissions != null) updateData['permissions'] = permissions;

    // 1. Update accessPermissions/{permissionId}
    await _permissions.doc(permissionId).set(updateData, SetOptions(merge: true));

    // 2. Update patients/{patientId}/accessRequests/{permissionId}
    if (patientId.isNotEmpty) {
      try {
        await _patients.doc(patientId).collection('accessRequests').doc(permissionId).set(
          updateData,
          SetOptions(merge: true),
        );
      } catch (e) {
        dev.log('[ACCESS] Note on updating accessRequests: $e', name: 'PatientRepository');
      }
    }

    // 3. Create notification ONLY under requesting doctor's UID: doctors/{doctorId}/notifications
    if (doctorId.isNotEmpty) {
      dev.log('[NOTIFICATION] Notifying doctor at doctors/$doctorId/notifications', name: 'PatientRepository');
      try {
        final dNotifRef = _db.collection('doctors').doc(doctorId).collection('notifications').doc();
        final pName = patientName.isNotEmpty ? patientName : "Patient";
        await dNotifRef.set({
          'id': dNotifRef.id,
          'notificationId': dNotifRef.id,
          'recipientUid': doctorId,
          'senderUid': patientId,
          'type': 'profile_access_approved',
          'title': 'Access Approved',
          'message': '$pName approved your health profile access request.',
          'requestId': permissionId,
          'permissionId': permissionId,
          'relatedId': permissionId,
          'patientId': patientId,
          'patientName': pName,
          'doctorId': doctorId,
          'status': 'approved',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        dev.log('[NOTIFICATION] [FIRESTORE] Exception writing doctor notification: $e', name: 'PatientRepository');
      }

      // Explicitly write approved consent records
      if (patientId.isNotEmpty) {
        try {
          await _patients.doc(patientId).collection('consents').doc(doctorId).set({
            'doctorId': doctorId,
            'patientId': patientId,
            'status': 'approved',
            'permissions': permissions ?? ['profile', 'vitals', 'medications', 'appointments', 'reports', 'aiChat'],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await _db.collection('doctors').doc(doctorId).collection('authorizedPatients').doc(patientId).set({
            'patientId': patientId,
            'doctorId': doctorId,
            'patientName': patientName,
            'status': 'approved',
            'permissions': permissions ?? ['profile', 'vitals', 'medications', 'appointments', 'reports', 'aiChat'],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await AwesomeNotificationService.showLocalNotification(
            id: permissionId.hashCode,
            title: 'Access Approved',
            body: '$patientName approved your health profile access request.',
          );
        } catch (e) {
          dev.log('[ACCESS] Consent document write error: $e', name: 'PatientRepository');
        }
      }
    }

    // 4. Update the patient's notification status to 'actioned'
    if (patientId.isNotEmpty) {
      try {
        if (notificationId != null && notificationId.isNotEmpty) {
          await _db.collection('patients').doc(patientId).collection('notifications').doc(notificationId).update({
            'status': 'actioned',
            'isRead': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        final patNotifs = await _db
            .collection('patients')
            .doc(patientId)
            .collection('notifications')
            .where('permissionId', isEqualTo: permissionId)
            .get();
        for (final doc in patNotifs.docs) {
          await doc.reference.update({
            'status': 'actioned',
            'isRead': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        dev.log('[NOTIFICATION] Patient notification status update note: $e', name: 'PatientRepository');
      }
    }
  }

  @override
  Future<void> denyAccess(String permissionId, {String? notificationId}) async {
    dev.log('[ACCESS] [FIRESTORE] Denying permission: accessPermissions/$permissionId', name: 'PatientRepository');

    String doctorId = '';
    String patientId = '';
    String patientName = '';
    if (permissionId.contains('_')) {
      final parts = permissionId.split('_');
      doctorId = parts.first;
      patientId = parts.sublist(1).join('_');
    }

    final permDoc = await _permissions.doc(permissionId).get();
    if (permDoc.exists) {
      final data = permDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        doctorId = data['doctorId'] as String? ?? doctorId;
        patientId = data['patientId'] as String? ?? patientId;
        patientName = data['patientName'] as String? ?? '';
      }
    }

    final updateData = <String, dynamic>{
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 1. Update accessPermissions/{permissionId}
    await _permissions.doc(permissionId).set(updateData, SetOptions(merge: true));

    // 2. Update patients/{patientId}/accessRequests/{permissionId}
    if (patientId.isNotEmpty) {
      try {
        await _patients.doc(patientId).collection('accessRequests').doc(permissionId).set(
          updateData,
          SetOptions(merge: true),
        );
      } catch (e) {
        dev.log('[ACCESS] Note on updating accessRequests: $e', name: 'PatientRepository');
      }
    }

    // 3. Create notification ONLY under requesting doctor's UID: doctors/{doctorId}/notifications
    if (doctorId.isNotEmpty) {
      dev.log('[NOTIFICATION] Notifying doctor of decline at doctors/$doctorId/notifications', name: 'PatientRepository');
      try {
        final dNotifRef = _db.collection('doctors').doc(doctorId).collection('notifications').doc();
        final pName = patientName.isNotEmpty ? patientName : "Patient";
        await dNotifRef.set({
          'id': dNotifRef.id,
          'notificationId': dNotifRef.id,
          'recipientUid': doctorId,
          'senderUid': patientId,
          'type': 'profile_access_declined',
          'title': 'Access Declined',
          'message': '$pName declined your access request.',
          'requestId': permissionId,
          'permissionId': permissionId,
          'relatedId': permissionId,
          'patientId': patientId,
          'patientName': pName,
          'doctorId': doctorId,
          'status': 'rejected',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        dev.log('[NOTIFICATION] [FIRESTORE] Exception writing doctor notification: $e', name: 'PatientRepository');
      }

      // Explicitly write declined consent records
      if (patientId.isNotEmpty) {
        try {
          await _patients.doc(patientId).collection('consents').doc(doctorId).set({
            'doctorId': doctorId,
            'patientId': patientId,
            'status': 'declined',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await _db.collection('doctors').doc(doctorId).collection('authorizedPatients').doc(patientId).set({
            'patientId': patientId,
            'doctorId': doctorId,
            'status': 'declined',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await AwesomeNotificationService.showLocalNotification(
            id: permissionId.hashCode,
            title: 'Access Declined',
            body: '$patientName declined your access request.',
          );
        } catch (e) {
          dev.log('[ACCESS] Consent decline document write error: $e', name: 'PatientRepository');
        }
      }
    }

    // 4. Update the patient's notification status to 'rejected'
    if (patientId.isNotEmpty) {
      try {
        if (notificationId != null && notificationId.isNotEmpty) {
          await _db.collection('patients').doc(patientId).collection('notifications').doc(notificationId).update({
            'status': 'rejected',
            'isRead': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        final patNotifs = await _db
            .collection('patients')
            .doc(patientId)
            .collection('notifications')
            .where('permissionId', isEqualTo: permissionId)
            .get();
        for (final doc in patNotifs.docs) {
          await doc.reference.update({
            'status': 'rejected',
            'isRead': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        dev.log('[NOTIFICATION] Patient notification status update note: $e', name: 'PatientRepository');
      }
    }
  }

  @override
  Future<void> revokeAccess(String permissionId) async {
    String doctorId = '';
    String patientId = '';
    String patientName = '';
    if (permissionId.contains('_')) {
      final parts = permissionId.split('_');
      doctorId = parts.first;
      patientId = parts.sublist(1).join('_');
    }

    final permDoc = await _permissions.doc(permissionId).get();
    if (permDoc.exists) {
      final data = permDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        doctorId = data['doctorId'] as String? ?? doctorId;
        patientId = data['patientId'] as String? ?? patientId;
        patientName = data['patientName'] as String? ?? '';
      }
    }

    final updateData = <String, dynamic>{
      'status': 'revoked',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _permissions.doc(permissionId).set(updateData, SetOptions(merge: true));

    if (patientId.isNotEmpty) {
      try {
        await _patients.doc(patientId).collection('accessRequests').doc(permissionId).set(
          updateData,
          SetOptions(merge: true),
        );
      } catch (e) {
        dev.log('[ACCESS] Note on updating accessRequests: $e', name: 'PatientRepository');
      }
    }

    if (doctorId.isNotEmpty) {
      final dNotifRef = _db.collection('doctors').doc(doctorId).collection('notifications').doc();
      final pName = patientName.isNotEmpty ? patientName : "Patient";
      await dNotifRef.set({
        'id': dNotifRef.id,
        'notificationId': dNotifRef.id,
        'recipientUid': doctorId,
        'senderUid': patientId,
        'title': 'Access Revoked',
        'message': '$pName revoked access to their health records.',
        'type': 'profile_access_revoked',
        'patientId': patientId,
        'patientName': pName,
        'doctorId': doctorId,
        'permissionId': permissionId,
        'requestId': permissionId,
        'relatedId': permissionId,
        'status': 'revoked',
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
