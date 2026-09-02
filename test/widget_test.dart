import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/models/patient_model.dart';
import 'package:continuum_health/data/models/doctor_model.dart';

void main() {
  test('Patient model default initialization', () {
    final patient = Patient(
      id: 'p_01',
      name: 'Test Patient',
      age: 45,
      condition: 'Stable',
      status: 'stable',
      medicationAdherence: 90.0,
      conditions: ['Hypertension'],
      isAuthorized: true,
    );

    expect(patient.name, 'Test Patient');
    expect(patient.medicationAdherence, 90.0);
  });

  test('Doctor model initialization', () {
    const doctor = Doctor(
      id: 'd_01',
      name: 'Dr. Test',
      specialty: 'Cardiology',
      hospital: 'City Hospital',
      rating: 4.8,
      distance: 2.5,
      avatarUrl: '',
      phone: '1234567890',
      about: 'About doctor',
      availableDays: ['Monday'],
      isAvailable: true,
    );

    expect(doctor.specialty, 'Cardiology');
    expect(doctor.isAvailable, true);
  });
}
