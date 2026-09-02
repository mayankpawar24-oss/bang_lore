import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/models/user_model.dart';
import 'package:continuum_health/data/models/patient_model.dart';
import 'package:continuum_health/data/models/doctor_model.dart';
import 'package:continuum_health/data/models/permission_request_model.dart';
import 'package:continuum_health/data/models/family_member_model.dart';

void main() {
  group('UserModel & Registration Schema Tests', () {
    test('role enum serialization and deserialization', () {
      const user = UserModel(
        id: 'u_123',
        name: 'John Doe',
        email: 'john@example.com',
        role: UserRole.patient,
      );

      final json = user.toJson();
      expect(json['role'], 'patient');

      final deserialized = UserModel.fromJson(json);
      expect(deserialized.role, UserRole.patient);
      expect(deserialized.name, 'John Doe');
    });

    test('doctor role serialization', () {
      const user = UserModel(
        id: 'd_456',
        name: 'Dr. Smith',
        email: 'smith@example.com',
        role: UserRole.doctor,
      );

      final json = user.toJson();
      expect(json['role'], 'doctor');
      final deserialized = UserModel.fromJson(json);
      expect(deserialized.role, UserRole.doctor);
    });

    test('patient registration schema document validation', () {
      const user = UserModel(
        id: 'p_uid_789',
        name: 'Alice Cooper',
        email: 'alice@example.com',
        role: UserRole.patient,
      );

      final firestoreDoc = user.toFirestoreCreate();
      expect(firestoreDoc['name'], 'Alice Cooper');
      expect(firestoreDoc['email'], 'alice@example.com');
      expect(firestoreDoc['role'], 'patient');

      const patient = Patient(
        id: 'p_uid_789',
        name: 'Alice Cooper',
        age: 35,
        condition: 'General Wellness',
        status: 'stable',
        medicationAdherence: 100.0,
        isAuthorized: false,
        conditions: [],
      );
      final patientJson = patient.toJson();
      expect(patientJson['name'], 'Alice Cooper');
      expect(patientJson['age'], 35);
    });

    test('doctor registration schema document validation', () {
      const doctor = Doctor(
        id: 'd_uid_999',
        name: 'Dr. Aisha Patel',
        specialty: 'Cardiology',
        hospital: 'Metro Hospital',
        rating: 4.9,
        about: 'Practitioner',
        availableDays: ['Monday'],
        avatarUrl: '',
        distance: 0.0,
        isAvailable: true,
        phone: '',
      );

      final doctorJson = doctor.toJson();
      expect(doctorJson['name'], 'Dr. Aisha Patel');
      expect(doctorJson['specialty'], 'Cardiology');
    });

    test('dynamic initials generation logic', () {
      String getInitials(String name) {
        final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
        if (parts.isEmpty) return 'U';
        if (parts.length == 1) return parts.first[0].toUpperCase();
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }

      expect(getInitials('Margaret Chen'), 'MC');
      expect(getInitials('Dr. Aisha Patel'), 'DP');
      expect(getInitials('John'), 'J');
      expect(getInitials(''), 'U');
    });
  });

  group('AccessPermission Granular Tests', () {
    test('active permission status and expiration checks', () {
      final perm = AccessPermission(
        id: 'd_01_p_01',
        doctorId: 'd_01',
        doctorName: 'Dr. Aisha',
        patientId: 'p_01',
        patientName: 'Margaret',
        status: PermissionStatus.approved,
        requestedAt: DateTime.now(),
        permissions: const ['profile', 'vitals', 'aiChat'],
      );

      expect(perm.isActive, true);
      expect(perm.hasPermission('vitals'), true);
      expect(perm.hasPermission('aiChat'), true);
      expect(perm.hasPermission('medications'), false);
    });

    test('inactive when status is pending or denied', () {
      final perm = AccessPermission(
        id: 'd_01_p_01',
        doctorId: 'd_01',
        doctorName: 'Dr. Aisha',
        patientId: 'p_01',
        patientName: 'Margaret',
        status: PermissionStatus.pending,
        requestedAt: DateTime.now(),
        permissions: const ['vitals'],
      );

      expect(perm.isActive, false);
      expect(perm.hasPermission('vitals'), false);
    });
  });

  group('FamilyMember Model Tests', () {
    test('care tasks update and position persistence', () {
      final member = FamilyMember(
        id: 'fm_01',
        name: 'Grandmother',
        relationship: 'Grandmother',
        generation: 0,
        knownConditions: const ['Hypertension'],
        familyHistory: const ['Stroke'],
        careTasks: const [
          CareTask(id: 't1', title: 'Check BP', status: CareTaskStatus.todo),
        ],
        hydration: HydrationStatus.done,
        walking: WalkingStatus.needed,
        medication: MedicationStatus.active,
        positionX: 100.0,
        positionY: 200.0,
      );

      expect(member.positionX, 100.0);
      expect(member.careTasks.first.title, 'Check BP');

      final json = member.toJson();
      final fromJson = FamilyMember.fromJson(json);
      expect(fromJson.positionX, 100.0);
      expect(fromJson.careTasks.length, 1);
      expect(fromJson.knownConditions.first, 'Hypertension');
    });
  });
}
