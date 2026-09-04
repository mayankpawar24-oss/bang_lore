import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/providers.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/intro/screens/app_opening_screen.dart';
import '../../features/patient/dashboard/screens/patient_dashboard_screen.dart';
import '../../features/patient/schedule/screens/patient_schedule_screen.dart';
import '../../features/patient/profile/screens/patient_profile_screen.dart';
import '../../features/patient/family/screens/family_tree_screen.dart';
import '../../features/patient/family/screens/family_member_detail_screen.dart';
import '../../features/patient/dashboard/screens/doctor_search_screen.dart';
import '../../features/patient/dashboard/screens/doctor_detail_screen.dart';
import '../../features/patient/dashboard/screens/doctor_chat_screen.dart';
import '../../features/patient/schedule/screens/book_appointment_screen.dart';
import '../../features/patient/ai/screens/ai_chat_screen.dart';
import '../../features/patient/timeline/screens/patient_timeline_screen.dart';
import '../../features/patient/followup/screens/followup_center_screen.dart';
import '../../features/patient/dashboard/screens/twin_center_screen.dart';
import '../../features/patient/patient_shell.dart';
import '../../features/doctor/doctor_shell.dart';
import '../../features/doctor/dashboard/screens/doctor_dashboard_screen.dart';
import '../../features/doctor/calendar/screens/doctor_calendar_screen.dart';
import '../../features/doctor/patients/screens/doctor_patients_screen.dart';
import '../../features/doctor/patients/screens/patient_detail_screen.dart';
import '../../features/doctor/patients/screens/scan_qr_screen.dart';
import '../../features/doctor/profile/screens/doctor_profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch Firebase auth state stream for realtime auth changes
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/intro',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isIntro = loc == '/intro';
      final isPublicRoute = isIntro ||
          loc == '/login' ||
          loc == '/role-select' ||
          loc == '/register';

      dev.log('[ROUTER REDIRECT] Evaluating loc="$loc", status=${authState.status.name}, isAuth=${authState.isAuthenticated}, user=${authState.user?.email}, role=${authState.user?.role.name}', name: 'GoRouter');

      // 1. While loading (initial auth check, Firebase initializing, or role fetching), do NOT redirect anywhere
      if (authState.isLoading) {
        dev.log('[ROUTER REDIRECT] Auth loading -> return null', name: 'GoRouter');
        return null;
      }

      // 2. If in error state (e.g. invalid user doc / network error), stay on public route if there, or redirect to /login
      if (authState.status == AuthStatus.error) {
        dev.log('[ROUTER REDIRECT] Auth error -> ${isPublicRoute ? "stay on public route" : "redirect /login"}', name: 'GoRouter');
        if (!isPublicRoute) return '/login';
        return null;
      }

      // 3. Unauthenticated -> force login page if on private page
      if (!authState.isAuthenticated) {
        if (!isPublicRoute) {
          dev.log('[ROUTER] redirect after logout to /login (loc="$loc")', name: 'GoRouter');
          return '/login';
        }
        return null;
      }

      // 4. Authenticated -> route to proper dashboard if on public page (except intro)
      final role = authState.user?.role;
      if (isPublicRoute && !isIntro) {
        final target = role == UserRole.doctor ? '/doctor/dashboard' : '/patient/dashboard';
        dev.log('[ROUTER REDIRECT] Authenticated on public route "$loc" -> redirect $target (role: ${role?.name})', name: 'GoRouter');
        return target;
      }

      // 5. Role protection
      if (role == UserRole.doctor && loc.startsWith('/patient')) {
        dev.log('[ROUTER REDIRECT] Doctor on patient route -> redirect /doctor/dashboard', name: 'GoRouter');
        return '/doctor/dashboard';
      }
      if (role == UserRole.patient && loc.startsWith('/doctor')) {
        dev.log('[ROUTER REDIRECT] Patient on doctor route -> redirect /patient/dashboard', name: 'GoRouter');
        return '/patient/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/intro',
        builder: (context, state) => const AppOpeningScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/role-select',
        builder: (context, state) => const RoleSelectionScreen(),
      ),

      // ── PATIENT SHELL ──────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return PatientShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: HOME
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
                    builder: (context, state) =>
                        DoctorDetailScreen(doctorId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'doctor-chat/:doctorId',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return DoctorChatScreen(
                        doctorId: state.pathParameters['doctorId']!,
                        doctorName: extra?['doctorName'] as String?,
                        doctorSpecialty: extra?['doctorSpecialty'] as String?,
                        doctorAvatar: extra?['doctorAvatar'] as String?,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'followups',
                    builder: (context, state) => const FollowUpCenterScreen(),
                  ),
                  GoRoute(
                    path: 'twin',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      final patientId = extra?['patientId'] as String? ?? 'dev-patient-alex';
                      return TwinCenterScreen(patientId: patientId);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/patient/followups',
                builder: (context, state) => const FollowUpCenterScreen(),
              ),
              GoRoute(
                path: '/patient/twin',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  final patientId = extra?['patientId'] as String? ?? 'dev-patient-alex';
                  return TwinCenterScreen(patientId: patientId);
                },
              ),
            ],
          ),

          // Branch 1: FAMILY
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/family',
                builder: (context, state) => const FamilyTreeScreen(),
                routes: [
                  GoRoute(
                    path: 'family-member/:id',
                    builder: (context, state) => FamilyMemberDetailScreen(
                        memberId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: AI CARE
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/ai-care',
                builder: (context, state) => const AIChatScreen(),
              ),
              GoRoute(
                path: '/patient/ai-chat',
                builder: (context, state) => const AIChatScreen(),
              ),
            ],
          ),

          // Branch 3: TIMELINE
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/timeline',
                builder: (context, state) => const PatientTimelineScreen(),
                routes: [
                  GoRoute(
                    path: 'schedule',
                    builder: (context, state) => const PatientScheduleScreen(),
                  ),
                  GoRoute(
                    path: 'book/:doctorId',
                    builder: (context, state) => BookAppointmentScreen(
                        doctorId: state.pathParameters['doctorId']!),
                  ),
                ],
              ),
              GoRoute(
                path: '/patient/schedule',
                builder: (context, state) => const PatientScheduleScreen(),
                routes: [
                  GoRoute(
                    path: 'book/:doctorId',
                    builder: (context, state) => BookAppointmentScreen(
                        doctorId: state.pathParameters['doctorId']!),
                  ),
                ],
              ),
            ],
          ),

          // Branch 4: PROFILE
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
                        builder: (context, state) => FamilyMemberDetailScreen(
                            memberId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── DOCTOR SHELL ───────────────────────────────
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
                    builder: (context, state) => PatientDetailScreen(
                        patientId: state.pathParameters['id']!),
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
