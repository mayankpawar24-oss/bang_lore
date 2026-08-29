import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../models/doctor_model.dart';
import '../models/patient_model.dart';
import '../models/appointment_model.dart';
import '../models/medication_model.dart';
import '../models/reminder_model.dart';
import '../models/family_member_model.dart';
import '../models/chat_message_model.dart';
import '../models/notification_model.dart';
import '../models/permission_request_model.dart';

import '../mock/mock_data.dart';
import '../repositories/doctor_repository.dart';
import '../repositories/patient_repository.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/medication_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/ai_repository.dart';
import '../services/multi_agent_service.dart';

// Theme mode state
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);

  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

// Auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

class AuthState {
  final UserModel? user;
  final bool isAuthenticated;
  AuthState({this.user, this.isAuthenticated = false});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  void loginAsPatient() {
    state = AuthState(
      user: const UserModel(
        id: 'p_margaret_01',
        name: 'Margaret Chen',
        email: 'margaret@demo.com',
        role: UserRole.patient,
      ),
      isAuthenticated: true,
    );
  }

  void loginAsDoctor() {
    state = AuthState(
      user: const UserModel(
        id: 'd_aisha_01',
        name: 'Dr. Aisha Patel',
        email: 'aisha@demo.com',
        role: UserRole.doctor,
      ),
      isAuthenticated: true,
    );
  }

  void logout() {
    state = AuthState(user: null, isAuthenticated: false);
  }
}

// Repository providers
final doctorRepositoryProvider = Provider((ref) => MockDoctorRepository());
final patientRepositoryProvider = Provider((ref) => MockPatientRepository());
final appointmentRepositoryProvider = Provider((ref) => MockAppointmentRepository());
final medicationRepositoryProvider = Provider((ref) => MockMedicationRepository());
final reminderRepositoryProvider = Provider((ref) => MockReminderRepository());
final familyRepositoryProvider = Provider((ref) => MockFamilyRepository());
final aiRepositoryProvider = Provider((ref) => MockAIRepository());
final multiAgentServiceProvider = Provider((ref) => MultiAgentService());

// Data providers
final doctorsProvider = StateNotifierProvider<DoctorsNotifier, List<Doctor>>((ref) {
  return DoctorsNotifier(ref.read(doctorRepositoryProvider));
});

class DoctorsNotifier extends StateNotifier<List<Doctor>> {
  final MockDoctorRepository _repository;
  DoctorsNotifier(this._repository) : super([]) {
    loadDoctors();
  }

  Future<void> loadDoctors() async {
    state = await _repository.getDoctors();
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
  final MockMedicationRepository _repository;
  MedicationsNotifier(this._repository) : super([]) {
    loadMedications('patient_1');
  }

  Future<void> loadMedications(String patientId) async {
    state = await _repository.getMedications(patientId);
  }

  Future<void> markAsTaken(String medicationId) async {
    state = state.map((m) {
      if (m.id == medicationId) {
        return m.copyWith(isTaken: true);
      }
      return m;
    }).toList();
  }

  double getAdherence() {
    if (state.isEmpty) return 0.0;
    int takenCount = state.where((m) => m.isTaken).length;
    return takenCount / state.length * 100;
  }
}

final appointmentsProvider = StateNotifierProvider<AppointmentsNotifier, List<Appointment>>((ref) {
  return AppointmentsNotifier(ref.read(appointmentRepositoryProvider));
});

class AppointmentsNotifier extends StateNotifier<List<Appointment>> {
  final MockAppointmentRepository _repository;
  AppointmentsNotifier(this._repository) : super([]) {
    loadAppointments('user_1');
  }

  Future<void> loadAppointments(String userId) async {
    state = await _repository.getAppointments(userId);
  }

  Future<void> bookAppointment(Appointment appointment) async {
    state = [...state, appointment];
  }

  Future<void> cancelAppointment(String id) async {
    state = state.map((a) {
      if (a.id == id) {
        return a.copyWith(status: AppointmentStatus.cancelled);
      }
      return a;
    }).toList();
  }

  Future<void> rescheduleAppointment(String id, DateTime newDateTime) async {
    state = state.map((a) {
      if (a.id == id) {
        return a.copyWith(dateTime: newDateTime);
      }
      return a;
    }).toList();
  }
}

final remindersProvider = StateNotifierProvider<RemindersNotifier, List<Reminder>>((ref) {
  return RemindersNotifier(ref.read(reminderRepositoryProvider));
});

class RemindersNotifier extends StateNotifier<List<Reminder>> {
  final MockReminderRepository _repository;
  RemindersNotifier(this._repository) : super([]) {
    loadReminders('user_1');
  }

  Future<void> loadReminders(String userId) async {
    state = await _repository.getReminders(userId);
  }

  Future<void> addReminder(Reminder reminder) async {
    state = [...state, reminder];
  }

  Future<void> updateReminder(Reminder reminder) async {
    state = state.map((r) => r.id == reminder.id ? reminder : r).toList();
  }

  Future<void> toggleReminder(String id) async {
    state = state.map((r) {
      if (r.id == id) {
        return r.copyWith(isCompleted: !r.isCompleted);
      }
      return r;
    }).toList();
  }

  Future<void> completeReminder(String id) async {
    state = state.map((r) {
      if (r.id == id) {
        return r.copyWith(isCompleted: true);
      }
      return r;
    }).toList();
  }

  Future<void> deleteReminder(String id) async {
    state = state.where((r) => r.id != id).toList();
  }
}

final familyMembersProvider = StateNotifierProvider<FamilyMembersNotifier, List<FamilyMember>>((ref) {
  return FamilyMembersNotifier(ref.read(familyRepositoryProvider));
});

class FamilyMembersNotifier extends StateNotifier<List<FamilyMember>> {
  final MockFamilyRepository _repository;
  FamilyMembersNotifier(this._repository) : super([]) {
    loadFamilyMembers('patient_1');
  }

  Future<void> loadFamilyMembers(String patientId) async {
    state = await _repository.getFamilyMembers(patientId);
  }

  Future<void> addMember(FamilyMember member) async {
    state = [...state, member];
  }

  Future<void> updateMember(FamilyMember member) async {
    state = state.map((m) => m.id == member.id ? member : m).toList();
  }

  Future<void> deleteMember(String id) async {
    state = state.where((m) => m.id != id).toList();
  }

  Future<void> updateCareTaskStatus(String memberId, String taskId, CareTaskStatus newStatus) async {
    state = state.map((member) {
      if (member.id == memberId) {
        final updatedTasks = member.careTasks.map((task) {
          if (task.id == taskId) {
            return task.copyWith(status: newStatus);
          }
          return task;
        }).toList();
        return member.copyWith(careTasks: updatedTasks);
      }
      return member;
    }).toList();
  }
}

final patientsProvider = StateNotifierProvider<PatientsNotifier, List<Patient>>((ref) {
  return PatientsNotifier(ref.read(patientRepositoryProvider));
});

class PatientsNotifier extends StateNotifier<List<Patient>> {
  final MockPatientRepository _repository;
  PatientsNotifier(this._repository) : super([]) {
    loadPatients();
  }

  Future<void> loadPatients() async {
    state = await _repository.getPatients();
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
      if (p.id == patientId) {
        return p.copyWith(isAuthorized: true);
      }
      return p;
    }).toList();
  }
}

final permissionRequestsProvider = StateNotifierProvider<PermissionRequestsNotifier, List<PermissionRequest>>((ref) {
  return PermissionRequestsNotifier(ref);
});

class PermissionRequestsNotifier extends StateNotifier<List<PermissionRequest>> {
  final Ref _ref;
  PermissionRequestsNotifier(this._ref) : super([]);

  Future<void> addRequest(PermissionRequest request) async {
    state = [...state, request];
  }

  Future<void> approveRequest(String requestId) async {
    state = state.map((r) {
      if (r.id == requestId) {
        _ref.read(patientsProvider.notifier).authorizeDoctor(r.patientId);
        return r.copyWith(status: PermissionStatus.approved);
      }
      return r;
    }).toList();
  }

  Future<void> denyRequest(String requestId) async {
    state = state.map((r) {
      if (r.id == requestId) {
        return r.copyWith(status: PermissionStatus.denied);
      }
      return r;
    }).toList();
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>((ref) {
  return NotificationsNotifier();
});

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationsNotifier() : super(MockData.notifications);

  void markAsRead(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
  }

  void addNotification(NotificationModel notification) {
    state = [notification, ...state];
  }
}

final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier(ref.read(aiRepositoryProvider));
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final MockAIRepository _repository;
  ChatMessagesNotifier(this._repository) : super([]);

  Future<void> sendMessage(String content) async {
    final userMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMessage];

    final response = await _repository.sendMessage(content);
    final aiMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_ai',
      content: response,
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = [...state, aiMessage];
  }

  void clearMessages() {
    state = [];
  }
}
