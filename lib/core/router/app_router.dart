import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/providers.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/patient/dashboard/screens/patient_dashboard_screen.dart';
import '../../features/patient/schedule/screens/patient_schedule_screen.dart';
import '../../features/patient/profile/screens/patient_profile_screen.dart';
import '../../features/patient/family/screens/family_tree_screen.dart';
import '../../features/patient/family/screens/family_member_detail_screen.dart';
import '../../features/patient/dashboard/screens/doctor_search_screen.dart';
import '../../features/patient/dashboard/screens/doctor_detail_screen.dart';
import '../../features/patient/schedule/screens/book_appointment_screen.dart';
import '../../features/patient/ai/screens/ai_chat_screen.dart';
import '../../features/patient/patient_shell.dart';
import '../../features/doctor/doctor_shell.dart';
import '../../features/doctor/dashboard/screens/doctor_dashboard_screen.dart';
import '../../features/doctor/calendar/screens/doctor_calendar_screen.dart';
import '../../features/doctor/patients/screens/doctor_patients_screen.dart';
import '../../features/doctor/patients/screens/patient_detail_screen.dart';
import '../../features/doctor/patients/screens/scan_qr_screen.dart';
import '../../features/doctor/profile/screens/doctor_profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isLogin = state.matchedLocation == '/login';
      final isRoleSelect = state.matchedLocation == '/role-select';

      if (!isAuth) {
        if (!isLogin && !isRoleSelect) return '/login';
        return null;
      }

      if (isLogin) {
        if (authState.user?.role == UserRole.doctor) return '/doctor/dashboard';
        return '/patient/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/role-select',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return PatientShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/dashboard',
                builder: (context, state) => const PatientDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'doctor-search',
                    builder: (context, state) => const DoctorSearchScreen(),
                  ),
                  GoRoute(
                    path: 'doctor/:id',
                    builder: (context, state) => DoctorDetailScreen(doctorId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'ai-chat',
                    builder: (context, state) => const AIChatScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/schedule',
                builder: (context, state) => const PatientScheduleScreen(),
                routes: [
                  GoRoute(
                    path: 'book/:doctorId',
                    builder: (context, state) => BookAppointmentScreen(doctorId: state.pathParameters['doctorId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/family',
                builder: (context, state) => const FamilyTreeScreen(),
                routes: [
                  GoRoute(
                    path: 'family-member/:id',
                    builder: (context, state) => FamilyMemberDetailScreen(memberId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/profile',
                builder: (context, state) => const PatientProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'family-tree',
                    builder: (context, state) => const FamilyTreeScreen(),
                    routes: [
                      GoRoute(
                        path: 'family-member/:id',
                        builder: (context, state) => FamilyMemberDetailScreen(memberId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DoctorShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/doctor/dashboard',
                builder: (context, state) => const DoctorDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/doctor/calendar',
                builder: (context, state) => const DoctorCalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/doctor/patients',
                builder: (context, state) => const DoctorPatientsScreen(),
                routes: [
                  GoRoute(
                    path: 'patient/:id',
                    builder: (context, state) => PatientDetailScreen(patientId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'scan-qr',
                    builder: (context, state) => const ScanQrScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/doctor/profile',
                builder: (context, state) => const DoctorProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
