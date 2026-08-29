import '../models/doctor_model.dart';
import '../mock/mock_data.dart';

abstract class DoctorRepository {
  Future<List<Doctor>> getDoctors();
  Future<List<Doctor>> searchDoctors(String query);
  Future<Doctor> getDoctorById(String id);
  Future<List<Doctor>> getNearbyDoctors();
  Future<List<String>> getSpecialties();
}

class MockDoctorRepository implements DoctorRepository {
  @override
  Future<List<Doctor>> getDoctors() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.doctors;
  }

  @override
  Future<List<Doctor>> searchDoctors(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final q = query.toLowerCase();
    return MockData.doctors.where((d) =>
        d.name.toLowerCase().contains(q) || d.specialty.toLowerCase().contains(q)).toList();
  }

  @override
  Future<Doctor> getDoctorById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockData.doctors.firstWhere((d) => d.id == id);
  }

  @override
  Future<List<Doctor>> getNearbyDoctors() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final sorted = List<Doctor>.from(MockData.doctors)..sort((a, b) => a.distance.compareTo(b.distance));
    return sorted;
  }

  @override
  Future<List<String>> getSpecialties() async {
    return ['Cardiologist', 'Neurologist', 'Endocrinologist', 'General Practitioner', 'Pulmonologist'];
  }
}
