import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appointment_model.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';
import '../services/awesome_notification_service.dart';

abstract class AppointmentRepository {
  Future<List<Appointment>> getAppointments(String userId);
  Future<void> bookAppointment(Appointment appointment);
  Future<void> updateAppointment(String appointmentId, AppointmentStatus status, {String? notes});
  Future<void> updateStatus(
    String patientId,
    String doctorId,
    String appointmentId,
    AppointmentStatus newStatus, {
    String? notes,
    required bool updatedByDoctor,
    String? doctorName,
    String? patientName,
  });
  Future<void> cancelAppointment(String patientId, String appointmentId);
  Stream<List<Appointment>> appointmentsStream(String patientId);
  Stream<List<Appointment>> doctorAppointmentsStream(String doctorId);
  Stream<List<Map<String, dynamic>>> doctorAvailabilityStream(String doctorId);
}

class FirebaseAppointmentRepository implements AppointmentRepository {
  final FirebaseFirestore _db;
  final ActivityLogService _activityLogService;

  FirebaseAppointmentRepository({FirebaseFirestore? db, ActivityLogService? activityLogService})
      : _db = db ?? FirebaseFirestore.instance,
        _activityLogService = activityLogService ?? ActivityLogService(db: db);

  CollectionReference _patientAppts(String patientId) =>
      _db.collection('patients').doc(patientId).collection('appointments');

  CollectionReference _doctorAppts(String doctorId) =>
      _db.collection('doctors').doc(doctorId).collection('appointments');

  @override
  Stream<List<Appointment>> appointmentsStream(String patientId) {
    dev.log('[APPOINTMENT] path being read/written: appointments (query where patientId == $patientId)', name: 'FirebaseAppointmentRepository');
    return _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Appointment.fromFirestore(d)).toList();
          list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          return list;
        });
  }

  @override
  Stream<List<Appointment>> doctorAppointmentsStream(String doctorId) {
    dev.log('[APPOINTMENT] path being read/written: appointments (query where doctorId == $doctorId)', name: 'FirebaseAppointmentRepository');
    return _db
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Appointment.fromFirestore(d)).toList();
          list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          return list;
        });
  }

  @override
  Stream<List<Map<String, dynamic>>> doctorAvailabilityStream(String doctorId) {
    dev.log('[APPOINTMENT] path being read/written: doctors/$doctorId/availability', name: 'FirebaseAppointmentRepository');
    return _db
        .collection('doctors')
        .doc(doctorId)
        .collection('availability')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  @override
  Future<List<Appointment>> getAppointments(String userId) async {
    final snap = await _patientAppts(userId)
        .orderBy('dateTime', descending: false)
        .get();
    return snap.docs.map((d) => Appointment.fromFirestore(d)).toList();
  }

  @override
  @override
  Future<void> bookAppointment(Appointment appointment) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final patientId = (currentUid != null && currentUid.isNotEmpty)
        ? currentUid
        : appointment.patientId;
    final doctorId = appointment.doctorId;

    final apptId = appointment.id.isNotEmpty && !appointment.id.startsWith('app_')
        ? appointment.id
        : _db.collection('appointments').doc().id;

    dev.log('[APPOINTMENT] path being read/written: appointments/$apptId', name: 'FirebaseAppointmentRepository');
    dev.log('[APPOINTMENT] path being read/written: patients/$patientId/appointments/$apptId', name: 'FirebaseAppointmentRepository');
    dev.log('[APPOINTMENT] Firebase UID: $currentUid', name: 'FirebaseAppointmentRepository');
    dev.log('[APPOINTMENT] doctorId: $doctorId', name: 'FirebaseAppointmentRepository');
    dev.log('[APPOINTMENT] appointmentId: $apptId', name: 'FirebaseAppointmentRepository');

    // Slot key for doctor availability e.g. "2026-09-03_09-00"
    final slotKey = '${appointment.dateTime.year}-${appointment.dateTime.month.toString().padLeft(2, '0')}-${appointment.dateTime.day.toString().padLeft(2, '0')}_${appointment.dateTime.hour.toString().padLeft(2, '0')}-${appointment.dateTime.minute.toString().padLeft(2, '0')}';
    final slotPath = 'doctors/$doctorId/availability/$slotKey';
    dev.log('[APPOINTMENT] path being read/written: $slotPath', name: 'FirebaseAppointmentRepository');

    // 1. Availability check using doctors/{doctorId}/availability/{slotKey}
    // Deployed rule: match /availability/{slotId} { allow read: if isSignedIn(); }
    try {
      final slotDoc = await _db.collection('doctors').doc(doctorId).collection('availability').doc(slotKey).get();
      if (slotDoc.exists) {
        final slotData = slotDoc.data();
        final status = slotData?['status'] as String? ?? '';
        if (status == 'approved' || status == 'confirmed' || status == 'scheduled') {
          dev.log('[APPOINTMENT] Slot is already occupied: ${appointment.dateTime}', name: 'FirebaseAppointmentRepository');
          throw Exception('This consultation slot has already been booked by another patient.');
        }
      }
    } catch (e) {
      if (e.toString().contains('already been booked')) {
        dev.log('[APPOINTMENT] exception: $e', name: 'FirebaseAppointmentRepository');
        rethrow;
      }
      dev.log('[APPOINTMENT] Note during availability check: $e', name: 'FirebaseAppointmentRepository');
    }

    final withId = appointment.copyWith(
      id: apptId,
      patientId: patientId,
      status: AppointmentStatus.pending,
      requestedAt: DateTime.now(),
    );

    final data = {
      ...withId.toFirestoreCreate(),
      'id': apptId,
      'appointmentId': apptId,
      'patientId': patientId,
      'doctorId': doctorId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'requestedAt': FieldValue.serverTimestamp(),
    };

    try {
      final batch = _db.batch();

      // Write 1: Canonical top-level copy
      // Deployed rule: allow create: if isSignedIn() && (request.auth.uid == request.resource.data.patientId || ...)
      final cRef = _db.collection('appointments').doc(apptId);
      batch.set(cRef, data, SetOptions(merge: true));

      // Write 2: Patient subcollection copy
      // Deployed rule: match /patients/{patientId}/appointments/{appId} { allow read, write: if isSignedIn() && request.auth.uid == patientId; }
      final pRef = _patientAppts(patientId).doc(apptId);
      batch.set(pRef, data, SetOptions(merge: true));

      // Write 3: Doctor availability slot reservation
      // Deployed rule: match /availability/{slotId} { allow write: if isSignedIn() && (... request.resource.data.bookedByPatientId == request.auth.uid); }
      final slotRef = _db.collection('doctors').doc(doctorId).collection('availability').doc(slotKey);
      batch.set(slotRef, {
        'slotId': slotKey,
        'dateTime': Timestamp.fromDate(withId.dateTime),
        'status': 'pending',
        'bookedByPatientId': patientId,
        'patientName': withId.patientName,
        'appointmentId': apptId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Write 4: Doctor notification (under doctor's UID and synced to root notifications)
      final dNotifRef = _db.collection('doctors').doc(doctorId).collection('notifications').doc();
      final rootNotifRef = _db.collection('notifications').doc(dNotifRef.id);
      final patientDisplayName = withId.patientName.isNotEmpty ? withId.patientName : "a patient";
      final timeStr = '${withId.dateTime.day}/${withId.dateTime.month} at ${withId.dateTime.hour}:${withId.dateTime.minute.toString().padLeft(2, '0')}';
      final dNotifData = {
        'id': dNotifRef.id,
        'notificationId': dNotifRef.id,
        'recipientUid': doctorId,
        'recipientRole': 'doctor',
        'senderUid': patientId,
        'title': 'New Appointment Request',
        'message': 'New appointment request from $patientDisplayName for $timeStr',
        'type': 'appointment_request',
        'appointmentId': apptId,
        'relatedId': apptId,
        'patientId': patientId,
        'patientName': withId.patientName,
        'doctorId': doctorId,
        'doctorName': withId.doctorName,
        'dateTime': Timestamp.fromDate(withId.dateTime),
        'notes': withId.notes ?? '',
        'status': 'pending',
        'isRead': false,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      batch.set(dNotifRef, dNotifData);
      batch.set(rootNotifRef, dNotifData);

      await batch.commit();
      dev.log('[APPOINTMENT] Core appointment $apptId created in Firestore with status "pending"', name: 'FirebaseAppointmentRepository');

      try {
        await _activityLogService.logEvent(
          patientId: patientId,
          doctorId: doctorId,
          appointmentId: apptId,
          eventType: ActivityEventType.appointmentRequested,
          title: 'Appointment Requested',
          description: 'Requested consultation with Dr. ${withId.doctorName} for $timeStr.',
          actorUid: patientId,
          actorRole: 'patient',
          actorName: withId.patientName,
        );
      } catch (_) {}

      try {
        await AwesomeNotificationService.showLocalNotification(
          id: apptId.hashCode,
          title: 'Appointment Request Submitted',
          body: 'Appointment request with ${withId.doctorName.isNotEmpty ? "Dr. ${withId.doctorName}" : "Doctor"} scheduled.',
        );
      } catch (e) {
        dev.log('[AWESOME NOTIFICATION] Booking notification note: $e', name: 'FirebaseAppointmentRepository');
      }
    } catch (e) {
      dev.log('[APPOINTMENT] exception: $e', name: 'FirebaseAppointmentRepository');
      rethrow;
    }

    // Defensive secondary write: doctors/{doctorId}/appointments
    try {
      await _doctorAppts(doctorId).doc(apptId).set(data, SetOptions(merge: true));
    } catch (e) {
      dev.log('[APPOINTMENT] Doctor subcollection write skipped (handled via canonical appointments query): $e', name: 'FirebaseAppointmentRepository');
    }
  }

  @override
  Future<void> updateStatus(
    String patientId,
    String doctorId,
    String appointmentId,
    AppointmentStatus newStatus, {
    String? notes,
    required bool updatedByDoctor,
    String? doctorName,
    String? patientName,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    dev.log('[APPOINTMENT] path being read/written: appointments/$appointmentId (update to ${newStatus.name})', name: 'FirebaseAppointmentRepository');
    dev.log('[APPOINTMENT] path being read/written: patients/$patientId/appointments/$appointmentId', name: 'FirebaseAppointmentRepository');
    dev.log('[APPOINTMENT] path being read/written: doctors/$doctorId/appointments/$appointmentId', name: 'FirebaseAppointmentRepository');
    dev.log('[APPOINTMENT] Firebase UID: $currentUid', name: 'FirebaseAppointmentRepository');
    dev.log('[APPOINTMENT] doctorId: $doctorId', name: 'FirebaseAppointmentRepository');
    dev.log('[APPOINTMENT] appointmentId: $appointmentId', name: 'FirebaseAppointmentRepository');

    // Enforce strict appointment state transitions
    try {
      final currentDoc = await _db.collection('appointments').doc(appointmentId).get();
      if (currentDoc.exists) {
        final currentStatusStr = (currentDoc.data()?['status'] as String? ?? 'pending').toLowerCase();
        if ((currentStatusStr == 'rejected' || currentStatusStr == 'cancelled') &&
            (newStatus == AppointmentStatus.approved || newStatus == AppointmentStatus.pending)) {
          throw Exception('Cannot approve or revert a $currentStatusStr appointment.');
        }
        if (currentStatusStr == 'approved' && newStatus == AppointmentStatus.pending) {
          throw Exception('Cannot revert an approved appointment to pending.');
        }
        if (currentStatusStr == 'completed' && (newStatus == AppointmentStatus.missed || newStatus == AppointmentStatus.pending)) {
          throw Exception('Cannot mark a completed appointment as ${newStatus.name}.');
        }
      }
    } catch (e) {
      if (e.toString().contains('Cannot')) rethrow;
      dev.log('[APPOINTMENT] State transition pre-check note: $e', name: 'FirebaseAppointmentRepository');
    }

    final updateData = <String, dynamic>{
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newStatus == AppointmentStatus.approved || newStatus == AppointmentStatus.confirmed) {
      updateData['approvedAt'] = FieldValue.serverTimestamp();
    } else if (newStatus == AppointmentStatus.rejected) {
      updateData['rejectedAt'] = FieldValue.serverTimestamp();
    }
    if (notes != null) updateData['notes'] = notes;

    try {
      final batch = _db.batch();

      // 1. Canonical top-level copy
      final cRef = _db.collection('appointments').doc(appointmentId);
      batch.set(cRef, updateData, SetOptions(merge: true));

      // 2. Patient copy
      final pRef = _patientAppts(patientId).doc(appointmentId);
      batch.set(pRef, updateData, SetOptions(merge: true));

      // 3. Doctor copy (if doctor is updating, doctor is auth.uid)
      if (updatedByDoctor && (currentUid == doctorId || currentUid != null)) {
        final dRef = _doctorAppts(doctorId).doc(appointmentId);
        batch.set(dRef, updateData, SetOptions(merge: true));
      }

      await batch.commit();
      dev.log('[APPOINTMENT] Status for $appointmentId updated to ${newStatus.name}', name: 'FirebaseAppointmentRepository');
    } catch (e) {
      dev.log('[APPOINTMENT] exception: $e', name: 'FirebaseAppointmentRepository');
      rethrow;
    }

    // Update availability slot if exists
    try {
      final apptSnap = await _db.collection('appointments').doc(appointmentId).get();
      final dt = (apptSnap.data()?['dateTime'] as Timestamp?)?.toDate();
      if (dt != null) {
        final slotKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}-${dt.minute.toString().padLeft(2, '0')}';
        final slotRef = _db.collection('doctors').doc(doctorId).collection('availability').doc(slotKey);
        if (newStatus == AppointmentStatus.approved || newStatus == AppointmentStatus.confirmed) {
          await slotRef.set({'status': 'approved', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        } else if (newStatus == AppointmentStatus.rejected || newStatus == AppointmentStatus.cancelled) {
          await slotRef.delete();
        }
      }
    } catch (e) {
      dev.log('[APPOINTMENT] Availability slot update note: $e', name: 'FirebaseAppointmentRepository');
    }

    // Bidirectional notification write (user-specific + root collection sync)
    try {
      if (updatedByDoctor) {
        final pNotifRef = _db.collection('patients').doc(patientId).collection('notifications').doc();
        final rootNotifRef = _db.collection('notifications').doc(pNotifRef.id);
        final isApproved = newStatus == AppointmentStatus.approved ||
            newStatus == AppointmentStatus.confirmed ||
            newStatus == AppointmentStatus.scheduled;
        final isRejected = newStatus == AppointmentStatus.rejected;
        final isCompleted = newStatus == AppointmentStatus.completed;
        final isMissed = newStatus == AppointmentStatus.missed;
        final docDisplayName = doctorName ?? "Doctor";

        final type = isApproved
            ? 'appointment_approved'
            : isRejected
                ? 'appointment_rejected'
                : isCompleted
                    ? 'appointment_completed'
                    : isMissed
                        ? 'appointment_missed'
                        : 'appointment_cancelled';
        final title = isApproved
            ? 'Appointment Approved'
            : isRejected
                ? 'Appointment Rejected'
                : isCompleted
                    ? 'Appointment Completed'
                    : isMissed
                        ? 'Appointment Missed'
                        : 'Appointment Cancelled';
        final msg = isApproved
            ? 'Your appointment with Dr. $docDisplayName has been approved.'
            : isRejected
                ? 'Your appointment request with Dr. $docDisplayName was rejected.'
                : isCompleted
                    ? 'Your consultation with Dr. $docDisplayName has concluded.'
                    : isMissed
                        ? 'Your scheduled appointment with Dr. $docDisplayName was missed. Please reschedule.'
                        : 'Your appointment with Dr. $docDisplayName was cancelled.';

        final notifPayload = {
          'id': pNotifRef.id,
          'notificationId': pNotifRef.id,
          'recipientUid': patientId,
          'recipientRole': 'patient',
          'senderUid': doctorId,
          'title': title,
          'message': msg,
          'type': type,
          'appointmentId': appointmentId,
          'relatedId': appointmentId,
          'doctorId': doctorId,
          'doctorName': docDisplayName,
          'patientId': patientId,
          'patientName': patientName ?? '',
          'status': newStatus.name,
          'isRead': false,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        await pNotifRef.set(notifPayload);
        await rootNotifRef.set(notifPayload);

        try {
          await AwesomeNotificationService.showLocalNotification(
            id: appointmentId.hashCode,
            title: title,
            body: msg,
          );
        } catch (e) {
          dev.log('[AWESOME NOTIFICATION] Status update notification error: $e', name: 'FirebaseAppointmentRepository');
        }

        // Also update the doctor's pending notification to actioned/rejected
        try {
          final docNotifs = await _db
              .collection('doctors')
              .doc(doctorId)
              .collection('notifications')
              .where('appointmentId', isEqualTo: appointmentId)
              .get();
          for (final d in docNotifs.docs) {
            await d.reference.update({
              'status': isApproved ? 'actioned' : (isRejected ? 'rejected' : 'cancelled'),
              'isRead': true,
              'read': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          dev.log('[APPOINTMENT] Doctor notification status update note: $e', name: 'FirebaseAppointmentRepository');
        }
      } else {
        // Patient initiated status update/cancellation -> Notify doctor
        final dNotifRef = _db.collection('doctors').doc(doctorId).collection('notifications').doc();
        final rootNotifRef = _db.collection('notifications').doc(dNotifRef.id);
        final pName = (patientName != null && patientName.isNotEmpty) ? patientName : "Patient";
        final title = newStatus == AppointmentStatus.cancelled
            ? 'Appointment Cancelled'
            : 'Appointment Update';
        final msg = newStatus == AppointmentStatus.cancelled
            ? '$pName cancelled their appointment.'
            : '$pName updated the appointment status to ${newStatus.name}.';

        final dNotifPayload = {
          'id': dNotifRef.id,
          'notificationId': dNotifRef.id,
          'recipientUid': doctorId,
          'recipientRole': 'doctor',
          'senderUid': patientId,
          'title': title,
          'message': msg,
          'type': 'appointment_cancelled',
          'appointmentId': appointmentId,
          'relatedId': appointmentId,
          'doctorId': doctorId,
          'doctorName': doctorName ?? '',
          'patientId': patientId,
          'patientName': pName,
          'status': 'cancelled',
          'isRead': false,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        await dNotifRef.set(dNotifPayload);
        await rootNotifRef.set(dNotifPayload);

        try {
          await AwesomeNotificationService.showLocalNotification(
            id: appointmentId.hashCode,
            title: title,
            body: msg,
          );
        } catch (e) {
          dev.log('[AWESOME NOTIFICATION] Doctor notification error: $e', name: 'FirebaseAppointmentRepository');
        }
      }

      try {
        final isApproved = newStatus == AppointmentStatus.approved || newStatus == AppointmentStatus.confirmed;
        final isRejected = newStatus == AppointmentStatus.rejected;
        final isCancelled = newStatus == AppointmentStatus.cancelled;
        final isCompleted = newStatus == AppointmentStatus.completed;
        final isMissed = newStatus == AppointmentStatus.missed;

        final logEventType = isApproved
            ? ActivityEventType.appointmentApproved
            : isRejected
                ? ActivityEventType.appointmentRejected
                : isCancelled
                    ? ActivityEventType.appointmentCancelled
                    : isCompleted
                        ? ActivityEventType.appointmentCompleted
                        : isMissed
                            ? ActivityEventType.appointmentMissed
                            : ActivityEventType.general;

        final logTitle = isApproved
            ? 'Appointment Approved'
            : isRejected
                ? 'Appointment Rejected'
                : isCancelled
                    ? 'Appointment Cancelled'
                    : isCompleted
                        ? 'Appointment Completed'
                        : isMissed
                            ? 'Appointment Missed'
                            : 'Appointment Updated';

        final actorUid = updatedByDoctor ? doctorId : patientId;
        final actorRole = updatedByDoctor ? 'doctor' : 'patient';
        final actorName = updatedByDoctor ? (doctorName ?? 'Doctor') : (patientName ?? 'Patient');

        await _activityLogService.logEvent(
          patientId: patientId,
          doctorId: doctorId,
          appointmentId: appointmentId,
          eventType: logEventType,
          title: logTitle,
          description: 'Consultation status updated to ${newStatus.name}.',
          actorUid: actorUid,
          actorRole: actorRole,
          actorName: actorName,
        );
      } catch (e) {
        dev.log('[APPOINTMENT] Activity log note: $e', name: 'FirebaseAppointmentRepository');
      }
    } catch (e) {
      dev.log('[APPOINTMENT] Notification write error: $e', name: 'FirebaseAppointmentRepository');
    }
  }

  @override
  Future<void> updateAppointment(String appointmentId, AppointmentStatus status, {String? notes}) async {
    throw UnimplementedError('Use updateStatus with patientId and doctorId');
  }

  @override
  Future<void> cancelAppointment(String patientId, String appointmentId) async {
    final docSnap = await _patientAppts(patientId).doc(appointmentId).get();
    final docData = docSnap.data() as Map<String, dynamic>?;
    final doctorId = docData?['doctorId'] as String? ?? '';

    await updateStatus(
      patientId,
      doctorId,
      appointmentId,
      AppointmentStatus.cancelled,
      updatedByDoctor: false,
    );
  }
}

// Mock for fallback
class MockAppointmentRepository implements AppointmentRepository {
  final List<Appointment> _appointments = [];

  @override
  Stream<List<Appointment>> appointmentsStream(String patientId) => Stream.value([]);

  @override
  Stream<List<Appointment>> doctorAppointmentsStream(String doctorId) => Stream.value([]);

  @override
  Stream<List<Map<String, dynamic>>> doctorAvailabilityStream(String doctorId) => Stream.value([]);

  @override
  Future<List<Appointment>> getAppointments(String userId) async => List.from(_appointments);

  @override
  Future<void> bookAppointment(Appointment appointment) async {
    _appointments.add(appointment);
  }

  @override
  Future<void> updateStatus(
    String patientId,
    String doctorId,
    String appointmentId,
    AppointmentStatus newStatus, {
    String? notes,
    required bool updatedByDoctor,
    String? doctorName,
    String? patientName,
  }) async {
    final idx = _appointments.indexWhere((a) => a.id == appointmentId);
    if (idx >= 0) _appointments[idx] = _appointments[idx].copyWith(status: newStatus, notes: notes);
  }

  @override
  Future<void> updateAppointment(String id, AppointmentStatus status, {String? notes}) async {
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx >= 0) _appointments[idx] = _appointments[idx].copyWith(status: status, notes: notes);
  }

  @override
  Future<void> cancelAppointment(String patientId, String appointmentId) async {
    final idx = _appointments.indexWhere((a) => a.id == appointmentId);
    if (idx >= 0) {
      _appointments[idx] = _appointments[idx].copyWith(status: AppointmentStatus.cancelled);
    }
  }
}
