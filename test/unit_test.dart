import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/models/user_model.dart';
import 'package:continuum_health/data/models/patient_model.dart';
import 'package:continuum_health/data/models/doctor_model.dart';
import 'package:continuum_health/data/models/permission_request_model.dart';
import 'package:continuum_health/data/models/family_member_model.dart';
import 'package:continuum_health/data/models/report_model.dart';
import 'package:continuum_health/data/models/appointment_model.dart';
import 'package:continuum_health/data/models/vital_model.dart';
import 'package:continuum_health/data/models/reminder_model.dart';

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

  group('ReportModel & Health Document Ingestion Tests', () {
    test('report category serialization and metadata validation', () {
      final now = DateTime.now();
      final report = ReportModel(
        id: 'rep_001',
        patientId: 'pat_001',
        title: 'Comprehensive Metabolic Panel',
        category: ReportCategory.lab,
        date: now,
        doctorOrFacility: 'City Lab Diagnostics',
        summary: 'Blood glucose normal, potassium optimal.',
        sharedWithDoctor: true,
        extractedData: {'fastingGlucose': 92, 'hba1c': 5.4},
      );

      final json = report.toJson();
      expect(json['category'], 'lab');
      expect(json['title'], 'Comprehensive Metabolic Panel');
      expect(json['sharedWithDoctor'], true);

      final parsed = ReportModel.fromJson(json);
      expect(parsed.category, ReportCategory.lab);
      expect(parsed.extractedData?['fastingGlucose'], 92);
    });

    test('discharge and prescription reports category mapping', () {
      final discharge = ReportModel(
        id: 'rep_002',
        patientId: 'pat_001',
        title: 'Inpatient Discharge Summary',
        category: ReportCategory.discharge,
        date: DateTime.now(),
        followUpInstructions: 'Follow-up with cardiologist in 7 days.',
      );

      expect(discharge.category, ReportCategory.discharge);
      expect(discharge.followUpInstructions, contains('cardiologist'));
    });
  });

  group('Appointment Lifecycle & Status State Machine Tests', () {
    test('appointment initial requested/pending status and transitions', () {
      final now = DateTime.now().add(const Duration(days: 2));
      final appt = Appointment(
        id: 'appt_001',
        patientId: 'pat_001',
        patientName: 'Margaret Chen',
        doctorId: 'doc_001',
        doctorName: 'Dr. Aisha Patel',
        specialty: 'Cardiology',
        dateTime: now,
        durationMinutes: 30,
        status: AppointmentStatus.requested,
      );

      expect(appt.status, AppointmentStatus.requested);

      // Doctor Approves
      final approved = appt.copyWith(status: AppointmentStatus.approved);
      expect(approved.status, AppointmentStatus.approved);

      // Consultation Completed
      final completed = approved.copyWith(status: AppointmentStatus.completed);
      expect(completed.status, AppointmentStatus.completed);

      // Or Cancelled
      final cancelled = appt.copyWith(status: AppointmentStatus.cancelled);
      expect(cancelled.status, AppointmentStatus.cancelled);
    });
  });

  group('Vital & Reminder Telemetry Tests', () {
    test('vital telemetry values serialization', () {
      final vital = Vital(
        id: 'v_001',
        patientId: 'pat_001',
        heartRate: 72,
        systolic: 120,
        diastolic: 80,
        spo2: 98,
        weight: 68.5,
        recordedAt: DateTime.now(),
      );

      final json = vital.toJson();
      expect(json['heartRate'], 72);
      expect(json['systolic'], 120);
      expect(json['diastolic'], 80);
      expect(json['spo2'], 98);
      expect(json['weight'], 68.5);
    });

    test('reminder completion toggle', () {
      final reminder = Reminder(
        id: 'rem_001',
        patientId: 'pat_001',
        title: 'Take Metformin 500mg',
        type: ReminderType.medicine,
        dateTime: DateTime.now(),
        isCompleted: false,
      );

      expect(reminder.isCompleted, false);
      final completed = reminder.copyWith(isCompleted: true);
      expect(completed.isCompleted, true);
    });
  });
}
