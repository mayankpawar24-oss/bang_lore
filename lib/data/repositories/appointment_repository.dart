import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

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
}

class FirebaseAppointmentRepository implements AppointmentRepository {
  final FirebaseFirestore _db;
  FirebaseAppointmentRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _patientAppts(String patientId) =>
      _db.collection('patients').doc(patientId).collection('appointments');

  CollectionReference _doctorAppts(String doctorId) =>
      _db.collection('doctors').doc(doctorId).collection('appointments');

  @override
  Stream<List<Appointment>> appointmentsStream(String patientId) {
    return _patientAppts(patientId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Appointment.fromFirestore(d)).toList());
  }

  @override
  Stream<List<Appointment>> doctorAppointmentsStream(String doctorId) {
    return _doctorAppts(doctorId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Appointment.fromFirestore(d)).toList());
  }

  @override
  Future<List<Appointment>> getAppointments(String userId) async {
    final snap = await _patientAppts(userId)
        .orderBy('dateTime', descending: false)
        .get();
    return snap.docs.map((d) => Appointment.fromFirestore(d)).toList();
  }

  @override
  Future<void> bookAppointment(Appointment appointment) async {
    dev.log('[APPOINTMENT] [FIRESTORE] Booking appointment ${appointment.id} for patient ${appointment.patientId} with doctor ${appointment.doctorId}', name: 'FirebaseAppointmentRepository');
    final apptId = appointment.id.isNotEmpty && !appointment.id.startsWith('app_')
        ? appointment.id
        : _patientAppts(appointment.patientId).doc().id;
    final withId = appointment.copyWith(id: apptId);
    final data = {
      ...withId.toFirestoreCreate(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    // 0. Canonical top-level copy
    final cRef = _db.collection('appointments').doc(apptId);
    batch.set(cRef, data, SetOptions(merge: true));

    // 1. Patient copy
    final pRef = _patientAppts(withId.patientId).doc(apptId);
    batch.set(pRef, data, SetOptions(merge: true));

    // 2. Doctor copy
    final dRef = _doctorAppts(withId.doctorId).doc(apptId);
    batch.set(dRef, data, SetOptions(merge: true));

    // 3. Notification to Patient
    final pNotifRef = _db.collection('patients').doc(withId.patientId).collection('notifications').doc();
    batch.set(pNotifRef, {
      'title': 'Appointment Request Sent',
      'message': 'Your appointment request with ${withId.doctorName.isNotEmpty ? withId.doctorName : "Doctor"} has been submitted.',
      'type': 'appointment_request',
      'appointmentId': apptId,
      'patientId': withId.patientId,
      'doctorId': withId.doctorId,
      'doctorName': withId.doctorName,
      'dateTime': Timestamp.fromDate(withId.dateTime),
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Notification to Doctor
    final dNotifRef = _db.collection('doctors').doc(withId.doctorId).collection('notifications').doc();
    batch.set(dNotifRef, {
      'title': 'New Appointment Request',
      'message': '${withId.patientName.isNotEmpty ? withId.patientName : "A patient"} requested an appointment.',
      'type': 'appointment_request',
      'appointmentId': apptId,
      'patientId': withId.patientId,
      'patientName': withId.patientName,
      'doctorId': withId.doctorId,
      'dateTime': Timestamp.fromDate(withId.dateTime),
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    dev.log('[APPOINTMENT] [NOTIFICATION] Two-way appointment $apptId created in Firestore', name: 'FirebaseAppointmentRepository');
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
    dev.log('[APPOINTMENT] Updating status of $appointmentId to ${newStatus.name}', name: 'FirebaseAppointmentRepository');
    final batch = _db.batch();
    final updateData = <String, dynamic>{
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (notes != null) updateData['notes'] = notes;

    final cRef = _db.collection('appointments').doc(appointmentId);
    batch.set(cRef, updateData, SetOptions(merge: true));

    final pRef = _patientAppts(patientId).doc(appointmentId);
    batch.set(pRef, updateData, SetOptions(merge: true));

    final dRef = _doctorAppts(doctorId).doc(appointmentId);
    batch.set(dRef, updateData, SetOptions(merge: true));

    if (updatedByDoctor) {
      final pNotifRef = _db.collection('patients').doc(patientId).collection('notifications').doc();
      final isConfirmed = newStatus == AppointmentStatus.confirmed ||
          newStatus == AppointmentStatus.approved ||
          newStatus == AppointmentStatus.scheduled;
      final isRejected = newStatus == AppointmentStatus.rejected;
      final type = isConfirmed
          ? 'appointment_confirmed'
          : isRejected
              ? 'appointment_rejected'
              : 'appointment_cancelled';
      final title = isConfirmed
          ? 'Appointment Confirmed'
          : isRejected
              ? 'Appointment Declined'
              : 'Appointment Cancelled';
      final msg = isConfirmed
          ? 'Dr. ${doctorName ?? "Doctor"} confirmed your appointment.'
          : isRejected
              ? 'Dr. ${doctorName ?? "Doctor"} declined your appointment request.'
              : 'Your appointment status was updated to ${newStatus.name}.';
      batch.set(pNotifRef, {
        'title': title,
        'message': msg,
        'type': type,
        'appointmentId': appointmentId,
        'doctorId': doctorId,
        'doctorName': doctorName ?? '',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final dNotifRef = _db.collection('doctors').doc(doctorId).collection('notifications').doc();
      batch.set(dNotifRef, {
        'title': 'Appointment Cancelled',
        'message': 'Patient ${patientName ?? "Patient"} cancelled their appointment.',
        'type': 'appointment_cancelled',
        'appointmentId': appointmentId,
        'patientId': patientId,
        'patientName': patientName ?? '',
        'doctorId': doctorId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    dev.log('[APPOINTMENT] [NOTIFICATION] Two-way status update for $appointmentId complete', name: 'FirebaseAppointmentRepository');
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
