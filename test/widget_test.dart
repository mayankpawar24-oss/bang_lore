import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/models/patient_model.dart';
import 'package:continuum_health/data/models/doctor_model.dart';
import 'package:continuum_health/data/models/user_model.dart';
import 'package:continuum_health/data/models/family_member_model.dart';
import 'package:continuum_health/data/models/reminder_model.dart';
import 'package:continuum_health/data/providers/providers.dart';
import 'package:continuum_health/features/patient/dashboard/screens/patient_dashboard_screen.dart';
import 'package:continuum_health/features/patient/family/screens/family_tree_screen.dart';

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

  Future<void> loadFamilyMembers(String uid) async {}
  Future<void> updateMember(FamilyMemberModel member) async {}
  Future<void> addMember(FamilyMemberModel member) async {}
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
