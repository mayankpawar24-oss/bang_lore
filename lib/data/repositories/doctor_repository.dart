import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_model.dart';

abstract class DoctorRepository {
  Future<List<Doctor>> getDoctors();
  Future<List<Doctor>> searchDoctors(String query);
  Future<Doctor> getDoctorById(String id);
  Future<List<Doctor>> getNearbyDoctors();
  Future<List<String>> getSpecialties();
  Stream<Doctor?> doctorStream(String doctorId);
  Stream<List<Doctor>> doctorsStream();
  Stream<List<Map<String, dynamic>>> availabilityStream(String doctorId);
  Future<void> setAvailabilitySlot(String doctorId, Map<String, dynamic> slotData);
  Future<void> deleteAvailabilitySlot(String doctorId, String slotId);
}

class FirebaseDoctorRepository implements DoctorRepository {
  final FirebaseFirestore _db;

  FirebaseDoctorRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _doctors => _db.collection('doctors');

  @override
  Stream<Doctor?> doctorStream(String doctorId) {
    return _doctors.doc(doctorId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Doctor.fromFirestore(doc);
    });
  }

  @override
  Stream<List<Doctor>> doctorsStream() {
    return _doctors.snapshots().map((snap) => snap.docs.map((d) => Doctor.fromFirestore(d)).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> availabilityStream(String doctorId) {
    return _doctors
        .doc(doctorId)
        .collection('availability')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  @override
  Future<void> setAvailabilitySlot(String doctorId, Map<String, dynamic> slotData) async {
    final slotId = slotData['id'] as String? ?? _doctors.doc(doctorId).collection('availability').doc().id;
    await _doctors.doc(doctorId).collection('availability').doc(slotId).set({
      ...slotData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteAvailabilitySlot(String doctorId, String slotId) async {
    await _doctors.doc(doctorId).collection('availability').doc(slotId).delete();
  }

  @override
  Future<List<Doctor>> getDoctors() async {
    final snap = await _doctors.limit(50).get();
    return snap.docs.map((d) => Doctor.fromFirestore(d)).toList();
  }

  @override
  Future<List<Doctor>> searchDoctors(String query) async {
    final all = await getDoctors();
    final q = query.toLowerCase();
    return all
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            d.specialty.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<Doctor> getDoctorById(String id) async {
    final doc = await _doctors.doc(id).get();
    if (!doc.exists) throw Exception('Doctor not found: ');
    return Doctor.fromFirestore(doc);
  }

  @override
  Future<List<Doctor>> getNearbyDoctors() async {
    final all = await getDoctors();
    return all..sort((a, b) => a.distance.compareTo(b.distance));
  }

  @override
  Future<List<String>> getSpecialties() async {
    final all = await getDoctors();
    return all.map((d) => d.specialty).toSet().toList();
  }
}

// Keep mock for dev/fallback
class MockDoctorRepository implements DoctorRepository {
  final List<Doctor> _doctors = [
    const Doctor(
      id: 'd_aisha_01',
      name: 'Dr. Aisha Patel',
      specialty: 'Cardiology',
      hospital: 'City Heart Center',
      rating: 4.9,
      distance: 1.2,
      avatarUrl: 'https://i.pravatar.cc/150?u=aisha',
      phone: '+1234567890',
      about: 'Experienced Cardiologist with 15 years of practice.',
      availableDays: ['Monday', 'Wednesday', 'Friday'],
      isAvailable: true,
    ),
    const Doctor(
      id: 'd_james_02',
      name: 'Dr. James Wilson',
      specialty: 'Neurology',
      hospital: 'Metro General Hospital',
      rating: 4.8,
      distance: 3.5,
      avatarUrl: 'https://i.pravatar.cc/150?u=james',
      phone: '+1234567891',
      about: 'Specializes in neurodegenerative diseases.',
      availableDays: ['Tuesday', 'Thursday'],
      isAvailable: true,
    ),
    const Doctor(
      id: 'd_sarah_03',
      name: 'Dr. Sarah Kim',
      specialty: 'Endocrinology',
      hospital: 'Wellness Clinic',
      rating: 4.7,
      distance: 2.1,
      avatarUrl: 'https://i.pravatar.cc/150?u=sarahkim',
      phone: '+1234567892',
      about: 'Expert in diabetes management and thyroid disorders.',
      availableDays: ['Monday', 'Tuesday', 'Wednesday'],
      isAvailable: true,
    ),
  ];

  @override
  Future<List<Doctor>> getDoctors() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_doctors);
  }

  @override
  Future<List<Doctor>> searchDoctors(String query) async {
    final q = query.toLowerCase();
    return _doctors
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            d.specialty.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<Doctor> getDoctorById(String id) async {
    return _doctors.firstWhere((d) => d.id == id);
  }

  @override
  Future<List<Doctor>> getNearbyDoctors() async {
    return _doctors..sort((a, b) => a.distance.compareTo(b.distance));
  }

  @override
  Future<List<String>> getSpecialties() async {
    return ['Cardiology', 'Neurology', 'Endocrinology', 'General Practice'];
  }

  @override
  Stream<Doctor?> doctorStream(String doctorId) {
    return Stream.value(_doctors.firstWhere((d) => d.id == doctorId, orElse: () => _doctors.first));
  }

  @override
  Stream<List<Doctor>> doctorsStream() {
    return Stream.value(_doctors);
  }

  @override
  Stream<List<Map<String, dynamic>>> availabilityStream(String doctorId) => Stream.value([]);

  @override
  Future<void> setAvailabilitySlot(String doctorId, Map<String, dynamic> slotData) async {}

  @override
  Future<void> deleteAvailabilitySlot(String doctorId, String slotId) async {}
}
