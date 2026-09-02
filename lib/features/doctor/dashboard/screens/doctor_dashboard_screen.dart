import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/notification_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
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
    final patients = ref.watch(patientsProvider);
    final appointments = ref.watch(appointmentsProvider);
    final authState = ref.watch(authProvider);

    final activePatients = patients.where((p) => p.isAuthorized).toList();
    final needsAttention = activePatients.where((p) => p.status == 'attention' || p.status == 'critical').toList();

    final now = DateTime.now();
    final todayAppointments = appointments.where((a) {
      return a.dateTime.year == now.year && a.dateTime.month == now.month && a.dateTime.day == now.day;
    }).toList();

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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, authState.user?.name, isDark),
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
                    _buildStatCard('Available Slots', '8', LucideIcons.clock, AppColors.accentCyan, isDark),
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

  Widget _buildHeader(BuildContext context, String? doctorName, bool isDark) {
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
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E293B) : AppColors.softBlue,
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.white,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: (streamDoctor != null && streamDoctor.avatarUrl.isNotEmpty)
                    ? Image.network(streamDoctor.avatarUrl, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          displayName.replaceAll('Dr. ', '').split(' ').first.isNotEmpty
                              ? displayName.replaceAll('Dr. ', '').split(' ').first[0]
                              : 'D',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
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
                    child: const Center(
                      child: Text(
                        '3',
                        style: TextStyle(
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
  void _showAddAppointmentModal(BuildContext context, bool isDark) {
    final patientCtrl = TextEditingController();
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
              'Book Doctor Appointment',
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
                labelText: 'Patient Name',
                hintText: 'e.g. Margaret Chen',
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Confirm Appointment Slot',
              onPressed: () {
                if (patientCtrl.text.isNotEmpty) {
                  final appt = AppointmentModel(
                    id: const Uuid().v4(),
                    patientId: 'p_margaret_01',
                    doctorId: 'd_aisha_01',
                    doctorName: 'Dr. Aisha Patel',
                    patientName: patientCtrl.text,
                    specialty: 'Cardiology Follow-up',
                    dateTime: DateTime.now().add(const Duration(hours: 3)),
                    durationMinutes: 30,
                    status: AppointmentStatus.scheduled,
                  );
                  ref.read(appointmentsProvider.notifier).bookAppointment(appt);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Appointment scheduled!'),
                      backgroundColor: AppColors.primaryBlue,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPatientModal(BuildContext context, bool isDark) {
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
              'Add New Patient',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Patient Full Name')),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Primary Condition')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Send Access Request',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Access request sent to patient!'),
                    backgroundColor: AppColors.primaryBlue,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSendAlertModal(BuildContext context, bool isDark) {
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
              'Send Patient Alert Notification',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Alert Message',
                hintText: 'e.g. Please check your blood pressure now.',
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Broadcast Alert',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alert broadcasted to patient app!'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReminderModal(BuildContext context, bool isDark) {
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
              'Add Doctor Follow-up Reminder',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Reminder Note',
                hintText: 'e.g. Follow up on ECG report',
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Doctor Reminder',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Follow-up reminder set!'),
                    backgroundColor: AppColors.primaryBlue,
                  ),
                );
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
              'Recent Medical Reports',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue),
              title: Text('Margaret Chen - Blood Test (Aug 15)', style: TextStyle(color: isDark ? Colors.white : AppColors.navy)),
              trailing: const Icon(LucideIcons.download),
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue),
              title: Text('Margaret Chen - ECG Trace (Aug 10)', style: TextStyle(color: isDark ? Colors.white : AppColors.navy)),
              trailing: const Icon(LucideIcons.download),
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue),
              title: Text('Emily Davis - Chest X-Ray (Aug 12)', style: TextStyle(color: isDark ? Colors.white : AppColors.navy)),
              trailing: const Icon(LucideIcons.download),
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
