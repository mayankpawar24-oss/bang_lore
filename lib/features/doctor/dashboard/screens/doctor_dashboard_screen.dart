import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/notification_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(patientsProvider.notifier).loadPatients();
            if (authState.user != null) {
              ref.read(appointmentsProvider.notifier).loadAppointments(authState.user!.id);
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.softBlue,
                          backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=aisha'),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good morning, Dr. ${authState.user?.name.split(' ').last ?? 'Patel'} 👋',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Cardiology • City Heart Center',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => NotificationSheet.show(context),
                      icon: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.navy.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(LucideIcons.bell, color: AppColors.navy, size: 20),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                    _buildStatCard('Active Patients', activePatients.length.toString(), LucideIcons.users, AppColors.primaryBlue),
                    _buildStatCard('Appts Today', todayAppointments.length.toString(), LucideIcons.calendar, AppColors.success),
                    _buildStatCard('Needs Attention', needsAttention.length.toString(), LucideIcons.alertTriangle, AppColors.warning),
                    _buildStatCard('Available Slots', '8', LucideIcons.clock, AppColors.accentCyan),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                const SizedBox(height: 24),

                // Quick Actions Bar
                const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickActionButton('Add Appt', LucideIcons.plusCircle, AppColors.primaryBlue, () => _showAddAppointmentModal(context)),
                      _buildQuickActionButton('Add Patient', LucideIcons.userPlus, AppColors.success, () => _showAddPatientModal(context)),
                      _buildQuickActionButton('Send Alert', LucideIcons.bellRing, AppColors.danger, () => _showSendAlertModal(context)),
                      _buildQuickActionButton('Add Reminder', LucideIcons.clock, AppColors.warning, () => _showAddReminderModal(context)),
                      _buildQuickActionButton('View Reports', LucideIcons.fileText, const Color(0xFF8B5CF6), () => _showReportsModal(context)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Patients Needing Attention Section
                if (needsAttention.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Patients Needing Attention', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      TextButton(
                        onPressed: () => context.go('/doctor/patients'),
                        child: const Text('View All', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...needsAttention.map((patient) => _buildAttentionCard(context, patient, appointments)),
                  const SizedBox(height: 24),
                ],

                // Today's Schedule Stream
                const Text("Today's Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 12),
                if (todayAppointments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: const Center(
                      child: Text('No more consultations scheduled for today.', style: TextStyle(color: AppColors.secondaryText)),
                    ),
                  )
                else
                  ...todayAppointments.map((appt) => _buildScheduleTile(appt)),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                  color: color.withValues(alpha: 0.12),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionCard(BuildContext context, PatientModel patient, List<AppointmentModel> appointments) {
    final isCritical = patient.status == 'critical';
    final color = isCritical ? AppColors.danger : AppColors.warning;

    return GestureDetector(
      onTap: () => context.push('/doctor/patients/patient/${patient.id}', extra: patient),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(patient.name[0], style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text('${patient.condition} • Adherence ${patient.medicationAdherence.toInt()}%', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isCritical ? 'CRITICAL' : 'ATTENTION',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTile(AppointmentModel appt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.stethoscope, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appt.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                const SizedBox(height: 2),
                Text('${appt.specialty} • ${_formatTime(appt.dateTime)}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(10)),
            child: const Text('CONFIRMED', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // Modals for Quick Actions
  void _showAddAppointmentModal(BuildContext context) {
    final patientCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Book Doctor Appointment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            TextField(controller: patientCtrl, decoration: const InputDecoration(labelText: 'Patient Name', hintText: 'e.g. Margaret Chen')),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment scheduled!'), backgroundColor: AppColors.primaryBlue));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPatientModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Patient', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Patient Full Name')),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Primary Condition')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Send Access Request',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access request sent to patient!'), backgroundColor: AppColors.primaryBlue));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSendAlertModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send Patient Alert Notification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Alert Message', hintText: 'e.g. Please check your blood pressure now.')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Broadcast Alert',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert broadcasted to patient app!'), backgroundColor: AppColors.danger));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReminderModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Doctor Follow-up Reminder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Reminder Note', hintText: 'e.g. Follow up on ECG report')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Doctor Reminder',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Follow-up reminder set!'), backgroundColor: AppColors.primaryBlue));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Medical Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue), title: const Text('Margaret Chen - Blood Test (Aug 15)'), trailing: const Icon(LucideIcons.download)),
            ListTile(leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue), title: const Text('Margaret Chen - ECG Trace (Aug 10)'), trailing: const Icon(LucideIcons.download)),
            ListTile(leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue), title: const Text('Emily Davis - Chest X-Ray (Aug 12)'), trailing: const Icon(LucideIcons.download)),
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
