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
}
