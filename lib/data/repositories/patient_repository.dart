import '../models/patient_model.dart';
import '../models/permission_request_model.dart';
import '../mock/mock_data.dart';

abstract class PatientRepository {
  Future<List<Patient>> getPatients();
  Future<Patient> getPatientById(String id);
  Future<List<Patient>> getActivePatients();
  Future<List<Patient>> searchPatients(String query);
  Future<void> updatePatient(Patient patient);
  Future<PermissionRequest> requestAccess(String doctorId, String patientId);
  Future<void> approveAccess(String requestId);
  Future<void> denyAccess(String requestId);
  Future<List<PermissionRequest>> getPendingRequests(String patientId);
  Future<bool> isAuthorized(String doctorId, String patientId);
}

class MockPatientRepository implements PatientRepository {
  @override
  Future<List<Patient>> getPatients() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(MockData.patients);
  }

  @override
  Future<Patient> getPatientById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockData.patients.firstWhere((p) => p.id == id, orElse: () => MockData.currentPatient);
  }

  @override
  Future<List<Patient>> getActivePatients() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockData.patients.where((p) => p.status == 'attention' || p.status == 'critical').toList();
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final q = query.toLowerCase();
    return MockData.patients.where((p) => p.name.toLowerCase().contains(q) || p.condition.toLowerCase().contains(q)).toList();
  }

  @override
  Future<void> updatePatient(Patient patient) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<PermissionRequest> requestAccess(String doctorId, String patientId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final req = PermissionRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      doctorId: doctorId,
      doctorName: 'Dr. Aisha Patel',
      patientId: patientId,
      patientName: 'Margaret Chen',
      status: PermissionStatus.pending,
      requestedAt: DateTime.now(),
    );
    return req;
  }

  @override
  Future<void> approveAccess(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> denyAccess(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<List<PermissionRequest>> getPendingRequests(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  @override
  Future<bool> isAuthorized(String doctorId, String patientId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }
}
