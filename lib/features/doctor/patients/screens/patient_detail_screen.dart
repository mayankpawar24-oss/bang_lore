import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/patient_model.dart';
import '../../../../data/models/permission_request_model.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streamPatient = ref.watch(patientStreamProvider(widget.patientId)).valueOrNull;
    final perm = ref.watch(patientPermissionStreamProvider(widget.patientId)).valueOrNull;
    final patients = ref.watch(patientsProvider);
    final currentPatient = streamPatient ??
        widget.patient ??
        patients.firstWhere(
          (p) => p.id == widget.patientId,
          orElse: () => MockData.currentPatient,
        );

    final isAuthorized = (perm?.status == PermissionStatus.approved) || (widget.patient?.isAuthorized ?? false);

    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
        appBar: AppBar(
          title: Text(
            'Access Restricted',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : AppColors.navy),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: isDark ? 0.25 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.lock, size: 56, color: AppColors.warning),
                ),
                const SizedBox(height: 20),
                Text(
                  'Patient Authorization Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Request permission from ${currentPatient.name} to view continuous health records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: perm?.status == PermissionStatus.pending ? 'Access Requested (Pending)' : 'Request Access',
                  icon: LucideIcons.send,
                  isFullWidth: false,
                  onPressed: perm?.status == PermissionStatus.pending
                      ? null
                      : () async {
                          final docUid = ref.read(currentUidProvider);
                          if (docUid != null) {
                            await ref.read(patientRepositoryProvider).requestAccess(
                                  docUid,
                                  widget.patientId,
                                  permissions: const ['profile', 'vitals', 'medications', 'appointments', 'medicalHistory', 'familyHistory', 'reports', 'aiChat'],
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Access request sent to patient')),
                              );
                            }
                          }
                        },
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  text: 'Go Back',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final adherenceColor = currentPatient.medicationAdherence >= 80
        ? AppColors.success
        : (currentPatient.medicationAdherence >= 60 ? AppColors.warning : AppColors.danger);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      appBar: AppBar(
        title: Text(
          'Patient Health Brief',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.navy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : AppColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Header Card
            AppCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              elevation: 1,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                        : AppColors.softBlue,
                    child: Text(
                      currentPatient.name.isNotEmpty ? currentPatient.name[0] : 'P',
                      style: const TextStyle(
                        fontSize: 26,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentPatient.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.navy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currentPatient.age} yrs • ${currentPatient.condition}',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StatusChip(label: currentPatient.status.toUpperCase(), status: currentPatient.status),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.05),
            const SizedBox(height: 20),

            // Medication Adherence Section
            const SectionHeader(title: 'Medication Adherence'),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 20,
              elevation: 1,
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
                          backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.softBlue,
                          color: adherenceColor,
                          strokeWidth: 8,
                        ),
                      ),
                      Text(
                        '${currentPatient.medicationAdherence.toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: adherenceColor,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentPatient.medicationAdherence >= 80
                              ? 'Optimal Adherence'
                              : 'Intervention Recommended',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: adherenceColor,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tracked continuous medication intake across 30 days.',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 20),

            // Recent Vitals Grid
            const SectionHeader(title: 'Current Vitals'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildVitalTile('Heart Rate', '${currentPatient.vitals?['hr'] ?? 74} bpm', LucideIcons.activity, AppColors.danger, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildVitalTile('SpO₂', '${currentPatient.vitals?['spo2'] ?? 98}%', LucideIcons.wind, AppColors.primaryBlue, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildVitalTile('Weight', '${currentPatient.vitals?['weight'] ?? 68} kg', LucideIcons.scale, AppColors.success, isDark)),
              ],
            ).animate().fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 20),

            // Family Medical Context
            const SectionHeader(title: 'Generational Family History', subtitle: 'Hereditary risk indicators'),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 20,
              elevation: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.dna, color: AppColors.primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Father — Coronary artery disease',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.dna, color: AppColors.accentCyan, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Grandmother — Hypertension, Type 2 Diabetes',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: isDark ? const Color(0xFF334155) : AppColors.border),
                  const Text(
                    'Family history context — not a clinical diagnosis.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryBlue,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions Section
            const SectionHeader(title: 'Doctor Actions'),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Schedule Appointment',
              icon: LucideIcons.calendar,
              onPressed: () => _showAppointmentSheet(context, currentPatient.name, isDark),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'Send Reminder',
                    icon: LucideIcons.bell,
                    onPressed: () => _showReminderSheet(context, isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryButton(
                    text: 'View Records',
                    icon: LucideIcons.fileText,
                    onPressed: () => _showRecordsSheet(context, currentPatient.name, isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalTile(String label, String value, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      elevation: 0.5,
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
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _showAppointmentSheet(BuildContext context, String patientName, bool isDark) {
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
              'Schedule Consultation with $patientName',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Consultation Reason', hintText: 'e.g. ECG Review')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Confirm Consultation Slot',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appointment scheduled!'), backgroundColor: AppColors.primaryBlue),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReminderSheet(BuildContext context, bool isDark) {
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
              'Send Patient Care Reminder',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Reminder Message', hintText: 'e.g. Take evening BP reading')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Send Push Reminder',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reminder sent to patient!'), backgroundColor: AppColors.primaryBlue),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordsSheet(BuildContext context, String patientName, bool isDark) {
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
              'Medical Records — $patientName',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue),
              title: Text('Comprehensive Blood Panel (Aug 15)', style: TextStyle(color: isDark ? Colors.white : AppColors.navy)),
              trailing: const Icon(LucideIcons.download),
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue),
              title: Text('12-Lead Electrocardiogram (Aug 10)', style: TextStyle(color: isDark ? Colors.white : AppColors.navy)),
              trailing: const Icon(LucideIcons.download),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
