import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/notification_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/patient_model.dart';
import '../../../../data/models/appointment_model.dart';

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  ConsumerState<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      ref.read(patientsProvider.notifier).loadPatients();
      if (user != null) {
        ref.read(appointmentsProvider.notifier).loadAppointments(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final realAssociatedPatients = ref.watch(doctorAssociatedPatientsStreamProvider).valueOrNull;
    final List<PatientModel> patients = realAssociatedPatients ?? ref.watch(patientsProvider);
    final streamAppts = ref.watch(doctorAppointmentsStreamProvider).valueOrNull;
    final List<AppointmentModel> appointments = streamAppts ?? ref.watch(appointmentsProvider);
    final authState = ref.watch(authProvider);

    final activePatients = patients.where((p) => p.isAuthorized).toList();
    final needsAttention = patients.where((p) => p.status == 'attention' || p.status == 'critical').toList();

    final now = DateTime.now();
    final todayAppointments = appointments.where((a) {
      final isToday = a.dateTime.year == now.year && a.dateTime.month == now.month && a.dateTime.day == now.day;
      final isApproved = a.status == AppointmentStatus.approved || a.status == AppointmentStatus.confirmed || a.status == AppointmentStatus.scheduled;
      return isToday && isApproved;
    }).toList();

    final pendingRequests = appointments.where((a) {
      return a.status == AppointmentStatus.pending || a.status == AppointmentStatus.requested;
    }).toList();

    final notifications = ref.watch(notificationsStreamProvider).valueOrNull ?? [];
    final unreadNotifs = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(patientsProvider.notifier).loadPatients();
            if (authState.user != null) {
              ref.read(appointmentsProvider.notifier).loadAppointments(authState.user!.id);
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, authState.user?.name, isDark, unreadNotifs),
                const SizedBox(height: 20),

                // Stat Cards Grid (2x2)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    _buildStatCard('Active Patients', activePatients.length.toString(), LucideIcons.users, AppColors.primaryBlue, isDark),
                    _buildStatCard('Appts Today', todayAppointments.length.toString(), LucideIcons.calendar, AppColors.success, isDark),
                    _buildStatCard('Needs Attention', needsAttention.length.toString(), LucideIcons.alertTriangle, AppColors.warning, isDark),
                    _buildStatCard('Pending Requests', pendingRequests.length.toString(), LucideIcons.clock, pendingRequests.isNotEmpty ? AppColors.warning : AppColors.accentCyan, isDark),
                  ],
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),
                const SizedBox(height: 24),

                // Quick Actions Bar
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickActionButton('Add Appt', LucideIcons.plusCircle, AppColors.primaryBlue, () => _showAddAppointmentModal(context, isDark), isDark),
                      _buildQuickActionButton('Add Patient', LucideIcons.userPlus, AppColors.success, () => _showAddPatientModal(context, isDark), isDark),
                      _buildQuickActionButton('Send Alert', LucideIcons.bellRing, AppColors.danger, () => _showSendAlertModal(context, isDark), isDark),
                      _buildQuickActionButton('Add Reminder', LucideIcons.clock, AppColors.warning, () => _showAddReminderModal(context, isDark), isDark),
                      _buildQuickActionButton('View Reports', LucideIcons.fileText, const Color(0xFF8B5CF6), () => _showReportsModal(context, isDark), isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // PENDING APPOINTMENT REQUESTS
                if (pendingRequests.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PENDING APPOINTMENT REQUESTS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${pendingRequests.length} pending',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...pendingRequests.map((req) => _buildPendingRequestCard(context, req, isDark)),
                  const SizedBox(height: 24),
                ],

                // Patients Needing Attention Section
                if (needsAttention.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Patients Needing Attention',
                    actionText: 'View All',
                    onActionTap: () => context.go('/doctor/patients'),
                  ),
                  const SizedBox(height: 12),
                  ...needsAttention.map((patient) => _buildAttentionCard(context, patient, isDark)),
                  const SizedBox(height: 24),
                ],

                // Today's Schedule Stream
                Text(
                  "Today's Schedule",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                if (todayAppointments.isEmpty)
                  AppCard(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    borderRadius: 20,
                    child: Center(
                      child: Text(
                        'No consultations scheduled for today.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  ...todayAppointments.map((appt) => _buildScheduleTile(appt, isDark)),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? doctorName, bool isDark, int unreadCount) {
    final streamDoctor = ref.watch(currentDoctorStreamProvider).valueOrNull;
    final displayName = streamDoctor?.name ?? doctorName ?? 'Dr. Practitioner';
    final specialty = streamDoctor?.specialty ?? 'General Practice';
    final hospital = streamDoctor?.hospital ?? 'City Clinic';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppColors.blueToIndigo,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: displayName.isNotEmpty
                    ? Text(
                        displayName.replaceFirst('Dr. ', '').trim().isNotEmpty
                            ? displayName.replaceFirst('Dr. ', '').trim()[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Icon(
                        LucideIcons.user,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName.startsWith('Dr.') ? displayName : 'Dr. $displayName',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navy,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👋', style: TextStyle(fontSize: 17)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$specialty • $hospital',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => NotificationSheet.show(context),
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppColors.border.withValues(alpha: 0.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.bell,
                    color: isDark ? Colors.white : AppColors.navy,
                    size: 20,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF0A0F1D) : Colors.white,
                          width: 2,
                        ),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
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
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingRequestCard(BuildContext context, AppointmentModel appt, bool isDark) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      elevation: 1,
      borderColor: AppColors.warning.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.warning.withValues(alpha: isDark ? 0.25 : 0.15),
                child: Text(
                  appt.patientName.isNotEmpty ? appt.patientName[0].toUpperCase() : 'P',
                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt.patientName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('EEEE, MMM d, yyyy').format(appt.dateTime)} at ${_formatTime(appt.dateTime)}',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          if (appt.notes != null && appt.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Notes: ${appt.notes}',
                style: TextStyle(
                  color: isDark ? const Color(0xFFCBD5E1) : AppColors.slate,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Reject',
                  icon: LucideIcons.x,
                  onPressed: () async {
                    final currentDoctor = ref.read(currentDoctorStreamProvider).valueOrNull;
                    await ref.read(appointmentRepositoryProvider).updateStatus(
                          appt.patientId,
                          appt.doctorId,
                          appt.id,
                          AppointmentStatus.rejected,
                          updatedByDoctor: true,
                          doctorName: currentDoctor?.name,
                          patientName: appt.patientName,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Appointment request from ${appt.patientName} rejected.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Accept',
                  icon: LucideIcons.check,
                  onPressed: () async {
                    final currentDoctor = ref.read(currentDoctorStreamProvider).valueOrNull;
                    await ref.read(appointmentRepositoryProvider).updateStatus(
                          appt.patientId,
                          appt.doctorId,
                          appt.id,
                          AppointmentStatus.approved,
                          updatedByDoctor: true,
                          doctorName: currentDoctor?.name,
                          patientName: appt.patientName,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Appointment with ${appt.patientName} approved!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131C2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.border.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionCard(BuildContext context, PatientModel patient, bool isDark) {
    final isCritical = patient.status == 'critical';
    final color = isCritical ? AppColors.danger : AppColors.warning;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      elevation: 1,
      borderColor: color.withValues(alpha: 0.4),
      onTap: () => context.push('/doctor/patients/patient/${patient.id}', extra: patient),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: isDark ? 0.25 : 0.15),
            child: Text(
              patient.name.isNotEmpty ? patient.name[0] : 'P',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${patient.condition} • Adherence ${patient.medicationAdherence.toInt()}%',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              isCritical ? 'CRITICAL' : 'ATTENTION',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(AppointmentModel appt, bool isDark) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      elevation: 0.5,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.stethoscope, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.patientName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${appt.specialty} • ${_formatTime(appt.dateTime)}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : AppColors.softBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.25),
              ),
            ),
            child: const Text(
              'CONFIRMED',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modals for Quick Actions
  // Modals for Quick Actions
  void _showAddAppointmentModal(BuildContext context, bool isDark) {
    final currentDoctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doctorName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Doctor';
    final patientCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131C2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule Patient Consultation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: patientCtrl,
              decoration: const InputDecoration(
                labelText: 'Patient Name or ID',
                hintText: 'e.g. John Doe',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Consultation Reason / Notes',
                hintText: 'e.g. Follow-up consultation',
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Confirm & Schedule',
              onPressed: () async {
                final patientName = patientCtrl.text.trim();
                if (patientName.isEmpty) return;

                final apptId = const Uuid().v4();
                final patientId = patientName.toLowerCase().replaceAll(' ', '_');
                final apptDateTime = DateTime.now().add(const Duration(hours: 2));

                dev.log('[APPOINTMENT] path being read/written: appointments/$apptId', name: 'DoctorDashboardScreen');
                dev.log('[APPOINTMENT] Firebase UID: $currentDoctorUid', name: 'DoctorDashboardScreen');
                dev.log('[APPOINTMENT] doctorId: $currentDoctorUid', name: 'DoctorDashboardScreen');
                dev.log('[APPOINTMENT] appointmentId: $apptId', name: 'DoctorDashboardScreen');

                final appt = AppointmentModel(
                  id: apptId,
                  patientId: patientId,
                  doctorId: currentDoctorUid,
                  doctorName: doctorName,
                  patientName: patientName,
                  specialty: 'Medical Consultation',
                  dateTime: apptDateTime,
                  durationMinutes: 30,
                  status: AppointmentStatus.approved,
                  notes: notesCtrl.text.trim(),
                );

                try {
                  await ref.read(appointmentRepositoryProvider).bookAppointment(appt);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Consultation scheduled for $patientName!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  dev.log('[APPOINTMENT] exception: $e', name: 'DoctorDashboardScreen');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
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
    );
  }

  void _showAddPatientModal(BuildContext context, bool isDark) {
    final currentDoctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final idCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Patient & Request Access',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter patient UID or identifier to request health record access.',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: 'Patient UID / ID',
                hintText: 'Enter patient user ID',
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Send Access Request',
              onPressed: () async {
                final patientId = idCtrl.text.trim();
                if (patientId.isEmpty) return;

                dev.log('[ACCESS] Requesting access from doctor $currentDoctorUid to patient $patientId', name: 'DoctorDashboardScreen');
                try {
                  await ref.read(patientRepositoryProvider).requestAccess(
                    currentDoctorUid,
                    patientId,
                    permissions: const ['profile', 'vitals', 'medications', 'appointments', 'medicalHistory', 'reports'],
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Access request sent to patient $patientId!'),
                        backgroundColor: AppColors.primaryBlue,
                      ),
                    );
                  }
                } catch (e) {
                  dev.log('[ACCESS] exception: $e', name: 'DoctorDashboardScreen');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
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
    );
  }

  void _showSendAlertModal(BuildContext context, bool isDark) {
    final currentDoctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doctorName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Doctor';
    final alertCtrl = TextEditingController();
    final patientIdCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Patient Clinical Alert',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: patientIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Target Patient ID',
                hintText: 'e.g. Patient UID',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: alertCtrl,
              decoration: const InputDecoration(
                labelText: 'Alert Message',
                hintText: 'e.g. Please check your blood pressure immediately.',
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Send Real-Time Alert',
              onPressed: () async {
                final targetPatientId = patientIdCtrl.text.trim();
                final message = alertCtrl.text.trim();
                if (targetPatientId.isEmpty || message.isEmpty) return;

                dev.log('[NOTIFICATION] Sending alert to patients/$targetPatientId/notifications', name: 'DoctorDashboardScreen');
                try {
                  await FirebaseFirestore.instance
                      .collection('patients')
                      .doc(targetPatientId)
                      .collection('notifications')
                      .add({
                    'title': 'Doctor Clinical Alert',
                    'message': message,
                    'type': 'doctor_alert',
                    'doctorId': currentDoctorUid,
                    'doctorName': doctorName,
                    'isRead': false,
                    'timestamp': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Clinical alert sent to patient!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  dev.log('[NOTIFICATION] exception: $e', name: 'DoctorDashboardScreen');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Alert failed: $e'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReminderModal(BuildContext context, bool isDark) {
    final currentDoctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Doctor Clinical Reminder',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Reminder Note',
                hintText: 'e.g. Follow up on ECG report',
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Doctor Reminder',
              onPressed: () async {
                final note = noteCtrl.text.trim();
                if (note.isEmpty) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('doctors')
                      .doc(currentDoctorUid)
                      .collection('notifications')
                      .add({
                    'title': 'Clinical Reminder',
                    'message': note,
                    'type': 'doctor_reminder',
                    'doctorId': currentDoctorUid,
                    'isRead': false,
                    'timestamp': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Follow-up reminder saved to notifications!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  dev.log('[NOTIFICATION] exception: $e', name: 'DoctorDashboardScreen');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportsModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Medical Reports',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Access permitted patient records by selecting any authorized patient below.',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.users, color: AppColors.primaryBlue),
              title: Text('View Authorized Patients', style: TextStyle(color: isDark ? Colors.white : AppColors.navy)),
              subtitle: const Text('Navigate to full patient brief and reports'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () {
                Navigator.pop(context);
                context.push('/doctor/patients');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
