import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/models/patient_model.dart';
import 'package:continuum_health/data/models/doctor_model.dart';
import 'package:continuum_health/data/models/user_model.dart';
import 'package:continuum_health/data/models/family_member_model.dart';
import 'package:continuum_health/data/models/reminder_model.dart';
import 'package:continuum_health/data/models/report_model.dart';
import 'package:continuum_health/data/models/appointment_model.dart';
import 'package:continuum_health/data/providers/providers.dart';
import 'package:continuum_health/features/patient/dashboard/screens/patient_dashboard_screen.dart';
import 'package:continuum_health/features/patient/family/screens/family_tree_screen.dart';
import 'package:continuum_health/features/patient/profile/screens/patient_profile_screen.dart';
import 'package:continuum_health/features/doctor/profile/screens/doctor_profile_screen.dart';

class FamilyMembersNotifierMock extends StateNotifier<List<FamilyMemberModel>> implements FamilyMembersNotifier {
  FamilyMembersNotifierMock() : super([
    const FamilyMemberModel(
      id: 'fm_01',
      name: 'Grandmother',
      relationship: 'Grandmother',
      generation: 0,
      positionX: 400.0,
      positionY: 80.0,
      knownConditions: ['Hypertension'],
      familyHistory: [],
      careTasks: [],
      hydration: HydrationStatus.done,
      walking: WalkingStatus.needed,
      medication: MedicationStatus.active,
    ),
    const FamilyMemberModel(
      id: 'fm_02',
      name: 'Margaret Chen',
      relationship: 'Self',
      generation: 1,
      positionX: 400.0,
      positionY: 260.0,
      knownConditions: [],
      familyHistory: [],
      careTasks: [],
      hydration: HydrationStatus.done,
      walking: WalkingStatus.needed,
      medication: MedicationStatus.active,
    ),
  ]);

  @override
  Future<void> loadFamilyMembers(String uid) async {}
  @override
  Future<void> updateMember(FamilyMemberModel member) async {}
  @override
  Future<void> addMember(FamilyMemberModel member) async {}
  @override
  Future<void> deleteMember(String memberId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RemindersNotifierMock extends StateNotifier<List<ReminderModel>> implements RemindersNotifier {
  RemindersNotifierMock() : super([]);

  @override
  Future<void> loadReminders([String? uid]) async {}

  @override
  Future<void> addReminder(ReminderModel reminder) async {}

  @override
  Future<void> toggleReminder(String id) async {}

  @override
  Future<void> deleteReminder(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('PatientDashboardScreen renders without RenderBox errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('test_patient_uid'),
          currentUserProvider.overrideWith((ref) => Stream.value(
            const UserModel(id: 'test_patient_uid', name: 'Margaret Chen', email: 'test@example.com', role: UserRole.patient),
          )),
          currentPatientStreamProvider.overrideWith((ref) => Stream.value(
            const Patient(id: 'test_patient_uid', name: 'Margaret Chen', age: 30, condition: 'General Care', status: 'stable', medicationAdherence: 100, conditions: [], isAuthorized: true),
          )),
          appointmentsStreamProvider.overrideWith((ref) => Stream.value([])),
          medicationsStreamProvider.overrideWith((ref) => Stream.value([])),
          vitalsStreamProvider.overrideWith((ref) => Stream.value([])),
          reportsStreamProvider.overrideWith((ref) => Stream.value([])),
          doctorsStreamProvider.overrideWith((ref) => Stream.value([])),
          notificationsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: PatientDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PatientDashboardScreen), findsOneWidget);
    expect(find.text('Good morning,'), findsOneWidget);
    expect(find.text('Upload Health Records'), findsOneWidget);
  });

  testWidgets('FamilyTreeScreen renders with 2D InteractiveViewer canvas without errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('test_patient_uid'),
          familyMembersProvider.overrideWith((ref) => FamilyMembersNotifierMock()),
          remindersProvider.overrideWith((ref) => RemindersNotifierMock()),
        ],
        child: const MaterialApp(
          home: FamilyTreeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(FamilyTreeScreen), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('PatientProfileScreen renders without RenderBox errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('test_patient_uid'),
          currentUserProvider.overrideWith((ref) => Stream.value(
            const UserModel(id: 'test_patient_uid', name: 'Margaret Chen', email: 'test@example.com', role: UserRole.patient, telegramConnected: true, telegramChatId: '12345'),
          )),
          currentPatientStreamProvider.overrideWith((ref) => Stream.value(
            const Patient(id: 'test_patient_uid', name: 'Margaret Chen', age: 30, condition: 'General Care', status: 'stable', medicationAdherence: 100, conditions: [], isAuthorized: true),
          )),
          reportsStreamProvider.overrideWith((ref) => Stream.value([])),
          telegramStatusStreamProvider.overrideWith((ref) => Stream.value({'connected': true, 'chatId': '12345'})),
        ],
        child: const MaterialApp(
          home: PatientProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PatientProfileScreen), findsOneWidget);
    expect(find.text('Margaret Chen'), findsAtLeast(1));
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Medical Reports'), findsOneWidget);
    expect(find.text('Account & Actions'), findsOneWidget);
    expect(find.text('Telegram Connected'), findsOneWidget);
  });

  testWidgets('DoctorProfileScreen renders without RenderBox errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('test_doc_uid'),
          currentUserProvider.overrideWith((ref) => Stream.value(
            const UserModel(id: 'test_doc_uid', name: 'Dr. Aisha Patel', email: 'doc@example.com', role: UserRole.doctor, telegramConnected: false),
          )),
          currentDoctorStreamProvider.overrideWith((ref) => Stream.value(
            const Doctor(
              id: 'test_doc_uid',
              name: 'Dr. Aisha Patel',
              specialty: 'Cardiology',
              hospital: 'Metro Hospital',
              rating: 4.9,
              distance: 0.0,
              avatarUrl: '',
              phone: '+91 98765 43210',
              about: 'Heart specialist',
              availableDays: ['Monday', 'Tuesday'],
              isAvailable: true,
            ),
          )),
          telegramStatusStreamProvider.overrideWith((ref) => Stream.value({'connected': false, 'chatId': null})),
        ],
        child: const MaterialApp(
          home: DoctorProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(DoctorProfileScreen), findsOneWidget);
    expect(find.text('Doctor Profile'), findsOneWidget);
    expect(find.text('Dr. Aisha Patel'), findsOneWidget);
    expect(find.text('Cardiology'), findsOneWidget);
    expect(find.text('Connect Telegram'), findsAtLeast(1));
  });

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

  test('ReportModel Storage metadata round-trip', () {
    final report = ReportModel(
      id: 'doc_123',
      documentId: 'doc_123',
      patientId: 'patient_abc',
      title: 'Lab CBC Report',
      category: ReportCategory.lab,
      date: DateTime(2026, 8, 15),
      fileName: 'cbc_report.pdf',
      fileType: 'application/pdf',
      storagePath: 'patients/patient_abc/medicalDocuments/doc_123/cbc_report.pdf',
      downloadUrl: 'https://firebasestorage.googleapis.com/download/cbc.pdf',
      uploadedBy: 'patient_abc',
      documentCategory: 'lab',
    );

    final json = report.toJson();
    expect(json['documentId'], 'doc_123');
    expect(json['storagePath'], contains('patients/patient_abc/medicalDocuments'));
    expect(json['downloadUrl'], contains('https://firebasestorage.googleapis.com'));

    final parsed = ReportModel.fromJson(json);
    expect(parsed.documentId, 'doc_123');
    expect(parsed.fileName, 'cbc_report.pdf');
    expect(parsed.category, ReportCategory.lab);
  });

  test('AppointmentModel pending request fields round-trip', () {
    final appt = Appointment(
      id: 'appt_999',
      patientId: 'patient_abc',
      doctorId: 'doctor_xyz',
      doctorName: 'Dr. Aisha Patel',
      patientName: 'Margaret Chen',
      specialty: 'Cardiology',
      dateTime: DateTime(2026, 9, 5, 10, 30),
      durationMinutes: 30,
      status: AppointmentStatus.pending,
      notes: 'Chest tightness check',
      requestedAt: DateTime(2026, 9, 2),
    );

    expect(appt.appointmentId, 'appt_999');
    expect(appt.duration, 30);
    expect(appt.status, AppointmentStatus.pending);

    final json = appt.toJson();
    expect(json['appointmentId'], 'appt_999');
    expect(json['status'], 'pending');

    final parsed = Appointment.fromJson(json);
    expect(parsed.id, 'appt_999');
    expect(parsed.status, AppointmentStatus.pending);
    expect(parsed.notes, 'Chest tightness check');
  });
}
