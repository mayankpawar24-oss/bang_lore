import 'dart:async';
import 'dart:developer' as dev;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/doctor_model.dart';
import '../../../../data/models/medication_model.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/vital_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../data/models/reminder_model.dart';
import '../../../../data/models/report_model.dart';
import '../../../../data/services/awesome_notification_service.dart';
import '../../../../data/services/backend_service.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/doctor_card.dart';
import '../../../../core/widgets/medication_card.dart';
import '../../../../core/widgets/appointment_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/notification_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_layout_insets.dart';
import '../widgets/home_action_carousel.dart';
import '../widgets/health_insights_summary_card.dart';
import '../widgets/supporting_insight_cards.dart';
import '../widgets/twin_activity_card.dart';
import '../../../../data/models/twin_state_model.dart';

class PatientDashboardScreen extends ConsumerStatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  ConsumerState<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends ConsumerState<PatientDashboardScreen> {
  StreamSubscription? _familyRemindersSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final uid = ref.read(currentUidProvider);
        if (uid != null && uid.isNotEmpty) {
          ref.read(missedEventsServiceProvider).checkAndProcessMissedEvents(uid);
          _setupTargetRemindersListener(uid);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _familyRemindersSub?.cancel();
    super.dispose();
  }

  /// Listens for family reminders where targetUid == this user, and schedules awesome_notifications on this target device
  void _setupTargetRemindersListener(String uid) {
    _familyRemindersSub?.cancel();
    try {
      _familyRemindersSub = FirebaseFirestore.instance
          .collection('reminders')
          .where('targetUid', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
        for (final doc in snap.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? 'pending';
          final isCompleted = data['isCompleted'] == true || status == 'completed';
          final creatorUid = data['creatorUid'] as String? ?? data['createdBy'] as String?;

          // Only schedule if this reminder was created by another user (family caregiver) for THIS user, and is still pending
          if (!isCompleted && creatorUid != null && creatorUid != uid) {
            final medName = data['medicineName'] as String? ?? data['title'] as String? ?? 'Medication';
            final dosage = data['dosage'] as String? ?? '1 dose';
            final dateTimeTs = data['dateTime'] as Timestamp?;
            final scheduledTime = dateTimeTs?.toDate() ?? DateTime.now();
            final reminderId = doc.id;
            final timeDisplay = data['reminderTime'] as String? ?? '';

            dev.log('''
[FAMILY_NOTIFICATION]
creatorUid = $creatorUid
targetUid = $uid
patientId = $uid
reminderId = $reminderId
reminderTime = $timeDisplay
'''.trim(), name: 'FamilyReminder');

            AwesomeNotificationService.scheduleMedicationReminder(
              id: reminderId.hashCode,
              medicineName: medName,
              dosage: dosage,
              scheduledTime: scheduledTime,
              medicationId: reminderId,
            );
          }
        }
      }, onError: (e) {
        dev.log('[FAMILY_NOTIFICATION ERROR] $e', name: 'FamilyReminder');
      });
    } catch (e) {
      dev.log('[FAMILY_NOTIFICATION SETUP ERROR] $e', name: 'FamilyReminder');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = ref.watch(currentUidProvider);

    // Watch real-time Firestore stream providers
    final streamAppts = ref.watch(appointmentsStreamProvider).valueOrNull ?? [];
    final streamMeds = ref.watch(medicationsStreamProvider).valueOrNull ?? [];
    final streamVitals = ref.watch(vitalsStreamProvider).valueOrNull ?? [];
    final streamReports = ref.watch(reportsStreamProvider).valueOrNull ?? [];
    final List<DoctorModel> doctors = ref.watch(doctorsStreamProvider).valueOrNull ?? [];
    final notifications = ref.watch(notificationsStreamProvider).valueOrNull ?? [];
    final unreadCount = notifications.where((n) => !n.isRead).length;

    final insightsAsync = ref.watch(patientInsightsProvider(uid ?? 'dev-token-patient-alex'));
    final multiAgentInsights = insightsAsync.valueOrNull;

    AppointmentModel? nextAppointment;
    if (streamAppts.isNotEmpty) {
      final upcoming = streamAppts.where((a) => a.dateTime.isAfter(DateTime.now()) && a.status != AppointmentStatus.cancelled && a.status != AppointmentStatus.rejected).toList();
      if (upcoming.isNotEmpty) {
        upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        nextAppointment = upcoming.first;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, ref, unreadCount, isDark),
                  const SizedBox(height: 16),
                  AppSearchBar(
                    readOnly: true,
                    hintText: 'Ask anything about your health, doctors, symptoms...',
                    onTap: () => context.go('/patient/ai-care'),
                    onFilterTap: () => context.push('/patient/dashboard/doctor-search'),
                  ),
                  const SizedBox(height: 20),

                  // 1. Blue Action Carousel with pagination
                  HomeActionCarousel(
                    onUploadTap: () => _showUploadReportSheet(context, isDark, uid),
                  ),
                  const SizedBox(height: 24),

                  // 2. Today's Health Insights Header & Summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Today's Health Insights",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.navy,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/patient/timeline'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HealthInsightsSummaryCard(
                    vitals: streamVitals,
                    medications: streamMeds,
                    reports: streamReports,
                    insights: multiAgentInsights,
                  ),
                  const SizedBox(height: 16),

                  // 2.5 Personal Activity & Behavior Twin
                  FutureBuilder<TwinStateModel?>(
                    future: ref.read(backendServiceProvider).getTwinState(uid ?? ''),
                    builder: (context, snapshot) {
                      return TwinActivityCard(
                        twinState: snapshot.data,
                        patientId: uid ?? '',
                        backendService: ref.read(backendServiceProvider),
                        onRefresh: () => setState(() {}),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 3. Supporting 2-Column Insight Cards
                  SupportingInsightCards(
                    vitals: streamVitals,
                    medications: streamMeds,
                    appointments: streamAppts,
                    reports: streamReports,
                    onUploadTap: () => _showUploadReportSheet(context, isDark, uid),
                  ),
                  const SizedBox(height: 20),

                  // 4. Clinical Health Records Upload Card
                  _buildUploadRecordsBanner(context, isDark, uid),
                  const SizedBox(height: 24),

                  // 5. Clinical AI Guidance & Traditional Care Tip
                  _buildTodayInsightsCard(context, isDark, streamVitals, streamMeds, streamReports, streamAppts, multiAgentInsights),
                  const SizedBox(height: 24),

                  // 6. Quick Action Row
                  _buildQuickActionsRow(context, isDark, uid),
                  const SizedBox(height: 24),

                  // 7. Vitals Overview
                  _buildVitalsSection(context, isDark, uid, streamVitals),
                  const SizedBox(height: 24),

                  // 8. Today's Medications
                  _buildTodayMedication(context, isDark, uid, streamMeds),
                  const SizedBox(height: 24),

                  // 9. Care Coordination / Next Appointment
                  if (nextAppointment != null) ...[
                    _buildNextAppointment(context, nextAppointment),
                    const SizedBox(height: 24),
                  ],

                  // 10. Find Specialists
                  if (doctors.isNotEmpty) ...[
                    _buildNearbyDoctors(context, doctors),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, int unreadCount, bool isDark) {
    final userAsync = ref.watch(currentUserProvider);
    final patientAsync = ref.watch(currentPatientStreamProvider);

    final fullName = patientAsync.valueOrNull?.name ??
        userAsync.valueOrNull?.name ??
        ref.watch(authProvider).user?.name ??
        'User';

    final firstName = fullName.trim().isEmpty ? 'User' : fullName.trim().split(' ').first;

    final parts = fullName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'U'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.blueToIndigo,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning,',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                Text(
                  firstName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navy,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    LucideIcons.bell,
                    color: isDark ? Colors.white : AppColors.navy,
                    size: 24,
                  ),
                  onPressed: () => NotificationSheet.show(context),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadRecordsBanner(BuildContext context, bool isDark, String? uid) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue,
            const Color(0xFF1D4ED8),
            const Color(0xFF1E3A8A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.fileUp, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Health Records',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'FHIR, EMR, Prescriptions, Lab & Discharge',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Keep your care timeline up-to-date. Ingest medical documents for continuous AI monitoring and doctor sharing.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.uploadCloud, size: 16),
            label: const Text(
              'Upload Document',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () => _showUploadReportSheet(context, isDark, uid),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayInsightsCard(
    BuildContext context,
    bool isDark,
    List<Vital> vitals,
    List<MedicationModel> meds,
    List<ReportModel> reports,
    List<AppointmentModel> appointments, [
    MultiAgentInsightsResponse? insights,
  ]) {
    String insightText = 'Your baseline health parameters are steady. Maintain daily hydration and active movement.';
    String traditionalNuskha = 'Warm ginger & honey water is traditionally suggested to soothe throat and support digestion.';

    if (insights != null && (insights.oracle != null || insights.synthesizedActions.isNotEmpty)) {
      if (insights.oracle != null) {
        insightText = '[ORACLE ${(insights.oracle!.confidence * 100).toInt()}%]: ${insights.oracle!.summary}';
      } else if (insights.synthesizedActions.isNotEmpty) {
        insightText = 'Recommended protocol: ${insights.synthesizedActions.first}';
      }
    } else {
      // 1. Check if an approved appointment is scheduled for today
      final now = DateTime.now();
      final todayApprovedAppts = appointments.where((a) {
        final isToday = a.dateTime.year == now.year && a.dateTime.month == now.month && a.dateTime.day == now.day;
        final isApproved = a.status == AppointmentStatus.approved || a.status == AppointmentStatus.confirmed;
        return isToday && isApproved;
      }).toList();

      if (todayApprovedAppts.isNotEmpty) {
        final appt = todayApprovedAppts.first;
        final timeFormatted = DateFormat('hh:mm a').format(appt.dateTime);
        insightText = 'You have a confirmed consultation today with ${appt.doctorName} at $timeFormatted. Have your recent vitals and questions ready.';
        traditionalNuskha = 'Keep a brief list of active symptoms and medications handy for your consultation.';
      } else if (vitals.isNotEmpty) {
        final latest = vitals.first;
        if (latest.heartRate != null && latest.heartRate! > 95) {
          insightText = 'Your heart rate was slightly elevated (${latest.heartRate} bpm). Ensure adequate rest and avoid heavy caffeine today.';
          traditionalNuskha = 'Chamomile infusion or breathing exercises are traditionally helpful to promote relaxation.';
        } else if (latest.systolic != null && latest.systolic! > 135) {
          insightText = 'Blood pressure is tracking at ${latest.systolic}/${latest.diastolic}. Maintain low sodium intake and regular medication.';
          traditionalNuskha = 'Hibiscus tea and garlic infusion have traditional usage for vascular support.';
        }
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.sparkles, color: AppColors.primaryBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Today\'s Health Insights',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insightText,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white : AppColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(LucideIcons.leaf, size: 14, color: AppColors.success),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Traditional Care Suggestion / Nuskha',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  traditionalNuskha,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF166534),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complementary advice — not a substitute for prescribed clinical care.',
                  style: TextStyle(color: AppColors.muted, fontSize: 10.5, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context, bool isDark, String? uid) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                title: 'Find Doctors',
                subtitle: 'Book Consult',
                icon: LucideIcons.stethoscope,
                color: AppColors.primaryBlue,
                isDark: isDark,
                onTap: () => context.push('/patient/dashboard/doctor-search'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                context,
                title: 'Follow-Ups',
                subtitle: 'Care Loops',
                icon: LucideIcons.checkCircle2,
                color: const Color(0xFF6366F1),
                isDark: isDark,
                onTap: () => context.push('/patient/followups'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                title: 'Log Vitals',
                subtitle: 'Heart, BP, SpO₂',
                icon: LucideIcons.activity,
                color: AppColors.danger,
                isDark: isDark,
                onTap: () => _showLogVitalsSheet(context, isDark, uid),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                context,
                title: 'Add Reminder',
                subtitle: 'Pills, Follow-up',
                icon: LucideIcons.bellPlus,
                color: AppColors.warning,
                isDark: isDark,
                onTap: () => _showAddReminderSheet(context, isDark, uid),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 18,
        elevation: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsSection(BuildContext context, bool isDark, String? uid, List<Vital> vitals) {
    if (vitals.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Health Vitals',
            trailing: TextButton.icon(
              onPressed: () => _showLogVitalsSheet(context, isDark, uid),
              icon: const Icon(LucideIcons.plus, size: 14),
              label: const Text('Add Reading', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.activity, color: AppColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No vital readings recorded yet',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Log your blood pressure, heart rate, or SpO₂ manually.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showLogVitalsSheet(context, isDark, uid),
                  child: const Text('Log Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final hr = vitals.first.heartRate != null ? '${vitals.first.heartRate} bpm' : '--';
    final bp = (vitals.first.systolic != null && vitals.first.diastolic != null) ? '${vitals.first.systolic}/${vitals.first.diastolic}' : '--';
    final spo2 = vitals.first.spo2 != null ? '${vitals.first.spo2}%' : '--';
    final weight = vitals.first.weight != null ? '${vitals.first.weight} kg' : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recorded Vitals',
          trailing: TextButton.icon(
            onPressed: () => _showLogVitalsSheet(context, isDark, uid),
            icon: const Icon(LucideIcons.plus, size: 14),
            label: const Text('Add Reading', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildVitalItem('Heart Rate', hr, LucideIcons.heart, AppColors.danger, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildVitalItem('Blood Pressure', bp, LucideIcons.gauge, AppColors.primaryBlue, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildVitalItem('SpO₂', spo2, LucideIcons.wind, AppColors.accentCyan, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildVitalItem('Weight', weight, LucideIcons.scale, AppColors.success, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalItem(String label, String value, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      borderRadius: 16,
      elevation: 1,
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white : AppColors.navy,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMedication(
    BuildContext context,
    bool isDark,
    String? uid,
    List<MedicationModel> medications,
  ) {
    final today = DateTime.now();
    final todayMeds = medications.where((m) {
      final isSameDay = m.date.year == today.year && m.date.month == today.month && m.date.day == today.day;
      final freq = (m.frequency ?? '').toLowerCase();
      final isRecurring = freq.contains('daily') || freq.contains('day') || freq.contains('morning') || freq.contains('night');
      final inDateRange = (m.startDate == null || !m.startDate!.isAfter(today)) && (m.endDate == null || !m.endDate!.isBefore(today));
      return isSameDay || (isRecurring && inDateRange);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Today\'s Medications',
          actionText: 'View All',
          onActionTap: () => context.push('/patient/timeline'),
          trailing: ElevatedButton.icon(
            onPressed: () => _showAddMedicationSheet(context, isDark, uid),
            icon: const Icon(LucideIcons.plus, size: 14, color: Colors.white),
            label: const Text('Add Medicine', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (todayMeds.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderRadius: 16,
            child: Row(
              children: [
                const Icon(LucideIcons.pill, color: AppColors.muted, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No scheduled medications for today.',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddMedicationSheet(context, isDark, uid),
                  icon: const Icon(LucideIcons.plus, size: 13, color: Colors.white),
                  label: const Text('Add Medicine', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          )
        else
          ...todayMeds.take(5).map(
                (med) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MedicationCard(
                    name: med.name,
                    dosage: med.dosage,
                    time: med.time,
                    instructions: med.notes,
                    isTaken: med.isTaken,
                    isSkipped: med.isSkipped,
                    onMarkAsTaken: () async {
                      if (uid != null) {
                        try {
                          await ref.read(medicationRepositoryProvider).markTaken(uid, med.id);
                          dev.log('[MEDICATION] Marked ${med.name} as taken', name: 'PatientDashboard');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Marked ${med.name} as taken.'), backgroundColor: AppColors.success),
                            );
                          }
                        } catch (e) {
                          dev.log('[MEDICATION] Error marking taken: $e', error: e, name: 'PatientDashboard');
                        }
                      }
                    },
                    onMarkAsSkipped: () async {
                      if (uid != null) {
                        try {
                          await ref.read(medicationRepositoryProvider).markSkipped(uid, med.id);
                          dev.log('[MEDICATION] Marked ${med.name} as skipped', name: 'PatientDashboard');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Marked ${med.name} as skipped.'), backgroundColor: AppColors.warning),
                            );
                          }
                        } catch (e) {
                          dev.log('[MEDICATION] Error marking skipped: $e', error: e, name: 'PatientDashboard');
                        }
                      }
                    },
                    onEdit: () => _showEditMedicationSheet(context, isDark, uid, med),
                    onDelete: () => _confirmDeleteMedication(context, uid, med),
                  ),
                ),
              ),
      ],
    );
  }

  void _showAddMedicationSheet(BuildContext context, bool isDark, String? uid) {
    final effectiveUid = (uid != null && uid.isNotEmpty) ? uid : FirebaseAuth.instance.currentUser?.uid;
    if (effectiveUid == null || effectiveUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add medication reminders.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final notesController = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    String selectedFrequency = 'Once daily';
    final frequencies = ['Once daily', 'Twice daily', 'Three times daily', 'Morning & Night', 'As needed'];
    String? formError;
    bool isSaving = false;

    String reminderFor = 'Me'; // 'Me' or 'Family Member'
    String? selectedMemberId;
    String? selectedMemberName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final now = DateTime.now();
          final dtFormat = DateFormat('h:mm a');
          final timeDisplay = dtFormat.format(DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute));
          final familyAsync = ref.read(familyRelationshipsStreamProvider(effectiveUid));
          final familyList = familyAsync.valueOrNull ?? [];

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: Container(
                padding: EdgeInsets.only(
                  bottom: AppLayoutInsets.bottomSafeInset(context) + 20,
                  top: 24,
                  left: 20,
                  right: 20,
                ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131C2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.pill, color: AppColors.primaryBlue, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Add Medicine',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(LucideIcons.x, size: 20, color: isDark ? Colors.white70 : AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (formError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Who is this reminder for?
                  Text(
                    'Who is this reminder for? *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('For Me'),
                        selected: reminderFor == 'Me',
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.18),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              reminderFor = 'Me';
                              selectedMemberId = null;
                              selectedMemberName = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Family Member'),
                        selected: reminderFor == 'Family Member',
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.18),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              reminderFor = 'Family Member';
                              if (familyList.isNotEmpty && selectedMemberId == null) {
                                selectedMemberId = familyList.first.familyMemberId;
                                selectedMemberName = familyList.first.memberName ?? 'Family Member';
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (reminderFor == 'Family Member') ...[
                    const SizedBox(height: 8),
                    if (familyList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'No linked family members found. Link a member in the Family tab first to create reminders for them.',
                          style: TextStyle(fontSize: 12, color: Colors.amber),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selectedMemberId ?? familyList.first.familyMemberId,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: familyList.map((m) {
                          return DropdownMenuItem(
                            value: m.familyMemberId,
                            child: Text(
                              '${m.memberName ?? "Member"} (${m.relationship})',
                              style: TextStyle(color: isDark ? Colors.white : AppColors.navy, fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final match = familyList.firstWhere((m) => m.familyMemberId == val);
                            setModalState(() {
                              selectedMemberId = val;
                              selectedMemberName = match.memberName ?? 'Family Member';
                            });
                          }
                        },
                      ),
                  ],
                  const SizedBox(height: 14),

                  // Medicine Name
                  Text(
                    'Medicine Name *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Metformin, Paracetamol, Atorvastatin',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dosage
                  Text(
                    'Dosage *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dosageController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 500 mg, 1 tablet, 5 ml',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Reminder Time Picker
                  Text(
                    'Reminder Time *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.clock, size: 18, color: AppColors.primaryBlue),
                              const SizedBox(width: 10),
                              Text(
                                timeDisplay,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Change Time',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Frequency Selection
                  Text(
                    'Frequency *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: frequencies.map((freq) {
                      final isSelected = selectedFrequency == freq;
                      return ChoiceChip(
                        label: Text(freq),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.navy),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedFrequency = freq);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Optional Notes
                  Text(
                    'Instructions / Notes (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Take after meal with warm water',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final dosage = dosageController.text.trim();
                              if (name.isEmpty) {
                                setModalState(() => formError = 'Please enter medicine name.');
                                return;
                              }
                              if (dosage.isEmpty) {
                                setModalState(() => formError = 'Please enter dosage (e.g. 500mg).');
                                return;
                              }

                              setModalState(() {
                                isSaving = true;
                                formError = null;
                              });

                              try {
                                final now = DateTime.now();
                                final scheduledDateTime = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );

                                final targetUid = (reminderFor == 'Family Member' && selectedMemberId != null)
                                    ? selectedMemberId!
                                    : effectiveUid;
                                final isForFamily = targetUid != effectiveUid;

                                final docRef = FirebaseFirestore.instance
                                    .collection('patients')
                                    .doc(targetUid)
                                    .collection('medications')
                                    .doc();

                                final med = Medication(
                                  id: docRef.id,
                                  name: name,
                                  dosage: dosage,
                                  time: timeDisplay,
                                  isTaken: false,
                                  isSkipped: false,
                                  date: scheduledDateTime,
                                  patientId: targetUid,
                                  frequency: selectedFrequency,
                                  notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                                  startDate: scheduledDateTime,
                                  active: true,
                                );

                                dev.log('[FIRESTORE] Writing medication ${docRef.id} under target patient $targetUid (creator: $effectiveUid)', name: 'PatientDashboard');
                                await ref.read(medicationRepositoryProvider).addMedication(targetUid, med);

                                // Also persist to Reminder collection for unified schedule with target patientId & createdBy
                                final reminder = Reminder(
                                  id: 'rem_${docRef.id}',
                                  title: '$name ($dosage)',
                                  description: notesController.text.trim().isNotEmpty
                                      ? notesController.text.trim()
                                      : 'Scheduled medication reminder • $selectedFrequency',
                                  type: ReminderType.medication,
                                  dateTime: scheduledDateTime,
                                  isCompleted: false,
                                  patientId: targetUid,
                                  targetUid: targetUid,
                                  createdBy: effectiveUid,
                                  creatorUid: effectiveUid,
                                  medicineName: name,
                                  dosage: dosage,
                                  reminderTime: timeDisplay,
                                  frequency: selectedFrequency,
                                  targetPatientName: selectedMemberName,
                                );
                                await ref.read(reminderRepositoryProvider).addReminder(targetUid, reminder);

                                if (isForFamily) {
                                  dev.log('''
[FAMILY_REMINDER]
creatorUid = $effectiveUid
targetUid = $targetUid
patientId = $targetUid
reminderId = rem_${docRef.id}
reminderTime = $timeDisplay
'''.trim(), name: 'FamilyReminder');
                                  dev.log('[FAMILY_TARGET] targetUid = $targetUid', name: 'FamilyReminder');
                                }

                                // Trigger actual local notification via awesome_notifications ONLY for personal reminders
                                if (!isForFamily) {
                                  await AwesomeNotificationService.scheduleMedicationReminder(
                                    id: docRef.id.hashCode,
                                    medicineName: name,
                                    dosage: dosage,
                                    scheduledTime: scheduledDateTime,
                                    medicationId: docRef.id,
                                  );
                                } else {
                                  dev.log('[FAMILY_REMINDER] Creator device skipping local notification. Target ($targetUid) will schedule on device receipt.', name: 'PatientDashboard');
                                }
                                dev.log('[MEDICATION] Successfully added medication $name for $targetUid', name: 'PatientDashboard');

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isForFamily
                                          ? 'Medication reminder for $selectedMemberName ($name) scheduled for $timeDisplay.'
                                          : 'Medication reminder for $name scheduled for $timeDisplay.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                dev.log('[MEDICATION] Error saving medication: $e', error: e, name: 'PatientDashboard');
                                setModalState(() {
                                  isSaving = false;
                                  formError = 'Failed to save reminder: $e';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save Medicine',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
);
  }

  void _showEditMedicationSheet(BuildContext context, bool isDark, String? uid, MedicationModel med) {
    final effectiveUid = (uid != null && uid.isNotEmpty) ? uid : (med.patientId ?? FirebaseAuth.instance.currentUser?.uid);
    if (effectiveUid == null || effectiveUid.isEmpty) return;

    final nameController = TextEditingController(text: med.name);
    final dosageController = TextEditingController(text: med.dosage);
    final notesController = TextEditingController(text: med.notes ?? '');

    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    try {
      final parsed = DateFormat('h:mm a').parse(med.time);
      selectedTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    } catch (_) {
      try {
        final parsed24 = DateFormat('HH:mm').parse(med.time);
        selectedTime = TimeOfDay(hour: parsed24.hour, minute: parsed24.minute);
      } catch (_) {}
    }

    String selectedFrequency = med.frequency ?? 'Once daily';
    final frequencies = ['Once daily', 'Twice daily', 'Three times daily', 'Morning & Night', 'As needed'];
    if (!frequencies.contains(selectedFrequency)) frequencies.add(selectedFrequency);
    String? formError;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final now = DateTime.now();
          final dtFormat = DateFormat('h:mm a');
          final timeDisplay = dtFormat.format(DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute));

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: Container(
                padding: EdgeInsets.only(
                  bottom: AppLayoutInsets.bottomSafeInset(context) + 20,
                  top: 24,
                  left: 20,
                  right: 20,
                ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131C2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.pencil, color: AppColors.primaryBlue, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Edit Medication',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(LucideIcons.x, size: 20, color: isDark ? Colors.white70 : AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (formError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Medicine Name
                  Text(
                    'Medicine Name *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Metformin, Paracetamol',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dosage
                  Text(
                    'Dosage *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dosageController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 500 mg, 1 tablet',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Time
                  Text(
                    'Reminder Time *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.clock, size: 18, color: AppColors.primaryBlue),
                              const SizedBox(width: 10),
                              Text(
                                timeDisplay,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Change Time',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Frequency
                  Text(
                    'Frequency *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: frequencies.map((freq) {
                      final isSelected = selectedFrequency == freq;
                      return ChoiceChip(
                        label: Text(freq),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.navy),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedFrequency = freq);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Optional Notes
                  Text(
                    'Instructions / Notes (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Take with warm water after meals',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final dosage = dosageController.text.trim();
                              if (name.isEmpty) {
                                setModalState(() => formError = 'Please enter medicine name.');
                                return;
                              }
                              if (dosage.isEmpty) {
                                setModalState(() => formError = 'Please enter dosage (e.g. 500mg).');
                                return;
                              }

                              setModalState(() {
                                isSaving = true;
                                formError = null;
                              });

                              try {
                                final now = DateTime.now();
                                final scheduledDateTime = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );

                                final updatedMed = med.copyWith(
                                  name: name,
                                  dosage: dosage,
                                  time: timeDisplay,
                                  frequency: selectedFrequency,
                                  notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                                  date: scheduledDateTime,
                                );

                                await ref.read(medicationRepositoryProvider).updateMedication(effectiveUid, updatedMed);
                                dev.log('[MEDICATION] Updated medication ${med.id} in Firestore', name: 'PatientDashboard');

                                // Update corresponding reminder
                                final updatedReminder = Reminder(
                                  id: 'rem_${med.id}',
                                  title: '$name ($dosage)',
                                  description: notesController.text.trim().isNotEmpty
                                      ? notesController.text.trim()
                                      : 'Scheduled medication reminder • $selectedFrequency',
                                  type: ReminderType.medicine,
                                  dateTime: scheduledDateTime,
                                  isCompleted: med.isTaken,
                                  patientId: effectiveUid,
                                );
                                await ref.read(reminderRepositoryProvider).addReminder(effectiveUid, updatedReminder);

                                // Reschedule local notification
                                await AwesomeNotificationService.scheduleMedicationReminder(
                                  id: med.id.hashCode,
                                  medicineName: name,
                                  dosage: dosage,
                                  scheduledTime: scheduledDateTime,
                                  medicationId: med.id,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Updated $name successfully.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                dev.log('[MEDICATION] Error updating medication: $e', error: e, name: 'PatientDashboard');
                                setModalState(() {
                                  isSaving = false;
                                  formError = 'Failed to update: $e';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Update Medication',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
);
  }

  void _confirmDeleteMedication(BuildContext context, String? uid, MedicationModel med) {
    final effectiveUid = (uid != null && uid.isNotEmpty) ? uid : (med.patientId ?? FirebaseAuth.instance.currentUser?.uid);
    if (effectiveUid == null || effectiveUid.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Are you sure you want to delete ${med.name} (${med.dosage})? This will cancel all upcoming reminders for this medicine.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(medicationRepositoryProvider).deleteMedication(effectiveUid, med.id);
                await AwesomeNotificationService.cancelMedicationReminder(med.id.hashCode);
                dev.log('[MEDICATION] Successfully deleted ${med.id}', name: 'PatientDashboard');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted ${med.name}.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                dev.log('[MEDICATION] Failed to delete: $e', error: e, name: 'PatientDashboard');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNextAppointment(BuildContext context, AppointmentModel appointment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Care Coordination & Consultations',
          actionText: 'Timeline',
          onActionTap: () => context.push('/patient/timeline'),
        ),
        const SizedBox(height: 10),
        AppointmentCard(
          title: appointment.doctorName.isNotEmpty ? appointment.doctorName : 'Specialist Consultation',
          subtitle: appointment.specialty,
          dateTime: appointment.dateTime,
          onTap: () => context.push('/patient/timeline'),
        ),
      ],
    );
  }

  Widget _buildNearbyDoctors(BuildContext context, List<DoctorModel> doctors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Available Specialists',
          actionText: 'See all',
          onActionTap: () => context.push('/patient/dashboard/doctor-search'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: doctors.length > 5 ? 5 : doctors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return DoctorCard(
                name: doctor.name,
                specialty: doctor.specialty,
                avatarUrl: doctor.avatarUrl,
                rating: doctor.rating,
                onTap: () => context.push('/patient/dashboard/doctor/${doctor.id}'),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showUploadReportSheet(BuildContext context, bool isDark, String? uid) {
    final titleController = TextEditingController();
    final facilityController = TextEditingController();
    final summaryController = TextEditingController();
    ReportCategory selectedCategory = ReportCategory.lab;
    DateTime selectedDate = DateTime.now();
    DateTime? followUpDate;
    List<int>? attachedFileBytes;
    String? attachedFileName;
    String? attachedFileType;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: AppLayoutInsets.bottomSafeInset(ctx) + 20,
                ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Upload Health Document / Report',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navy),
                  ),
                  const SizedBox(height: 4),
                  Text('Direct in-memory AI clinical extraction (Zero file storage) & Care Timeline ingestion.', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText, fontSize: 12)),
                  const SizedBox(height: 16),

                  // File Picker Attachment Button
                  GestureDetector(
                    onTap: isUploading
                        ? null
                        : () async {
                            try {
                              final file = await FilePicker.pickFile(
                                type: FileType.any,
                              );
                              if (file != null) {
                                final bytes = await file.readAsBytes();
                                setModalState(() {
                                  attachedFileBytes = bytes;
                                  attachedFileName = file.name;
                                  attachedFileType = file.extension != null ? 'application/${file.extension}' : 'application/pdf';
                                  if (titleController.text.trim().isEmpty) {
                                    // Auto-populate title from filename without extension
                                    final nameWithoutExt = file.name.split('.').first;
                                    titleController.text = nameWithoutExt.replaceAll('_', ' ');
                                  }
                                });
                              }
                            } catch (e) {
                              dev.log('[TRANSIENT] FilePicker error: $e', error: e, name: 'PatientDashboard');
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: attachedFileName != null
                              ? AppColors.primaryBlue
                              : (isDark ? const Color(0xFF334155) : AppColors.border),
                          width: attachedFileName != null ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (attachedFileName != null ? AppColors.primaryBlue : AppColors.muted).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              attachedFileName != null ? LucideIcons.fileCheck : LucideIcons.uploadCloud,
                              color: attachedFileName != null ? AppColors.primaryBlue : AppColors.muted,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  attachedFileName ?? 'Attach Medical File (PDF, Image, EMR)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : AppColors.navy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  attachedFileBytes != null
                                      ? '${(attachedFileBytes!.length / 1024).toStringAsFixed(1)} KB • Ready for in-memory AI extraction'
                                      : 'Tap to select document from device',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (attachedFileName != null)
                            IconButton(
                              icon: const Icon(LucideIcons.x, size: 18, color: AppColors.muted),
                              onPressed: () {
                                setModalState(() {
                                  attachedFileBytes = null;
                                  attachedFileName = null;
                                  attachedFileType = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  
                  // Category Dropdown
                  DropdownButtonFormField<ReportCategory>(
                    initialValue: selectedCategory,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    decoration: InputDecoration(
                      labelText: 'Document Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: ReportCategory.lab, child: Text('Lab Report (CBC, Lipid, Blood Sugar)')),
                      DropdownMenuItem(value: ReportCategory.prescription, child: Text('Prescription')),
                      DropdownMenuItem(value: ReportCategory.discharge, child: Text('Discharge Summary')),
                      DropdownMenuItem(value: ReportCategory.emr, child: Text('EMR / Health Summary')),
                      DropdownMenuItem(value: ReportCategory.treatment, child: Text('Treatment Report')),
                      DropdownMenuItem(value: ReportCategory.doctorNote, child: Text('Doctor Consultation Note')),
                      DropdownMenuItem(value: ReportCategory.fhir, child: Text('FHIR Health Bundle')),
                      DropdownMenuItem(value: ReportCategory.other, child: Text('Other Medical Document')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Document Title *',
                      hintText: 'e.g. Complete Blood Count, Hospital Discharge',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: facilityController,
                    decoration: InputDecoration(
                      labelText: 'Hospital / Clinic / Doctor Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: summaryController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Summary / Findings / Extracted Notes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Follow-up Date Toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.calendarCheck, color: AppColors.primaryBlue),
                    title: const Text('Schedule Follow-Up Date (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      followUpDate != null ? DateFormat('EEEE, MMM d, yyyy').format(followUpDate!) : 'No follow-up selected',
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue),
                    ),
                    trailing: TextButton(
                      child: Text(followUpDate != null ? 'Change' : 'Set Date'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => followUpDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  PrimaryButton(
                    label: isUploading ? 'Extracting Clinical Insights...' : 'Extract & Save Insights',
                    icon: isUploading ? null : LucideIcons.check,
                    onPressed: isUploading
                        ? null
                        : () async {
                            if (uid == null || titleController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a document title')),
                              );
                              return;
                            }

                            setModalState(() => isUploading = true);

                            final report = ReportModel(
                              id: '',
                              patientId: uid,
                              title: titleController.text.trim(),
                              category: selectedCategory,
                              date: selectedDate,
                              doctorOrFacility: facilityController.text.trim().isNotEmpty ? facilityController.text.trim() : null,
                              summary: summaryController.text.trim().isNotEmpty ? summaryController.text.trim() : null,
                              followUpDate: followUpDate,
                              followUpInstructions: followUpDate != null ? 'Follow up regarding ${titleController.text.trim()}' : null,
                              sharedWithDoctor: true,
                            );

                            try {
                              await ref.read(reportRepositoryProvider).uploadReport(
                                    report,
                                    fileBytes: attachedFileBytes,
                                    fileName: attachedFileName,
                                    fileType: attachedFileType,
                                  );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Clinical insights extracted and added to Care Timeline (Zero file storage)!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              dev.log('[TRANSIENT] [FIRESTORE] Document processing failed: $e', error: e, name: 'PatientDashboard');
                              setModalState(() => isUploading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Extraction failed: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
);
  }

  void _showLogVitalsSheet(BuildContext context, bool isDark, String? uid) {
    final hrController = TextEditingController(text: '74');
    final sysController = TextEditingController(text: '120');
    final diaController = TextEditingController(text: '80');
    final spo2Controller = TextEditingController(text: '98');
    final weightController = TextEditingController(text: '68.0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: AppLayoutInsets.bottomSafeInset(ctx) + 20,
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Log Vital Reading', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navy)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hrController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Heart Rate (bpm)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: spo2Controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'SpO₂ (%)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sysController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Systolic BP', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: diaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Diastolic BP', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Save Vitals Reading',
              onPressed: () async {
                if (uid != null) {
                  final vital = Vital(
                    id: '',
                    patientId: uid,
                    heartRate: int.tryParse(hrController.text) ?? 74,
                    systolic: int.tryParse(sysController.text) ?? 120,
                    diastolic: int.tryParse(diaController.text) ?? 80,
                    spo2: int.tryParse(spo2Controller.text) ?? 98,
                    weight: double.tryParse(weightController.text) ?? 68.0,
                    recordedAt: DateTime.now(),
                  );
                  await ref.read(vitalRepositoryProvider).addVital(uid, vital);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  void _showAddReminderSheet(BuildContext context, bool isDark, String? uid) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime reminderTime = DateTime.now().add(const Duration(hours: 2));
    ReminderType selectedType = ReminderType.medicine;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: AppLayoutInsets.bottomSafeInset(ctx) + 20,
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Text('Create Health Reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navy)),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'Reminder Title (e.g. Take Metformin, Drink 500ml Water)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(labelText: 'Instructions / Description (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.clock, color: AppColors.primaryBlue),
                  title: Text(DateFormat('EEEE, MMM d • hh:mm a').format(reminderTime), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: TextButton(
                    child: const Text('Change Time'),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: ctx,
                        initialDate: reminderTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null && ctx.mounted) {
                        final pickedTime = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(reminderTime),
                        );
                        if (pickedTime != null) {
                          setModalState(() {
                            reminderTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Set Reminder',
                  onPressed: () async {
                    if (uid != null && titleController.text.trim().isNotEmpty) {
                      final reminder = Reminder(
                        id: '',
                        patientId: uid,
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        dateTime: reminderTime,
                        type: selectedType,
                        isCompleted: false,
                      );
                      await ref.read(reminderRepositoryProvider).addReminder(uid, reminder);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      );
        },
      ),
    );
  }
}
