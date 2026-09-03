import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/medication_model.dart';
import '../../../../data/models/vital_model.dart';
import '../../../../data/models/report_model.dart';

class SupportingInsightCards extends StatelessWidget {
  final List<VitalModel> vitals;
  final List<MedicationModel> medications;
  final List<AppointmentModel> appointments;
  final List<ReportModel> reports;
  final VoidCallback onUploadTap;

  const SupportingInsightCards({
    super.key,
    required this.vitals,
    required this.medications,
    required this.appointments,
    required this.reports,
    required this.onUploadTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Vitals data extraction
    final hrVital = vitals.where((v) => v.heartRate != null).toList();
    final bpVital = vitals.where((v) => v.systolic != null && v.diastolic != null).toList();
    final hrValue = hrVital.isNotEmpty ? '${hrVital.first.heartRate} bpm' : '72 bpm';
    final bpValue = bpVital.isNotEmpty ? '${bpVital.first.systolic}/${bpVital.first.diastolic}' : '120/80';

    // Meds data
    final totalMeds = medications.length;
    final takenMeds = medications.where((m) => m.isTaken).length;

    // Next appointment
    AppointmentModel? nextAppt;
    final upcoming = appointments.where((a) =>
        a.dateTime.isAfter(DateTime.now()) &&
        a.status != AppointmentStatus.cancelled &&
        a.status != AppointmentStatus.rejected).toList();
    if (upcoming.isNotEmpty) {
      upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      nextAppt = upcoming.first;
    }

    return Column(
      children: [
        Row(
          children: [
            // Card 1: Vitals Status
            Expanded(
              child: _buildTile(
                context,
                isDark: isDark,
                icon: LucideIcons.heartPulse,
                iconColor: const Color(0xFFEF4444),
                iconBg: const Color(0xFFEF4444).withValues(alpha: 0.12),
                title: 'Vitals Status',
                primaryMetric: hrValue,
                subMetric: 'BP: $bpValue',
                badgeText: 'STABLE',
                badgeColor: AppColors.success,
                onTap: () => context.push('/patient/timeline'),
              ),
            ),
            const SizedBox(width: 12),
            // Card 2: Medications
            Expanded(
              child: _buildTile(
                context,
                isDark: isDark,
                icon: LucideIcons.pill,
                iconColor: AppColors.primaryBlue,
                iconBg: AppColors.primaryBlue.withValues(alpha: 0.12),
                title: 'Medication',
                primaryMetric: totalMeds > 0 ? '$takenMeds of $totalMeds' : '3 Active',
                subMetric: 'Daily protocol',
                badgeText: takenMeds == totalMeds && totalMeds > 0 ? 'COMPLETE' : 'ON TRACK',
                badgeColor: AppColors.primaryBlue,
                onTap: () => context.push('/patient/timeline'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Card 3: Care Coordination
            Expanded(
              child: _buildTile(
                context,
                isDark: isDark,
                icon: LucideIcons.calendar,
                iconColor: const Color(0xFF8B5CF6),
                iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                title: 'Consultation',
                primaryMetric: nextAppt != null
                    ? DateFormat('d MMM, h:mm a').format(nextAppt.dateTime)
                    : 'Schedule',
                subMetric: nextAppt != null ? nextAppt.doctorName : 'Specialist care',
                badgeText: nextAppt != null ? 'UPCOMING' : 'BOOK',
                badgeColor: const Color(0xFF8B5CF6),
                onTap: () => context.push('/patient/dashboard/doctor-search'),
              ),
            ),
            const SizedBox(width: 12),
            // Card 4: Health Records
            Expanded(
              child: _buildTile(
                context,
                isDark: isDark,
                icon: LucideIcons.fileText,
                iconColor: const Color(0xFF0EA5E9),
                iconBg: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                title: 'Clinical Records',
                primaryMetric: '${reports.length} Reports',
                subMetric: 'Encrypted storage',
                badgeText: 'UPLOAD',
                badgeColor: const Color(0xFF0EA5E9),
                onTap: onUploadTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String primaryMetric,
    required String subMetric,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 135,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.border.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(icon, color: iconColor, size: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      primaryMetric,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    Text(
                      subMetric,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF64748B) : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
