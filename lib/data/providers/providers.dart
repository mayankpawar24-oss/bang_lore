import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/doctor_model.dart';
import '../models/patient_model.dart';
import '../models/appointment_model.dart';
import '../models/medication_model.dart';
import '../models/reminder_model.dart';
import '../models/family_member_model.dart';
import '../models/notification_model.dart';
import '../models/permission_request_model.dart';
import '../models/vital_model.dart';
import '../models/ai_chat_model.dart';
import '../models/report_model.dart';

import '../repositories/auth_repository.dart';
import '../repositories/doctor_repository.dart';
import '../repositories/patient_repository.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/medication_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/vital_repository.dart';
import '../repositories/permission_repository.dart';
import '../repositories/ai_chat_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/ai_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/telegram_repository.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';
import '../services/proton_drive_service.dart';
import '../services/ocr_service.dart';
import '../services/awesome_notification_service.dart';
import '../services/multi_agent_service.dart';
import '../services/backend_service.dart';

// ════════════════════════════════════════════
// FIREBASE SINGLETON PROVIDERS
// ════════════════════════════════════════════

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// ════════════════════════════════════════════
// THEME
// ════════════════════════════════════════════

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);
  void toggleTheme() => state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  void setTheme(ThemeMode mode) => state = mode;
}

// ════════════════════════════════════════════
// REPOSITORIES
// ════════════════════════════════════════════

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) {
  return FirebaseDoctorRepository();
});

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return FirebasePatientRepository();
});

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return FirebaseAppointmentRepository();
});

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  return FirebaseMedicationRepository();
});

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return FirebaseReminderRepository();
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FirebaseFamilyRepository();
});

final vitalRepositoryProvider = Provider<FirebaseVitalRepository>((ref) {
  return FirebaseVitalRepository();
});

final permissionRepositoryProvider = Provider<FirebasePermissionRepository>((ref) {
  return FirebasePermissionRepository();
});

final aiChatRepositoryProvider = Provider<FirebaseAIChatRepository>((ref) {
  return FirebaseAIChatRepository();
});

final notificationRepositoryProvider = Provider<FirebaseNotificationRepository>((ref) {
  return FirebaseNotificationRepository();
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return FirebaseReportRepository();
});

final telegramRepositoryProvider = Provider<TelegramRepository>((ref) {
  return FirebaseTelegramRepository();
});

final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService();
});

final activityLogServiceProvider = Provider<ActivityLogService>((ref) {
  return ActivityLogService();
});

final protonDriveServiceProvider = Provider<ProtonDriveService>((ref) {
  return ProtonDriveService();
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

final awesomeNotificationServiceProvider = Provider<AwesomeNotificationService>((ref) {
  return AwesomeNotificationService();
});

final activityLogsStreamProvider = StreamProvider.family<List<ActivityLogModel>, String>((ref, patientId) {
  return ref.watch(activityLogServiceProvider).streamLogs(patientId);
});

// Keep AI mock for local development
final aiRepositoryProvider = Provider<MockAIRepository>((ref) => MockAIRepository());
final multiAgentServiceProvider = Provider<MultiAgentService>((ref) => MultiAgentService());

// ════════════════════════════════════════════
// AUTHENTICATION — FIREBASE STREAM
// ════════════════════════════════════════════

/// Realtime Firebase auth state stream
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return ref.read(firebaseAuthProvider).authStateChanges();
});

/// Current UserModel loaded from Firestore after auth
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  return ref.read(authRepositoryProvider).authStateChanges;
});

/// Convenience provider for the current user's UID
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(firebaseAuthStateProvider).valueOrNull?.uid ?? ref.watch(firebaseAuthProvider).currentUser?.uid;
});

/// Auth state (keeps backward compatibility for router)
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final UserModel? user;
  final AuthStatus status;
  final String? error;

  const AuthState({
    this.user,
    this.status = AuthStatus.initial,
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading || status == AuthStatus.initial;

  AuthState copyWith({
    UserModel? user,
    AuthStatus? status,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      status: status ?? this.status,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthNotifier(this._ref) : super(const AuthState()) {
    _ref.listen(currentUserProvider, (_, next) {
      next.when(
        data: (user) {
          if (user != null) {
            dev.log('[AUTH NOTIFIER] User authenticated: ${user.id} (${user.email}) role=${user.role.name}', name: 'AuthNotifier');
            state = AuthState(
              user: user,
              status: AuthStatus.authenticated,
            );
          } else {
            dev.log('[AUTH NOTIFIER] User unauthenticated', name: 'AuthNotifier');
            state = const AuthState(
              user: null,
              status: AuthStatus.unauthenticated,
            );
          }
        },
        loading: () {
          dev.log('[AUTH NOTIFIER] Auth state loading...', name: 'AuthNotifier');
          state = AuthState(
            user: state.user,
            status: AuthStatus.loading,
          );
        },
        error: (e, st) {
          dev.log('[AUTH NOTIFIER ERROR] Auth state error: $e', name: 'AuthNotifier', error: e, stackTrace: st);
          state = AuthState(
            user: null,
            status: AuthStatus.error,
            error: e.toString(),
          );
        },
      );
    });
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _ref.read(authRepositoryProvider).login(email, password);
      state = AuthState(user: user, status: AuthStatus.authenticated);
    } on FirebaseAuthException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _authError(e.code));
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> register(
      String name, String email, String password, UserRole role) async {
    return registerUser(
      name: name,
      password: password,
      phoneNumber: '9876543210',
      role: role,
      email: email,
    );
  }

  Future<void> registerUser({
    required String name,
    required String password,
    required String phoneNumber,
    required UserRole role,
    String? email,
    String? abhaId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _ref.read(authRepositoryProvider).registerUser(
        name: name,
        password: password,
        phoneNumber: phoneNumber,
        role: role,
        email: email,
        abhaId: abhaId,
      );
      state = AuthState(user: user, status: AuthStatus.authenticated);
    } on FirebaseAuthException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _authError(e.code));
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> loginAsPatient() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _ref.read(authRepositoryProvider).loginAsPatient();
      state = AuthState(user: user, status: AuthStatus.authenticated);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> loginAsDoctor() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _ref.read(authRepositoryProvider).loginAsDoctor();
      state = AuthState(user: user, status: AuthStatus.authenticated);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> logout() async {
    dev.log('[AUTH] logout started', name: 'AuthNotifier');
    state = state.copyWith(status: AuthStatus.loading);
    await _ref.read(authRepositoryProvider).logout();
    _ref.invalidate(currentUidProvider);
    _ref.invalidate(currentUserProvider);
    _ref.invalidate(currentPatientStreamProvider);
    _ref.invalidate(currentDoctorStreamProvider);
    _ref.invalidate(appointmentsStreamProvider);
    _ref.invalidate(doctorAppointmentsStreamProvider);
    _ref.invalidate(patientsProvider);
    _ref.invalidate(vitalsStreamProvider);
    _ref.invalidate(medicationsStreamProvider);
    _ref.invalidate(reportsStreamProvider);
    _ref.invalidate(notificationsStreamProvider);
    _ref.invalidate(telegramStatusStreamProvider);
    state = const AuthState(user: null, status: AuthStatus.unauthenticated);
    dev.log('[AUTH] logout completed: currentUser is null, state reset to unauthenticated', name: 'AuthNotifier');
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }
}

// ════════════════════════════════════════════
// PATIENT REALTIME STREAMS
// ════════════════════════════════════════════

/// Stream of the current patient's profile
final currentPatientStreamProvider = StreamProvider<Patient?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.read(patientRepositoryProvider).patientStream(uid);
});

/// Stream of the current doctor's profile
final currentDoctorStreamProvider = StreamProvider<Doctor?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.read(doctorRepositoryProvider).doctorStream(uid);
});

/// Stream of current patient's medications
final medicationsStreamProvider = StreamProvider<List<Medication>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(medicationRepositoryProvider).medicationsStream(uid);
});

/// Stream of current patient's appointments
final appointmentsStreamProvider = StreamProvider<List<Appointment>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(appointmentRepositoryProvider).appointmentsStream(uid);
});

/// Stream of current patient's reminders
final remindersStreamProvider = StreamProvider<List<Reminder>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(reminderRepositoryProvider).remindersStream(uid);
});

/// Stream of current patient's family members
final familyMembersStreamProvider = StreamProvider<List<FamilyMember>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(familyRepositoryProvider).familyMembersStream(uid);
});

/// Stream of current user's vitals
final vitalsStreamProvider = StreamProvider<List<Vital>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(vitalRepositoryProvider).vitalsStream(uid);
});

/// Stream of current user's notifications
final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final uid = ref.watch(currentUidProvider) ?? FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return Stream.value([]);
  final user = ref.watch(currentUserProvider).valueOrNull ?? ref.watch(authProvider).user;
  final isDoctor = user?.role == UserRole.doctor;
  final type = isDoctor ? UserType.doctor : UserType.patient;
  return ref.read(notificationRepositoryProvider).notificationsStream(uid, type);
});

/// Stream of current patient's pending access requests
final pendingPermissionsStreamProvider = StreamProvider<List<AccessPermission>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(patientRepositoryProvider).pendingRequestsStream(uid);
});

/// Doctor: stream of all approved patients
final doctorApprovedPatientsStreamProvider = StreamProvider<List<AccessPermission>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(permissionRepositoryProvider).doctorPermissionsStream(uid);
});

/// Stream of current doctor's appointments
final doctorAppointmentsStreamProvider = StreamProvider<List<Appointment>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(appointmentRepositoryProvider).doctorAppointmentsStream(uid);
});

/// Stream of appointments for a specific doctor by ID (used by patient booking screen)
final doctorAppointmentsFamilyStreamProvider = StreamProvider.family<List<Appointment>, String>((ref, doctorId) {
  if (doctorId.isEmpty) return Stream.value([]);
  return ref.read(appointmentRepositoryProvider).doctorAppointmentsStream(doctorId);
});

/// Stream of availability slots for a specific doctor by ID (accessible by patients)
final doctorAvailabilityStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, doctorId) {
  if (doctorId.isEmpty) return Stream.value([]);
  return ref.read(appointmentRepositoryProvider).doctorAvailabilityStream(doctorId);
});

/// Stream of all registered doctors
final doctorsStreamProvider = StreamProvider<List<Doctor>>((ref) {
  return ref.read(doctorRepositoryProvider).doctorsStream();
});

/// Stream of all registered patients for doctor patient discovery
final allPatientsStreamProvider = StreamProvider<List<Patient>>((ref) {
  return ref.read(patientRepositoryProvider).patientsStream();
});

/// Real patients associated with this doctor through appointments or approved access permissions
final doctorAssociatedPatientsStreamProvider = StreamProvider<List<PatientModel>>((ref) {
  final currentUid = FirebaseAuth.instance.currentUser?.uid ?? ref.watch(currentUidProvider);
  if (currentUid == null || currentUid.isEmpty) return Stream.value([]);

  final db = FirebaseFirestore.instance;

  return db
      .collection('appointments')
      .where('doctorId', isEqualTo: currentUid)
      .snapshots()
      .asyncMap((apptSnap) async {
        final patientMap = <String, PatientModel>{};

        // 1. Collect from appointments
        for (final doc in apptSnap.docs) {
          final data = doc.data();
          final pId = data['patientId'] as String? ?? '';
          final pName = data['patientName'] as String? ?? 'Patient';
          final specialty = data['specialty'] as String? ?? 'General Care';
          final status = data['status'] as String? ?? 'pending';
          if (pId.isNotEmpty && !patientMap.containsKey(pId)) {
            patientMap[pId] = PatientModel(
              id: pId,
              name: pName,
              age: 32,
              condition: specialty,
              status: status == 'approved' ? 'stable' : 'attention',
              isAuthorized: false,
              conditions: [specialty],
              medicationAdherence: 0.95,
            );
          }
        }

        // 2. Collect from approved access permissions
        try {
          final permSnap = await db
              .collection('accessPermissions')
              .where('doctorId', isEqualTo: currentUid)
              .get();

          for (final pDoc in permSnap.docs) {
            final pData = pDoc.data();
            final pId = pData['patientId'] as String? ?? '';
            final pName = pData['patientName'] as String? ?? 'Patient';
            final isApproved = pData['status'] == 'approved';

            if (pId.isNotEmpty) {
              if (isApproved) {
                try {
                  final pProfileDoc = await db.collection('patients').doc(pId).get();
                  if (pProfileDoc.exists) {
                    final profile = PatientModel.fromFirestore(pProfileDoc).copyWith(isAuthorized: true);
                    patientMap[pId] = profile;
                    continue;
                  }
                } catch (e) {
                  dev.log('[DOCTOR PATIENT] Profile fetch note: $e', name: 'doctorAssociatedPatientsStreamProvider');
                }
              }

              if (patientMap.containsKey(pId)) {
                patientMap[pId] = patientMap[pId]!.copyWith(isAuthorized: isApproved);
              } else {
                patientMap[pId] = PatientModel(
                  id: pId,
                  name: pName,
                  age: 30,
                  condition: 'Consultation Patient',
                  status: isApproved ? 'stable' : 'attention',
                  isAuthorized: isApproved,
                  conditions: const ['Consultation Patient'],
                  medicationAdherence: 0.95,
                );
              }
            }
          }
        } catch (e) {
          dev.log('[DOCTOR PATIENT] Access permissions check note: $e', name: 'doctorAssociatedPatientsStreamProvider');
        }

        return patientMap.values.toList();
      });
});

/// Stream of current patient's AI chats
final aiChatsStreamProvider = StreamProvider<List<AIChat>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(aiChatRepositoryProvider).chatsStream(uid);
});

/// Stream of a specific patient's AI chats (used by doctor with 'aiChat' permission)
final patientAiChatsFamilyStreamProvider = StreamProvider.family<List<AIChat>, String>((ref, patientId) {
  if (patientId.isEmpty) return Stream.value([]);
  return ref.read(aiChatRepositoryProvider).chatsStream(patientId);
});

/// Stream of messages for a specific patient's chat session
final patientChatMessagesFamilyStreamProvider = StreamProvider.family<List<AIChatMessage>, ({String patientId, String chatId})>((ref, arg) {
  if (arg.patientId.isEmpty || arg.chatId.isEmpty) return Stream.value([]);
  return ref.read(aiChatRepositoryProvider).messagesStream(arg.patientId, arg.chatId);
});

/// Stream of a specific patient's profile
final patientStreamProvider = StreamProvider.family<Patient?, String>((ref, patientId) {
  return ref.read(patientRepositoryProvider).patientStream(patientId);
});

/// Stream of a specific patient's access permission for current doctor
final patientPermissionStreamProvider = StreamProvider.family<AccessPermission?, String>((ref, patientId) {
  final docUid = ref.watch(currentUidProvider);
  if (docUid == null) return Stream.value(null);
  return ref.read(permissionRepositoryProvider).permissionStream(docUid, patientId);
});

/// Stream of all access permissions for current patient
final patientAllPermissionsStreamProvider = StreamProvider<List<AccessPermission>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(permissionRepositoryProvider).patientPermissionsStream(uid);
});

/// Stream of a specific patient's vitals
final patientVitalsStreamProvider = StreamProvider.family<List<Vital>, String>((ref, patientId) {
  return ref.read(vitalRepositoryProvider).vitalsStream(patientId);
});

/// Stream of a specific patient's medications
final patientMedicationsStreamProvider = StreamProvider.family<List<Medication>, String>((ref, patientId) {
  return ref.read(medicationRepositoryProvider).medicationsStream(patientId);
});

/// Stream of current patient's uploaded health reports & documents
final reportsStreamProvider = StreamProvider<List<ReportModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(reportRepositoryProvider).reportsStream(uid);
});

/// Stream of health reports for a specific patient by ID (doctor view)
final patientReportsFamilyStreamProvider = StreamProvider.family<List<ReportModel>, String>((ref, patientId) {
  if (patientId.isEmpty) return Stream.value([]);
  return ref.read(reportRepositoryProvider).reportsStream(patientId);
});

/// Stream of current authenticated user's Telegram connection status
final telegramStatusStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value({'connected': false, 'chatId': null});
  }
  return ref.read(telegramRepositoryProvider).telegramStatusStream(uid);
});

// ════════════════════════════════════════════
// LEGACY STATENOTIFIER PROVIDERS
// (kept for screens that haven't been updated yet)
// ════════════════════════════════════════════

final doctorsProvider = StateNotifierProvider<DoctorsNotifier, List<Doctor>>((ref) {
  return DoctorsNotifier(ref.read(doctorRepositoryProvider));
});

class DoctorsNotifier extends StateNotifier<List<Doctor>> {
  final DoctorRepository _repository;
  DoctorsNotifier(this._repository) : super([]) {
    loadDoctors();
  }

  Future<void> loadDoctors() async {
    try {
      state = await _repository.getDoctors();
    } catch (_) {
      state = [];
    }
  }

  Future<void> searchDoctors(String query) async {
    if (query.isEmpty) {
      state = await _repository.getDoctors();
      return;
    }
    state = await _repository.searchDoctors(query);
  }
}

final medicationsProvider = StateNotifierProvider<MedicationsNotifier, List<Medication>>((ref) {
  return MedicationsNotifier(ref.read(medicationRepositoryProvider));
});

class MedicationsNotifier extends StateNotifier<List<Medication>> {
  final MedicationRepository _repository;
  String? _currentPatientId;
  MedicationsNotifier(this._repository) : super([]);

  Future<void> loadMedications(String patientId) async {
    _currentPatientId = patientId;
    try {
      state = await _repository.getMedications(patientId);
    } catch (_) {
      state = [];
    }
  }

  Future<void> markAsTaken(String medicationId) async {
    state = state.map((m) {
      if (m.id == medicationId) return m.copyWith(isTaken: true);
      return m;
    }).toList();
    if (_currentPatientId != null) {
      await _repository.markTaken(_currentPatientId!, medicationId);
    }
  }

  double getAdherence() {
    if (state.isEmpty) return 0.0;
    return state.where((m) => m.isTaken).length / state.length * 100;
  }
}

final appointmentsProvider = StateNotifierProvider<AppointmentsNotifier, List<Appointment>>((ref) {
  return AppointmentsNotifier(ref.read(appointmentRepositoryProvider));
});

class AppointmentsNotifier extends StateNotifier<List<Appointment>> {
  final AppointmentRepository _repository;
  AppointmentsNotifier(this._repository) : super([]);

  Future<void> loadAppointments(String userId) async {
    try {
      state = await _repository.getAppointments(userId);
    } catch (_) {
      state = [];
    }
  }

  Future<void> bookAppointment(Appointment appointment) async {
    await _repository.bookAppointment(appointment);
    state = [...state, appointment];
  }

  Future<void> cancelAppointment(String patientId, String id) async {
    await _repository.cancelAppointment(patientId, id);
    state = state.map((a) {
      if (a.id == id) return a.copyWith(status: AppointmentStatus.cancelled);
      return a;
    }).toList();
  }
}

final remindersProvider = StateNotifierProvider<RemindersNotifier, List<Reminder>>((ref) {
  return RemindersNotifier(ref.read(reminderRepositoryProvider), ref);
});

class RemindersNotifier extends StateNotifier<List<Reminder>> {
  final ReminderRepository _repository;
  final Ref _ref;
  String? _currentPatientId;

  RemindersNotifier(this._repository, this._ref) : super([]);

  String? get _effectivePatientId => _currentPatientId ?? _ref.read(currentUidProvider);

  Future<void> loadReminders(String userId) async {
    _currentPatientId = userId;
    try {
      state = await _repository.getReminders(userId);
    } catch (_) {
      state = [];
    }
  }

  Future<void> addReminder(Reminder reminder) async {
    state = [...state, reminder];
    final targetUid = _effectivePatientId;
    if (targetUid != null) {
      await _repository.addReminder(targetUid, reminder);
    }
  }

  Future<void> completeReminder(String id) async {
    state = state.map((r) {
      if (r.id == id) return r.copyWith(isCompleted: true);
      return r;
    }).toList();
    final targetUid = _effectivePatientId;
    if (targetUid != null) {
      await _repository.completeReminder(targetUid, id);
    }
  }

  Future<void> deleteReminder(String id) async {
    state = state.where((r) => r.id != id).toList();
    final targetUid = _effectivePatientId;
    if (targetUid != null) {
      await _repository.deleteReminder(targetUid, id);
    }
  }

  Future<void> toggleReminder(String id) async {
    final rem = state.firstWhere((r) => r.id == id, orElse: () => state.first);
    if (rem.isCompleted) {
      state = state.map((r) => r.id == id ? r.copyWith(isCompleted: false) : r).toList();
    } else {
      await completeReminder(id);
    }
  }

  Future<void> updateReminder(Reminder reminder) async {
    state = state.map((r) => r.id == reminder.id ? reminder : r).toList();
    final targetUid = _effectivePatientId;
    if (targetUid != null) {
      await _repository.updateReminder(targetUid, reminder);
    }
  }
}

final familyMembersProvider = StateNotifierProvider<FamilyMembersNotifier, List<FamilyMember>>((ref) {
  return FamilyMembersNotifier(ref.read(familyRepositoryProvider), ref);
});

class FamilyMembersNotifier extends StateNotifier<List<FamilyMember>> {
  final FamilyRepository _repository;
  final Ref _ref;
  String? _currentPatientId;

  FamilyMembersNotifier(this._repository, this._ref) : super([]);

  String? get _effectivePatientId => _currentPatientId ?? _ref.read(currentUidProvider);

  Future<void> loadFamilyMembers(String patientId) async {
    _currentPatientId = patientId;
    try {
      state = await _repository.getFamilyMembers(patientId);
    } catch (_) {
      state = [];
    }
  }

  Future<void> addMember(FamilyMember member) async {
    final targetUid = _effectivePatientId;
    if (targetUid != null) {
      final saved = await _repository.addFamilyMember(targetUid, member);
      state = [...state.where((m) => m.id != saved.id), saved];
    } else {
      state = [...state, member];
    }
  }

  Future<void> updateMember(FamilyMember member) async {
    state = state.map((m) => m.id == member.id ? member : m).toList();
    final targetUid = _effectivePatientId;
    if (targetUid != null) {
      await _repository.updateFamilyMember(targetUid, member);
    }
  }

  Future<void> deleteMember(String id) async {
    state = state.where((m) => m.id != id).toList();
    final targetUid = _effectivePatientId;
    if (targetUid != null) {
      await _repository.deleteFamilyMember(targetUid, id);
    }
  }

  Future<void> updateCareTaskStatus(String memberId, String taskId, CareTaskStatus newStatus) async {
    state = state.map((member) {
      if (member.id == memberId) {
        final updatedTasks = member.careTasks.map((task) {
          if (task.id == taskId) return task.copyWith(status: newStatus);
          return task;
        }).toList();
        final updated = member.copyWith(careTasks: updatedTasks);
        final targetUid = _effectivePatientId;
        if (targetUid != null) {
          _repository.updateFamilyMember(targetUid, updated);
        }
        return updated;
      }
      return member;
    }).toList();
  }
}

final patientsProvider = StateNotifierProvider<PatientsNotifier, List<Patient>>((ref) {
  return PatientsNotifier(ref.read(patientRepositoryProvider));
});

class PatientsNotifier extends StateNotifier<List<Patient>> {
  final PatientRepository _repository;
  PatientsNotifier(this._repository) : super([]) {
    loadPatients();
  }

  Future<void> loadPatients() async {
    try {
      state = await _repository.getPatients();
    } catch (_) {
      state = [];
    }
  }

  Future<void> searchPatients(String query) async {
    if (query.isEmpty) {
      state = await _repository.getPatients();
      return;
    }
    state = await _repository.searchPatients(query);
  }

  Future<void> authorizeDoctor(String patientId) async {
    state = state.map((p) {
      if (p.id == patientId) return p.copyWith(isAuthorized: true);
      return p;
    }).toList();
  }
}

final permissionRequestsProvider =
    StateNotifierProvider<PermissionRequestsNotifier, List<AccessPermission>>((ref) {
  return PermissionRequestsNotifier(ref);
});

class PermissionRequestsNotifier extends StateNotifier<List<AccessPermission>> {
  final Ref _ref;
  PermissionRequestsNotifier(this._ref) : super([]);

  Future<void> addRequest(AccessPermission request) async {
    state = [...state, request];
  }

  Future<void> approveRequest(String requestId, {List<String>? permissions}) async {
    await _ref
        .read(patientRepositoryProvider)
        .approveAccess(requestId, permissions: permissions);
    state = state.map((r) {
      if (r.id == requestId) return r.copyWith(status: PermissionStatus.approved);
      return r;
    }).toList();
  }

  Future<void> denyRequest(String requestId) async {
    await _ref.read(patientRepositoryProvider).denyAccess(requestId);
    state = state.map((r) {
      if (r.id == requestId) return r.copyWith(status: PermissionStatus.denied);
      return r;
    }).toList();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>((ref) {
  return NotificationsNotifier(ref);
});

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  final Ref _ref;
  NotificationsNotifier(this._ref) : super([]);

  void setNotifications(List<NotificationModel> notifs) {
    state = notifs;
  }

  Future<void> markAsRead(String id) async {
    state = state.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();

    final uid = _ref.read(currentUidProvider);
    final user = _ref.read(authProvider).user;
    if (uid != null && user != null) {
      final type = user.role == UserRole.patient ? UserType.patient : UserType.doctor;
      await _ref.read(notificationRepositoryProvider).markAsRead(uid, type, id);
    }
  }

  void addNotification(NotificationModel notification) {
    state = [notification, ...state];
  }
}

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<AIChatMessage>>((ref) {
  return ChatMessagesNotifier(ref);
});

class ChatMessagesNotifier extends StateNotifier<List<AIChatMessage>> {
  final Ref _ref;
  String? _currentChatId;

  ChatMessagesNotifier(this._ref) : super([]);

  Future<void> sendMessage(String content, {String? chatId}) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    final userMsg = AIChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId ?? _currentChatId ?? '',
      sender: AIChatSender.user,
      content: content,
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];

    try {
      final backend = _ref.read(backendServiceProvider);
      final response = await backend.sendAIMessage(
        message: content,
        chatId: chatId ?? _currentChatId,
      );

      // If no chatId yet, use the one from the response
      if (_currentChatId == null && response.chatId != null) {
        _currentChatId = response.chatId;
      }

      final aiMsg = AIChatMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        chatId: _currentChatId ?? '',
        sender: AIChatSender.assistant,
        content: response.answer,
        timestamp: DateTime.now(),
        metadata: {
          'confidence': response.confidence,
          'recommendedAction': response.recommendedAction,
          'safetyNote': response.safetyNote,
        },
      );
      state = [...state, aiMsg];
    } catch (e) {
      // Fallback to mock if backend is unavailable
      final fallbackMsg = AIChatMessage(
        id: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
        chatId: _currentChatId ?? '',
        sender: AIChatSender.assistant,
        content: _fallbackResponse(content),
        timestamp: DateTime.now(),
      );
      state = [...state, fallbackMsg];
    }
  }

  String _fallbackResponse(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('medicine') || lower.contains('medication')) {
      return 'Based on your records, please check your medication schedule. '
          'If you have concerns, consult your doctor. (Offline mode)';
    } else if (lower.contains('appointment')) {
      return 'Please check your calendar for upcoming appointments. '
          'The AI assistant requires internet connection for personalized responses.';
    }
    return 'I am currently unable to connect to the AI service. '
        'Please ensure the backend is running and you have internet access. '
        'For medical emergencies, call emergency services immediately.';
  }

  void clearMessages() => state = [];
  void setCurrentChatId(String id) => _currentChatId = id;
}
