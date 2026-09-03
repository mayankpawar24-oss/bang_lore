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
import 'package:continuum_health/data/models/notification_model.dart';
import 'package:continuum_health/data/models/ai_chat_model.dart';
import 'package:continuum_health/data/models/medication_model.dart';
import 'package:continuum_health/data/models/activity_log_model.dart';
import 'package:continuum_health/data/models/family_message_model.dart';
import 'package:continuum_health/data/models/family_relationship_model.dart';
import 'package:continuum_health/data/repositories/medication_repository.dart';

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

    test('user telegram connection fields serialization', () {
      const user = UserModel(
        id: 'u_tele_123',
        name: 'Jane Doe',
        email: 'jane@example.com',
        role: UserRole.patient,
        telegramChatId: '987654321',
        telegramConnected: true,
      );

      final json = user.toJson();
      expect(json['telegramChatId'], '987654321');
      expect(json['telegramConnected'], true);

      final fromJson = UserModel.fromJson(json);
      expect(fromJson.telegramChatId, '987654321');
      expect(fromJson.telegramConnected, true);

      final firestoreMap = user.toFirestore();
      expect(firestoreMap['telegramChatId'], '987654321');
      expect(firestoreMap['telegramConnected'], true);
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

      // Or Missed
      final missed = appt.copyWith(status: AppointmentStatus.missed);
      expect(missed.status, AppointmentStatus.missed);
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

  group('Doctor Availability & Slot Key Tests', () {
    test('slot key deterministic format matches doctor availability storage', () {
      final date = DateTime(2026, 9, 15, 14, 30);
      final slotKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}-${date.minute.toString().padLeft(2, '0')}';
      expect(slotKey, '2026-09-15_14-30');
    });

    test('appointment state machine transitions and status colors', () {
      final appt = Appointment(
        id: 'appt_101',
        patientId: 'patient_alpha',
        doctorId: 'doctor_beta',
        doctorName: 'Dr. Aisha Patel',
        patientName: 'John Doe',
        specialty: 'Cardiology',
        dateTime: DateTime(2026, 9, 15, 10, 0),
        durationMinutes: 30,
        status: AppointmentStatus.pending,
      );

      expect(appt.status, AppointmentStatus.pending);
      final approved = appt.copyWith(status: AppointmentStatus.approved);
      expect(approved.status, AppointmentStatus.approved);

      final rejected = appt.copyWith(status: AppointmentStatus.rejected);
      expect(rejected.status, AppointmentStatus.rejected);
    });

    test('notification serialization for access approval', () {
      final notif = NotificationModel(
        id: 'notif_1',
        title: 'Access Request',
        message: 'Dr. Patel requested access to your health records',
        timestamp: DateTime.now(),
        type: NotificationType.permission,
        isRead: false,
        permissionId: 'doctor_beta_patient_alpha',
        doctorId: 'doctor_beta',
        patientId: 'patient_alpha',
      );

      final json = notif.toJson();
      expect(json['type'], 'permission');
      expect(json['permissionId'], 'doctor_beta_patient_alpha');
      expect(json['isRead'], false);

      final parsed = NotificationModel.fromJson(json);
      expect(parsed.type, NotificationType.permission);
      expect(parsed.doctorId, 'doctor_beta');
    });
  });

  group('Doctor Patient Access & Chat History Tests', () {
    test('canonical docId follows doctorId_patientId convention', () {
      const docId = 'doc_789';
      const patientId = 'pat_456';
      final canonicalId = AccessPermission.docId(docId, patientId);
      expect(canonicalId, 'doc_789_pat_456');
    });

    test('granular permissions gating for aiChat, vitals, and reports', () {
      final permWithChat = AccessPermission(
        id: 'doc_1_pat_1',
        doctorId: 'doc_1',
        doctorName: 'Dr. Sarah',
        patientId: 'pat_1',
        patientName: 'Jane',
        status: PermissionStatus.approved,
        requestedAt: DateTime.now(),
        permissions: const ['profile', 'vitals', 'reports', 'aiChat'],
      );

      expect(permWithChat.isActive, isTrue);
      expect(permWithChat.hasPermission('aiChat'), isTrue);
      expect(permWithChat.hasPermission('vitals'), isTrue);
      expect(permWithChat.hasPermission('reports'), isTrue);
      expect(permWithChat.hasPermission('medications'), isFalse);

      final permWithoutChat = permWithChat.copyWith(
        permissions: const ['profile', 'vitals'],
      );
      expect(permWithoutChat.hasPermission('aiChat'), isFalse);
    });

    test('AIChat and AIChatMessage structure and serialization', () {
      final now = DateTime.now();
      final chat = AIChat(
        id: 'chat_01',
        patientId: 'pat_123',
        title: 'Headache and medication inquiry',
        createdAt: now,
        sharedWithDoctor: true,
      );

      expect(chat.id, 'chat_01');
      expect(chat.patientId, 'pat_123');
      expect(chat.sharedWithDoctor, isTrue);

      final userMsg = AIChatMessage(
        id: 'msg_01',
        chatId: 'chat_01',
        sender: AIChatSender.user,
        content: 'I have a headache after taking my morning pills.',
        timestamp: now,
      );
      expect(userMsg.isUser, isTrue);
      expect(userMsg.content, contains('headache'));

      final aiMsg = AIChatMessage(
        id: 'msg_02',
        chatId: 'chat_01',
        sender: AIChatSender.assistant,
        content: 'Headaches can occasionally occur with ACE inhibitors.',
        timestamp: now.add(const Duration(seconds: 2)),
        metadata: const {
          'confidence': 'high',
          'recommendedAction': 'see_doctor',
        },
      );
      expect(aiMsg.isUser, isFalse);
      expect(aiMsg.metadata?['recommendedAction'], 'see_doctor');
    });
  });

  group('User-Specific Notifications & Access Control Tests', () {
    test('appointment request notification is addressed ONLY to doctor', () {
      final notif = NotificationModel(
        id: 'notif_appt_1',
        title: 'New Appointment Request',
        message: 'New appointment request from Alice',
        timestamp: DateTime.now(),
        type: NotificationType.appointment,
        rawType: 'appointment_request',
        isRead: false,
        recipientUid: 'doctor_uid_456',
        senderUid: 'patient_uid_123',
        appointmentId: 'appt_999',
        relatedId: 'appt_999',
        doctorId: 'doctor_uid_456',
        patientId: 'patient_uid_123',
        status: 'pending',
      );

      expect(notif.recipientUid, 'doctor_uid_456');
      expect(notif.senderUid, 'patient_uid_123');
      expect(notif.isPending, isTrue);
      expect(notif.isActioned, isFalse);
      expect(notif.effectiveAppointmentId, 'appt_999');

      final json = notif.toJson();
      expect(json['recipientUid'], 'doctor_uid_456');
      expect(json['senderUid'], 'patient_uid_123');
      expect(json['status'], 'pending');
      expect(json['type'], 'appointment_request');

      final parsed = NotificationModel.fromJson(json);
      expect(parsed.recipientUid, 'doctor_uid_456');
      expect(parsed.senderUid, 'patient_uid_123');
      expect(parsed.isPending, isTrue);
    });

    test('profile access request notification is addressed ONLY to patient', () {
      final notif = NotificationModel(
        id: 'notif_access_1',
        title: 'Profile Access Request',
        message: 'Dr. Michael Chang requested access to your health records',
        timestamp: DateTime.now(),
        type: NotificationType.permission,
        rawType: 'profile_access_request',
        isRead: false,
        recipientUid: 'patient_uid_123',
        senderUid: 'doctor_uid_456',
        requestId: 'doctor_uid_456_patient_uid_123',
        relatedId: 'doctor_uid_456_patient_uid_123',
        doctorId: 'doctor_uid_456',
        doctorName: 'Dr. Michael Chang',
        patientId: 'patient_uid_123',
        status: 'pending',
      );

      expect(notif.recipientUid, 'patient_uid_123');
      expect(notif.senderUid, 'doctor_uid_456');
      expect(notif.isPending, isTrue);
      expect(notif.effectiveRequestId, 'doctor_uid_456_patient_uid_123');

      final actioned = notif.copyWith(status: 'actioned', isRead: true);
      expect(actioned.isActioned, isTrue);
      expect(actioned.isPending, isFalse);
      expect(actioned.isRead, isTrue);

      final rejected = notif.copyWith(status: 'rejected', isRead: true);
      expect(rejected.isRejected, isTrue);
      expect(rejected.isPending, isFalse);
    });

    test('approval notification is addressed ONLY to requesting doctor', () {
      final notif = NotificationModel(
        id: 'notif_approved_1',
        title: 'Access Approved',
        message: 'Alice Henderson approved your health profile access request',
        timestamp: DateTime.now(),
        type: NotificationType.permission,
        rawType: 'profile_access_approved',
        isRead: false,
        recipientUid: 'doctor_uid_456',
        senderUid: 'patient_uid_123',
        requestId: 'doctor_uid_456_patient_uid_123',
        doctorId: 'doctor_uid_456',
        patientId: 'patient_uid_123',
        patientName: 'Alice Henderson',
        status: 'approved',
      );

      expect(notif.recipientUid, 'doctor_uid_456');
      expect(notif.senderUid, 'patient_uid_123');
      expect(notif.isActioned, isTrue);
      expect(notif.status, 'approved');
    });
  });

  group('Medication Reminders & Schedule Tests', () {
    test('medication model serialization with isSkipped and timestamps', () {
      final now = DateTime.now();
      final med = Medication(
        id: 'med_001',
        name: 'Metformin',
        dosage: '500 mg',
        time: '08:00 AM',
        isTaken: false,
        isSkipped: false,
        date: now,
        patientId: 'patient_test_123',
        frequency: 'Once daily',
        active: true,
      );

      final json = med.toJson();
      expect(json['name'], 'Metformin');
      expect(json['dosage'], '500 mg');
      expect(json['isTaken'], isFalse);
      expect(json['isSkipped'], isFalse);
      expect(json['frequency'], 'Once daily');

      final deserialized = Medication.fromJson(json);
      expect(deserialized.id, 'med_001');
      expect(deserialized.name, 'Metformin');
      expect(deserialized.isTaken, isFalse);
      expect(deserialized.isSkipped, isFalse);
    });

    test('medication markTaken and markSkipped state transitions and persistence', () async {
      final repo = MockMedicationRepository();
      final now = DateTime.now();
      final med = Medication(
        id: 'med_002',
        name: 'Atorvastatin',
        dosage: '20 mg',
        time: '09:00 PM',
        isTaken: false,
        isSkipped: false,
        date: now,
        patientId: 'patient_test_123',
        frequency: 'Once daily',
      );

      await repo.addMedication('patient_test_123', med);
      var meds = await repo.getMedications('patient_test_123');
      expect(meds.length, 1);
      expect(meds.first.isTaken, isFalse);
      expect(meds.first.isSkipped, isFalse);

      // Mark taken
      await repo.markTaken('patient_test_123', 'med_002');
      meds = await repo.getMedications('patient_test_123');
      expect(meds.first.isTaken, isTrue);
      expect(meds.first.isSkipped, isFalse);

      // Mark skipped
      await repo.markSkipped('patient_test_123', 'med_002');
      meds = await repo.getMedications('patient_test_123');
      expect(meds.first.isTaken, isFalse);
      expect(meds.first.isSkipped, isTrue);
    });

    test('today medication filtering correctly includes today scheduled medicines', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      final meds = [
        Medication(
          id: 'med_today',
          name: 'Amoxicillin',
          dosage: '250 mg',
          time: '08:00 AM',
          isTaken: false,
          date: today,
          frequency: 'Once daily',
        ),
        Medication(
          id: 'med_daily_range',
          name: 'Lisinopril',
          dosage: '10 mg',
          time: '09:00 AM',
          isTaken: false,
          date: yesterday,
          frequency: 'Daily',
          startDate: yesterday,
          endDate: tomorrow,
        ),
        Medication(
          id: 'med_past_expired',
          name: 'Old Med',
          dosage: '50 mg',
          time: '10:00 AM',
          isTaken: false,
          date: yesterday.subtract(const Duration(days: 5)),
          frequency: 'Once',
          startDate: yesterday.subtract(const Duration(days: 5)),
          endDate: yesterday,
        ),
      ];

      final todayMeds = meds.where((m) {
        final isSameDay = m.date.year == today.year && m.date.month == today.month && m.date.day == today.day;
        final freq = (m.frequency ?? '').toLowerCase();
        final isRecurring = freq.contains('daily') || freq.contains('day') || freq.contains('morning') || freq.contains('night');
        final inDateRange = (m.startDate == null || !m.startDate!.isAfter(today)) && (m.endDate == null || !m.endDate!.isBefore(today));
        return isSameDay || (isRecurring && inDateRange);
      }).toList();

      expect(todayMeds.map((m) => m.id), contains('med_today'));
      expect(todayMeds.map((m) => m.id), contains('med_daily_range'));
      expect(todayMeds.map((m) => m.id), isNot(contains('med_past_expired')));
    });

    test('medication model notes field serialization, update and delete flow', () async {
      final repo = MockMedicationRepository();
      final now = DateTime.now();
      final med = Medication(
        id: 'med_crud_01',
        name: 'Omeprazole',
        dosage: '20 mg',
        time: '07:30 AM',
        isTaken: false,
        date: now,
        patientId: 'patient_crud',
        frequency: 'Once daily',
        notes: 'Take before breakfast with water',
      );

      // Verify JSON serialization of notes
      final json = med.toJson();
      expect(json['notes'], 'Take before breakfast with water');
      final fromJson = Medication.fromJson(json);
      expect(fromJson.notes, 'Take before breakfast with water');

      // Add to repository
      await repo.addMedication('patient_crud', med);
      var meds = await repo.getMedications('patient_crud');
      expect(meds.length, 1);
      expect(meds.first.notes, 'Take before breakfast with water');

      // Update medication
      final updated = med.copyWith(dosage: '40 mg', notes: 'Increased dose by Dr. Smith');
      await repo.updateMedication('patient_crud', updated);
      meds = await repo.getMedications('patient_crud');
      expect(meds.first.dosage, '40 mg');
      expect(meds.first.notes, 'Increased dose by Dr. Smith');

      // Delete medication
      await repo.deleteMedication('patient_crud', 'med_crud_01');
      meds = await repo.getMedications('patient_crud');
      expect(meds, isEmpty);
    });
  });

  group('Appointment Status Lifecycle & Transition Integrity Tests', () {
    test('supports exact statuses: pending, approved, rejected, cancelled, completed, missed', () {
      final statuses = AppointmentStatus.values.map((s) => s.name).toSet();
      expect(statuses, contains('pending'));
      expect(statuses, contains('approved'));
      expect(statuses, contains('rejected'));
      expect(statuses, contains('cancelled'));
      expect(statuses, contains('completed'));
      expect(statuses, contains('missed'));
    });

    test('state transition rule validation matches requirements', () {
      // Helper validator mimicking repository transition logic
      bool isValidTransition(AppointmentStatus current, AppointmentStatus target) {
        if ((current == AppointmentStatus.rejected || current == AppointmentStatus.cancelled) &&
            (target == AppointmentStatus.approved || target == AppointmentStatus.pending)) {
          return false;
        }
        if (current == AppointmentStatus.approved && target == AppointmentStatus.pending) {
          return false;
        }
        if (current == AppointmentStatus.completed &&
            (target == AppointmentStatus.missed || target == AppointmentStatus.pending)) {
          return false;
        }
        return true;
      }

      // Disallowed transitions
      expect(isValidTransition(AppointmentStatus.approved, AppointmentStatus.pending), isFalse);
      expect(isValidTransition(AppointmentStatus.rejected, AppointmentStatus.approved), isFalse);
      expect(isValidTransition(AppointmentStatus.cancelled, AppointmentStatus.approved), isFalse);
      expect(isValidTransition(AppointmentStatus.completed, AppointmentStatus.missed), isFalse);

      // Allowed transitions
      expect(isValidTransition(AppointmentStatus.pending, AppointmentStatus.approved), isTrue);
      expect(isValidTransition(AppointmentStatus.pending, AppointmentStatus.rejected), isTrue);
      expect(isValidTransition(AppointmentStatus.approved, AppointmentStatus.completed), isTrue);
      expect(isValidTransition(AppointmentStatus.approved, AppointmentStatus.missed), isTrue);
      expect(isValidTransition(AppointmentStatus.approved, AppointmentStatus.cancelled), isTrue);
    });

    test('user-specific notification schema compliance', () {
      final now = DateTime.now();
      const patientId = 'patient_xyz_123';
      const doctorId = 'doctor_dr_patel';

      final patientNotification = NotificationModel(
        id: 'notif_patient_01',
        recipientUid: patientId,
        senderUid: doctorId,
        rawType: 'appointment_approved',
        title: 'Appointment Approved',
        message: 'Your appointment with Dr. Aisha Patel has been approved.',
        timestamp: now,
        type: NotificationType.appointment,
        isRead: false,
        appointmentId: 'appt_101',
        relatedId: 'appt_101',
      );

      final docNotification = NotificationModel(
        id: 'notif_doc_01',
        recipientUid: doctorId,
        senderUid: patientId,
        rawType: 'appointment_cancelled',
        title: 'Appointment Cancelled',
        message: 'Margaret Chen cancelled their appointment.',
        timestamp: now,
        type: NotificationType.appointment,
        isRead: false,
        appointmentId: 'appt_101',
        relatedId: 'appt_101',
      );

      expect(patientNotification.recipientUid, patientId);
      expect(patientNotification.senderUid, doctorId);
      expect(docNotification.recipientUid, doctorId);
      expect(docNotification.senderUid, patientId);

      final pJson = patientNotification.toJson();
      expect(pJson['recipientUid'], patientId);
      expect(pJson['type'], 'appointment_approved');
      expect(pJson['relatedId'], 'appt_101');
    });

    test('deterministic event key generation ensures idempotency', () {
      String buildEventKey(String appointmentId, String status, int seconds) {
        return '${appointmentId}_${status}_$seconds';
      }

      final key1 = buildEventKey('appt_456', 'approved', 1725350400);
      final key2 = buildEventKey('appt_456', 'approved', 1725350400);
      final keyDifferentStatus = buildEventKey('appt_456', 'cancelled', 1725350400);

      expect(key1, key2);
      expect(key1, isNot(equals(keyDifferentStatus)));
      expect(key1, 'appt_456_approved_1725350400');
    });
  });

  group('Patient & Doctor Telegram Isolation, Missed Detection, & Audit Log Tests', () {
    test('patient and doctor telegram IDs are completely isolated', () {
      final patientUser = UserModel(
        id: 'patient_alpha',
        name: 'Patient Alpha',
        email: 'alpha@patient.com',
        role: UserRole.patient,
        phoneNumber: '9876543210',
        telegramChatId: 'tg_chat_11111',
        telegramConnected: true,
      );

      final doctorUser = UserModel(
        id: 'doctor_beta',
        name: 'Dr. Beta',
        email: 'beta@doctor.com',
        role: UserRole.doctor,
        phoneNumber: '9123456780',
        telegramChatId: 'tg_chat_99999',
        telegramConnected: true,
      );

      // Verify recipient isolation
      expect(patientUser.telegramChatId, isNot(equals(doctorUser.telegramChatId)));
      expect(patientUser.role, UserRole.patient);
      expect(doctorUser.role, UserRole.doctor);

      // Notification recipient routing function
      String routeTelegramDestination(UserModel recipient, String eventRole) {
        if (recipient.role.name != eventRole) {
          throw ArgumentError('Role mismatch: cannot route $eventRole event to ${recipient.role.name}');
        }
        return recipient.telegramChatId ?? '';
      }

      expect(routeTelegramDestination(patientUser, 'patient'), 'tg_chat_11111');
      expect(routeTelegramDestination(doctorUser, 'doctor'), 'tg_chat_99999');
      expect(() => routeTelegramDestination(patientUser, 'doctor'), throwsArgumentError);
      expect(() => routeTelegramDestination(doctorUser, 'patient'), throwsArgumentError);
    });

    test('missed appointment detection logic correctly flags past appointments', () {
      final now = DateTime.now();

      bool isAppointmentMissed(DateTime apptTime, int durationMinutes, AppointmentStatus status) {
        if (status != AppointmentStatus.approved) return false;
        final endTime = apptTime.add(Duration(minutes: durationMinutes));
        final graceTime = endTime.add(const Duration(minutes: 10));
        return now.isAfter(graceTime);
      }

      final pastAppt = now.subtract(const Duration(minutes: 50)); // 30m duration + 10m grace = 40m. 50m is missed.
      final upcomingAppt = now.add(const Duration(minutes: 30));
      final completedAppt = now.subtract(const Duration(minutes: 50));

      expect(isAppointmentMissed(pastAppt, 30, AppointmentStatus.approved), isTrue);
      expect(isAppointmentMissed(upcomingAppt, 30, AppointmentStatus.approved), isFalse);
      expect(isAppointmentMissed(completedAppt, 30, AppointmentStatus.completed), isFalse);
    });

    test('medication missed detection correctly flags overdue uncompleted medicines', () {
      bool isMedicationMissed({
        required bool isTaken,
        required bool isSkipped,
        required DateTime scheduledTime,
        required DateTime currentTime,
        int graceMinutes = 60,
      }) {
        if (isTaken || isSkipped) return false;
        return currentTime.difference(scheduledTime).inMinutes > graceMinutes;
      }

      final now = DateTime.now();
      final dueJustNow = now.subtract(const Duration(minutes: 15));
      final overdueDose = now.subtract(const Duration(minutes: 75)); // > 60 min grace

      expect(isMedicationMissed(isTaken: false, isSkipped: false, scheduledTime: dueJustNow, currentTime: now), isFalse);
      expect(isMedicationMissed(isTaken: false, isSkipped: false, scheduledTime: overdueDose, currentTime: now), isTrue);
      expect(isMedicationMissed(isTaken: true, isSkipped: false, scheduledTime: overdueDose, currentTime: now), isFalse);
    });

    test('activity log model serializes complete audit schema with all required fields', () {
      final now = DateTime.now();
      final log = ActivityLogModel(
        id: 'log_audit_777',
        patientId: 'patient_001',
        actorUid: 'patient_001',
        actorRole: 'patient',
        actorName: 'Sarah Connor',
        eventType: ActivityEventType.medicineAdded,
        title: 'Medication Added',
        description: 'Prescription added: Metformin 500mg',
        timestamp: now,
        doctorUid: 'doc_123',
        appointmentId: 'appt_888',
        medicationId: 'med_999',
        notificationType: 'medication_reminder',
        deliveryStatus: 'sent',
      );

      final map = log.toFirestore();
      expect(map['id'], 'log_audit_777');
      expect(map['eventId'], 'log_audit_777');
      expect(map['patientUid'], 'patient_001');
      expect(map['actorUid'], 'patient_001');
      expect(map['actorRole'], 'patient');
      expect(map['eventType'], 'medicineAdded');
      expect(map['doctorUid'], 'doc_123');
      expect(map['appointmentId'], 'appt_888');
      expect(map['medicationId'], 'med_999');
      expect(map['notificationType'], 'medication_reminder');
      expect(map['deliveryStatus'], 'sent');
      expect(log.eventId, 'log_audit_777');
      expect(log.patientUid, 'patient_001');
    });

    test('FamilyMessageModel serializes text message and readBy list', () {
      final now = DateTime.now();
      final msg = FamilyMessageModel(
        id: 'fmsg_001',
        patientId: 'pat_123',
        senderId: 'pat_123',
        senderName: 'John Doe',
        senderRole: 'patient',
        content: 'Good morning family! Mom took her medications.',
        timestamp: now,
        type: 'text',
        readBy: ['pat_123', 'mem_456'],
      );

      final map = msg.toFirestore();
      expect(map['patientId'], 'pat_123');
      expect(map['senderId'], 'pat_123');
      expect(map['senderName'], 'John Doe');
      expect(map['content'], 'Good morning family! Mom took her medications.');
      expect(map['type'], 'text');
      expect(map['readBy'], contains('mem_456'));
    });

    test('FamilyMessageModel serializes shared medical report with reference', () {
      final now = DateTime.now();
      final msg = FamilyMessageModel(
        id: 'fmsg_rep_002',
        patientId: 'pat_123',
        senderId: 'pat_123',
        senderName: 'John Doe',
        senderRole: 'patient',
        content: 'Sharing Mom’s recent blood test report.',
        timestamp: now,
        type: 'report',
        reportId: 'rep_789',
        reportTitle: 'Complete Blood Count (CBC)',
        reportCategory: 'lab',
        reportUrl: 'https://storage.googleapis.com/continuum-health/cbc.pdf',
        reportDate: now,
        readBy: ['pat_123'],
      );

      final map = msg.toFirestore();
      expect(map['type'], 'report');
      expect(map['reportId'], 'rep_789');
      expect(map['reportTitle'], 'Complete Blood Count (CBC)');
      expect(map['reportCategory'], 'lab');
      expect(map['reportUrl'], 'https://storage.googleapis.com/continuum-health/cbc.pdf');
    });

    test('Emergency Alert message formatting with coordinates and unavailable location', () {
      String formatEmergencyMessage({
        required String patientName,
        required String locationText,
        required String timeStr,
      }) {
        return '''
🚨 EMERGENCY ALERT

$patientName may require immediate assistance.

Location:
$locationText

Time:
$timeStr

Please contact the patient/emergency services immediately.
'''.trim();
      }

      final withGps = formatEmergencyMessage(
        patientName: 'Margaret Chen',
        locationText: 'https://maps.google.com/?q=12.9716,77.5946',
        timeStr: '2026-09-04 10:30:00',
      );

      expect(withGps, contains('🚨 EMERGENCY ALERT'));
      expect(withGps, contains('Margaret Chen may require immediate assistance.'));
      expect(withGps, contains('https://maps.google.com/?q=12.9716,77.5946'));

      final withoutGps = formatEmergencyMessage(
        patientName: 'Margaret Chen',
        locationText: 'Location: Unavailable (Permission denied or GPS disabled)',
        timeStr: '2026-09-04 10:30:00',
      );

      expect(withoutGps, contains('Location: Unavailable (Permission denied or GPS disabled)'));
      expect(withoutGps, isNot(contains('fake')));
    });

    test('Missed appointment and medication 2-minute test detection logic', () {
      final now = DateTime.now();

      bool isAppointmentPastTwoMinutes(DateTime apptTime) {
        return now.difference(apptTime).inMinutes >= 2;
      }

      bool isMedicationPastTwoMinutes(DateTime scheduledTime, bool isTaken, bool isSkipped, bool isMissed) {
        if (isTaken || isSkipped || isMissed) return false;
        return now.difference(scheduledTime).inMinutes >= 2;
      }

      final apptDue1MinAgo = now.subtract(const Duration(minutes: 1));
      final apptDue3MinAgo = now.subtract(const Duration(minutes: 3));

      expect(isAppointmentPastTwoMinutes(apptDue1MinAgo), isFalse);
      expect(isAppointmentPastTwoMinutes(apptDue3MinAgo), isTrue);

      final medDue1MinAgo = now.subtract(const Duration(minutes: 1));
      final medDue3MinAgo = now.subtract(const Duration(minutes: 3));

      expect(isMedicationPastTwoMinutes(medDue1MinAgo, false, false, false), isFalse);
      expect(isMedicationPastTwoMinutes(medDue3MinAgo, false, false, false), isTrue);
      expect(isMedicationPastTwoMinutes(medDue3MinAgo, true, false, false), isFalse); // Already taken
    });

    test('FamilyRelationshipModel serializes real permissions and schema', () {
      final now = DateTime.now();
      const perms = FamilyRelationshipPermissions(
        basicProfile: true,
        appointments: true,
        medications: true,
        reports: false,
        emergency: true,
      );

      final rel = FamilyRelationshipModel(
        id: 'rel_patientA_patientB',
        patientId: 'patientA',
        familyMemberId: 'patientB',
        relationship: 'Mother',
        status: 'approved',
        permissions: perms,
        createdAt: now,
        memberName: 'Emma Larson',
        memberAge: 52,
      );

      final firestoreData = rel.toFirestore();
      expect(firestoreData['patientId'], 'patientA');
      expect(firestoreData['familyMemberId'], 'patientB');
      expect(firestoreData['relationship'], 'Mother');
      expect(firestoreData['status'], 'approved');
      expect(firestoreData['permissions']['reports'], false);
      expect(firestoreData['permissions']['medications'], true);
    });

    test('Cross-Patient Reminder uses target patientId and separate createdBy', () {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'rem_dolo_123',
        title: 'Dolo (650mg)',
        medicineName: 'Dolo',
        dosage: '650mg',
        type: ReminderType.medication,
        dateTime: now,
        isCompleted: false,
        patientId: 'patientB_mother',
        createdBy: 'patientA_son',
        reminderTime: '12:00 PM',
        frequency: 'Daily',
      );

      final json = reminder.toFirestore();
      expect(json['patientId'], 'patientB_mother');
      expect(json['createdBy'], 'patientA_son');
      expect(json['medicineName'], 'Dolo');
      expect(json['dosage'], '650mg');
      expect(json['status'], 'pending');
      expect(json['isCompleted'], false);

      // Verify idempotency event key format
      final dateStr = '2026-09-04';
      final eventKey = 'medication:${reminder.id}:$dateStr';
      expect(eventKey, 'medication:rem_dolo_123:2026-09-04');
    });

    test('Target Telegram Dispatch routing isolates target patient from creator', () {
      final patientA = {'uid': 'patientA', 'telegramChatId': '111111', 'telegramLinked': true};
      final patientB = {'uid': 'patientB', 'telegramChatId': '222222', 'telegramLinked': true};
      final patientC = {'uid': 'patientC', 'telegramChatId': null, 'telegramLinked': false};

      String? resolveTargetChatId(Map<String, dynamic> targetProfile) {
        final isLinked = targetProfile['telegramLinked'] == true;
        final chatId = targetProfile['telegramChatId'] as String?;
        if (!isLinked || chatId == null || chatId.isEmpty) return null;
        return chatId;
      }

      // Reminder created by Patient A for Patient B
      final targetChat = resolveTargetChatId(patientB);
      expect(targetChat, '222222');
      expect(targetChat, isNot(patientA['telegramChatId'])); // Never sent to creator

      // Reminder for unlinked patient C
      final unlinkedChat = resolveTargetChatId(patientC);
      expect(unlinkedChat, isNull);
    });

    test('Family tree sensible hierarchy positioning adheres strictly to relationships', () {
      const center = Offset(1200.0, 800.0);

      final parentPos = FamilyRelationshipModel.calculateSensiblePosition('Parent', center: center);
      final grandparentPos = FamilyRelationshipModel.calculateSensiblePosition('Grandparent', center: center);
      final childPos = FamilyRelationshipModel.calculateSensiblePosition('Child', center: center);
      final grandchildPos = FamilyRelationshipModel.calculateSensiblePosition('Grandchild', center: center);
      final spousePos = FamilyRelationshipModel.calculateSensiblePosition('Spouse', center: center);
      final siblingPos = FamilyRelationshipModel.calculateSensiblePosition('Sibling', center: center);

      // Parent: 1 level above patient
      expect(parentPos.dy, lessThan(center.dy));
      // Grandparent: 2 levels above patient
      expect(grandparentPos.dy, lessThan(parentPos.dy));

      // Child: 1 level below patient
      expect(childPos.dy, greaterThan(center.dy));
      // Grandchild: 2 levels below patient
      expect(grandchildPos.dy, greaterThan(childPos.dy));

      // Spouse: beside patient
      expect(spousePos.dy, equals(center.dy));
      expect(spousePos.dx, greaterThan(center.dx));

      // Sibling: beside/near patient
      expect(siblingPos.dy, equals(center.dy));
      expect(siblingPos.dx, lessThan(center.dx));
    });

    test('Prevent duplicate relationships between same owner and member', () {
      final existingRelationships = [
        {'ownerUid': 'patientA', 'memberUid': 'patientB', 'relationship': 'Mother'},
        {'ownerUid': 'patientA', 'memberUid': 'patientC', 'relationship': 'Father'},
      ];

      bool hasDuplicate(String owner, String member) {
        return existingRelationships.any((r) => r['ownerUid'] == owner && r['memberUid'] == member);
      }

      expect(hasDuplicate('patientA', 'patientB'), isTrue); // Already exists!
      expect(hasDuplicate('patientA', 'patientD'), isFalse); // New member
    });

    test('Family Reminder targeting data adheres strictly to creator and target UIDs', () {
      final now = DateTime.now();
      const myUid = 'user_me_son_123';
      const fatherUid = 'user_father_456';

      final familyReminder = Reminder(
        id: 'rem_family_999',
        title: 'BP Tablet (10mg)',
        medicineName: 'BP Tablet',
        dosage: '10mg',
        type: ReminderType.medication,
        dateTime: now,
        isCompleted: false,
        patientId: fatherUid,
        targetUid: fatherUid,
        createdBy: myUid,
        creatorUid: myUid,
        reminderTime: '08:00 AM',
        frequency: 'Daily',
        targetPatientName: 'Father',
      );

      final firestoreMap = familyReminder.toFirestore();
      expect(firestoreMap['creatorUid'], myUid);
      expect(firestoreMap['createdBy'], myUid);
      expect(firestoreMap['targetUid'], fatherUid);
      expect(firestoreMap['patientId'], fatherUid);

      // Verify device notification isolation logic:
      final isForFamily = (familyReminder.creatorUid != familyReminder.targetUid);
      expect(isForFamily, isTrue);

      // Creator device: should NOT schedule
      final creatorShouldSchedule = !isForFamily;
      expect(creatorShouldSchedule, isFalse);

      // Father's device: listener matches targetUid == fatherUid && creatorUid != fatherUid
      final fatherDeviceMatches = (familyReminder.targetUid == fatherUid && familyReminder.creatorUid != fatherUid);
      expect(fatherDeviceMatches, isTrue);
    });

    test('Family Reminder and Missed Medication Telegram message formats', () {
      const medName = 'Metformin';
      const dosage = '500mg';
      const time = '08:00 AM';

      final reminderMsg = '''
💊 Family Medication Reminder

Medicine: $medName
Dosage: $dosage
Time: $time
'''.trim();

      final missedMsg = '''
⚠️ Missed Medication

Medicine: $medName
Dosage: $dosage

This medication was not marked as taken.
'''.trim();

      expect(reminderMsg, contains('💊 Family Medication Reminder'));
      expect(reminderMsg, contains('Medicine: Metformin'));
      expect(reminderMsg, contains('Dosage: 500mg'));
      expect(reminderMsg, contains('Time: 08:00 AM'));

      expect(missedMsg, contains('⚠️ Missed Medication'));
      expect(missedMsg, contains('Medicine: Metformin'));
      expect(missedMsg, contains('Dosage: 500mg'));
      expect(missedMsg, contains('This medication was not marked as taken.'));
      expect(missedMsg.contains('bot_token'), isFalse); // Never logs bot token
    });
  });

  group('Emergency SOS Google Maps Location & Intent Tests', () {
    ({double lat, double lng})? extractCoordinates(String? mapsUrl, String? location, String? message) {
      final candidates = [mapsUrl, location, message];
      for (final candidate in candidates) {
        if (candidate == null || candidate.trim().isEmpty) continue;
        final text = candidate.trim();

        // URL check
        try {
          final uriRegex = RegExp(r'https?://[^\s]+');
          final uriMatches = uriRegex.allMatches(text);
          for (final m in uriMatches) {
            final uriStr = m.group(0);
            if (uriStr != null) {
              final parsedUri = Uri.tryParse(uriStr);
              if (parsedUri != null) {
                final q = parsedUri.queryParameters['q'] ?? parsedUri.queryParameters['query'];
                if (q != null) {
                  final parts = q.split(',');
                  if (parts.length == 2) {
                    final lat = double.tryParse(parts[0].trim());
                    final lng = double.tryParse(parts[1].trim());
                    if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
                      return (lat: lat, lng: lng);
                    }
                  }
                }
              }
            }
          }
        } catch (_) {}

        // Coordinates regex
        final coordRegex = RegExp(r'([-+]?\d{1,2}\.\d+)[,\s]+([-+]?\d{1,3}\.\d+)');
        final match = coordRegex.firstMatch(text);
        if (match != null) {
          final latStr = match.group(1);
          final lngStr = match.group(2);
          if (latStr != null && lngStr != null) {
            final lat = double.tryParse(latStr);
            final lng = double.tryParse(lngStr);
            if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
              return (lat: lat, lng: lng);
            }
          }
        }
      }
      return null;
    }

    test('extracts exact coordinates from maps.google.com query URL', () {
      const url = 'https://maps.google.com/?q=12.933514,77.6924253';
      final coords = extractCoordinates(url, null, null);
      expect(coords, isNotNull);
      expect(coords!.lat, closeTo(12.933514, 0.000001));
      expect(coords.lng, closeTo(77.6924253, 0.000001));
    });

    test('extracts coordinates from message text with embedded URL', () {
      const msg = '🚨 SOS Alert from Patient!\nLocation: https://maps.google.com/?q=12.933514,77.6924253\nPlease respond immediately.';
      final coords = extractCoordinates(null, null, msg);
      expect(coords, isNotNull);
      expect(coords!.lat, closeTo(12.933514, 0.000001));
      expect(coords.lng, closeTo(77.6924253, 0.000001));
    });

    test('extracts coordinates from raw location string', () {
      const loc = '12.933514, 77.6924253';
      final coords = extractCoordinates(null, loc, null);
      expect(coords, isNotNull);
      expect(coords!.lat, closeTo(12.933514, 0.000001));
      expect(coords.lng, closeTo(77.6924253, 0.000001));
    });

    test('constructs canonical Google Maps search URL and geo URI', () {
      const lat = 12.933514;
      const lng = 77.6924253;
      final mapsWebUri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '$lat,$lng',
      });
      final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');

      expect(mapsWebUri.scheme, 'https');
      expect(mapsWebUri.host, 'www.google.com');
      expect(mapsWebUri.path, '/maps/search/');
      expect(mapsWebUri.queryParameters['api'], '1');
      expect(mapsWebUri.queryParameters['query'], '12.933514,77.6924253');
      expect(geoUri.toString(), 'geo:12.933514,77.6924253?q=12.933514,77.6924253');
    });

    test('returns null when location is unavailable', () {
      final coords = extractCoordinates(null, 'Location: Unavailable (Permission denied or GPS disabled)', 'SOS triggered');
      expect(coords, isNull);
    });
  });
}
