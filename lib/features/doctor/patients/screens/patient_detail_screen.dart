import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/patient_model.dart';
import '../../../../data/mock/mock_data.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final String patientId;
  final PatientModel? patient;

  const PatientDetailScreen({super.key, required this.patientId, this.patient});

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final currentPatient = widget.patient ??
        patients.firstWhere(
          (p) => p.id == widget.patientId,
          orElse: () => MockData.currentPatient,
        );

    if (!currentPatient.isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Access Restricted')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.lock, size: 64, color: AppColors.warning),
              const SizedBox(height: 16),
              const Text('Patient Authorization Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 8),
              const Text('Request permission to view medical records.', style: TextStyle(color: AppColors.secondaryText)),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Go Back',
                isFullWidth: false,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      );
    }

    final adherenceColor = currentPatient.medicationAdherence >= 80
        ? AppColors.success
        : (currentPatient.medicationAdherence >= 60 ? AppColors.warning : AppColors.danger);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Health Brief', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.softBlue,
                    child: Text(
                      currentPatient.name[0],
                      style: const TextStyle(fontSize: 28, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentPatient.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currentPatient.age} yrs • ${currentPatient.condition}',
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        StatusChip(label: currentPatient.status.toUpperCase(), status: currentPatient.status),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.05),
            const SizedBox(height: 24),

            // Medication Adherence Section
            const SectionHeader(title: 'Medication Adherence'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 64,
                        width: 64,
                        child: CircularProgressIndicator(
                          value: currentPatient.medicationAdherence / 100,
                          backgroundColor: AppColors.softBlue,
                          color: adherenceColor,
                          strokeWidth: 8,
                        ),
                      ),
                      Text(
                        '${currentPatient.medicationAdherence.toInt()}%',
                        style: TextStyle(fontWeight: FontWeight.bold, color: adherenceColor, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentPatient.medicationAdherence >= 80 ? 'Optimal Adherence' : 'Intervention Recommended',
                          style: TextStyle(fontWeight: FontWeight.bold, color: adherenceColor, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tracked continuous medication intake across 30 days.',
                          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 24),

            // Recent Vitals Grid
            const SectionHeader(title: 'Current Vitals'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildVitalTile('Heart Rate', '${currentPatient.vitals?['hr'] ?? 74} bpm', LucideIcons.activity, AppColors.danger)),
                const SizedBox(width: 10),
                Expanded(child: _buildVitalTile('SpO₂', '${currentPatient.vitals?['spo2'] ?? 98}%', LucideIcons.wind, AppColors.primaryBlue)),
                const SizedBox(width: 10),
                Expanded(child: _buildVitalTile('Weight', '${currentPatient.vitals?['weight'] ?? 68} kg', LucideIcons.scale, AppColors.success)),
              ],
            ).animate().fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 24),

            // Family Medical Context
            const SectionHeader(title: 'Generational Family History', subtitle: 'Hereditary risk indicators'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.softBlue.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('• Father — Coronary artery disease', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('• Grandmother — Hypertension, Type 2 Diabetes', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 14)),
                  Divider(height: 20),
                  Text(
                    'Family history context — not a diagnosis.',
                    style: TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions Section
            const SectionHeader(title: 'Doctor Actions'),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Schedule Appointment',
              icon: LucideIcons.calendar,
              onPressed: () => _showAppointmentSheet(context, currentPatient.name),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReminderSheet(context),
                    icon: const Icon(LucideIcons.bell, color: AppColors.primaryBlue, size: 18),
                    label: const Text('Send Reminder', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: AppColors.primaryBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRecordsSheet(context, currentPatient.name),
                    icon: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue, size: 18),
                    label: const Text('View Records', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: AppColors.primaryBlue),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
        ],
      ),
    );
  }

  void _showAppointmentSheet(BuildContext context, String patientName) {
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
            Text('Schedule Consultation for $patientName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Consultation Reason', hintText: 'Follow-up / ECG check')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Confirm Schedule',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Consultation booked for $patientName!'), backgroundColor: AppColors.primaryBlue));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReminderSheet(BuildContext context) {
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
            const Text('Send Patient Medication Reminder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Reminder Message', hintText: 'Take Furosemide 40mg at 6 PM')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Send Direct Reminder',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder sent to patient app!'), backgroundColor: AppColors.primaryBlue));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordsSheet(BuildContext context, String patientName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$patientName Medical Records', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue), title: const Text('Blood Test Panel (Aug 15)'), trailing: const Icon(LucideIcons.eye)),
            ListTile(leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue), title: const Text('12-Lead ECG Report (Aug 10)'), trailing: const Icon(LucideIcons.eye)),
            ListTile(leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue), title: const Text('Echocardiogram Summary (Jul 28)'), trailing: const Icon(LucideIcons.eye)),
          ],
        ),
      ),
    );
  }
}
