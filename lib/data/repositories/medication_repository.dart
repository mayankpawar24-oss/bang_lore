import '../models/medication_model.dart';
import '../mock/mock_data.dart';

abstract class MedicationRepository {
  Future<List<Medication>> getMedications(String patientId);
  Future<void> markAsTaken(String medicationId);
  Future<double> getAdherence(String patientId);
}

class MockMedicationRepository implements MedicationRepository {
  final List<Medication> _medications = List.from(MockData.medications);

  @override
  Future<List<Medication>> getMedications(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _medications;
  }

  @override
  Future<void> markAsTaken(String medicationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _medications.indexWhere((m) => m.id == medicationId);
    if (index >= 0) {
      _medications[index] = _medications[index].copyWith(isTaken: true);
    }
  }

  @override
  Future<double> getAdherence(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockData.currentPatient.medicationAdherence;
  }
}
