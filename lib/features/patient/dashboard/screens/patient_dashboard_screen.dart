import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/doctor_model.dart';
import '../../../../data/models/medication_model.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/vital_model.dart';
import '../../../../data/models/reminder_model.dart';
import '../../../../data/models/report_model.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/doctor_card.dart';
import '../../../../core/widgets/medication_card.dart';
import '../../../../core/widgets/appointment_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/notification_sheet.dart';
import '../../../../core/widgets/primary_button.dart';

class PatientDashboardScreen extends ConsumerStatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  ConsumerState<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends ConsumerState<PatientDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = ref.watch(currentUidProvider);

    // Watch real-time Firestore stream providers
    final streamAppts = ref.watch(appointmentsStreamProvider).valueOrNull ?? [];
    final streamMeds = ref.watch(medicationsStreamProvider).valueOrNull ?? [];
    final streamVitals = ref.watch(vitalsStreamProvider).valueOrNull ?? [];
    final streamReports = ref.watch(reportsStreamProvider).valueOrNull ?? [];
    final List<DoctorModel> doctors = ref.watch(doctorsStreamProvider).valueOrNull ?? ref.watch(doctorsProvider);
    final notifications = ref.watch(notificationsStreamProvider).valueOrNull ?? [];
    final unreadCount = notifications.where((n) => !n.isRead).length;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ref, unreadCount, isDark),
              const SizedBox(height: 16),
              AppSearchBar(
                readOnly: true,
                hintText: 'Search specialists, symptoms, clinics...',
                onTap: () => context.push('/patient/dashboard/doctor-search'),
                onFilterTap: () => context.push('/patient/dashboard/doctor-search'),
              ),
              const SizedBox(height: 20),

              // 1. Health Records Upload Card
              _buildUploadRecordsBanner(context, isDark, uid),
              const SizedBox(height: 20),

              // 2. Today's Insights & AI Care Tip
              _buildTodayInsightsCard(context, isDark, streamVitals, streamMeds, streamReports),
              const SizedBox(height: 24),

              // 3. Quick Action Row
              _buildQuickActionsRow(context, isDark, uid),
              const SizedBox(height: 24),

              // 4. Vitals Overview
              _buildVitalsSection(context, isDark, uid, streamVitals),
              const SizedBox(height: 24),

              // 5. Today's Medications
              _buildTodayMedication(context, isDark, uid, streamMeds),
              const SizedBox(height: 24),

              // 6. Care Coordination / Next Appointment
              if (nextAppointment != null) ...[
                _buildNextAppointment(context, nextAppointment),
                const SizedBox(height: 24),
              ],

              // 7. Find Specialists
              if (doctors.isNotEmpty) ...[
                _buildNearbyDoctors(context, doctors),
                const SizedBox(height: 24),
              ],
            ],
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
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
  ) {
    String insightText = 'Your baseline health parameters are steady. Maintain daily hydration and active movement.';
    String traditionalNuskha = 'Warm ginger & honey water is traditionally suggested to soothe throat and support digestion.';

    if (vitals.isNotEmpty) {
      final latest = vitals.first;
      if (latest.heartRate != null && latest.heartRate! > 95) {
        insightText = 'Your heart rate was slightly elevated (${latest.heartRate} bpm). Ensure adequate rest and avoid heavy caffeine today.';
        traditionalNuskha = 'Chamomile infusion or breathing exercises are traditionally helpful to promote relaxation.';
      } else if (latest.systolic != null && latest.systolic! > 135) {
        insightText = 'Blood pressure is tracking at ${latest.systolic}/${latest.diastolic}. Maintain low sodium intake and regular medication.';
        traditionalNuskha = 'Hibiscus tea and garlic infusion have traditional usage for vascular support.';
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
                    Text(
                      'Traditional Care Suggestion / Nuskha',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
    return Row(
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
    final hr = vitals.isNotEmpty ? vitals.first.heartRate : 74;
    final bp = vitals.isNotEmpty ? '${vitals.first.systolic}/${vitals.first.diastolic}' : '120/80';
    final spo2 = vitals.isNotEmpty ? vitals.first.spo2 : 98;
    final weight = vitals.isNotEmpty && vitals.first.weight != null ? vitals.first.weight! : 68.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Continuous Vitals'),
            TextButton.icon(
              onPressed: () => _showLogVitalsSheet(context, isDark, uid),
              icon: const Icon(LucideIcons.plus, size: 14),
              label: const Text('Add Reading', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildVitalItem('Heart Rate', '$hr bpm', LucideIcons.heart, AppColors.danger, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildVitalItem('Blood Pressure', bp, LucideIcons.gauge, AppColors.primaryBlue, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildVitalItem('SpO₂', '$spo2%', LucideIcons.wind, AppColors.accentCyan, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildVitalItem('Weight', '$weight kg', LucideIcons.scale, AppColors.success, isDark)),
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
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
            textAlign: TextAlign.center,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Today\'s Medications'),
            TextButton(
              onPressed: () => context.push('/patient/timeline'),
              child: const Text('View All', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (medications.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            child: Row(
              children: [
                const Icon(LucideIcons.pill, color: AppColors.muted, size: 24),
                const SizedBox(width: 12),
                Text(
                  'No scheduled medications for today.',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...medications.take(3).map(
                (med) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MedicationCard(
                    name: med.name,
                    dosage: med.dosage,
                    time: med.time,
                    isTaken: med.isTaken,
                    onMarkAsTaken: () {
                      if (uid != null) {
                        ref.read(medicationRepositoryProvider).markTaken(uid, med.id);
                      }
                    },
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildNextAppointment(BuildContext context, AppointmentModel appointment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Care Coordination & Consultations'),
            TextButton(
              onPressed: () => context.push('/patient/timeline'),
              child: const Text('Timeline', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Available Specialists'),
            TextButton(
              onPressed: () => context.push('/patient/dashboard/doctor-search'),
              child: const Text('See all', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                  Text('Ingest medical records for continuous AI analysis and timeline tracking.', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText, fontSize: 12)),
                  const SizedBox(height: 16),
                  
                  // Category Dropdown
                  DropdownButtonFormField<ReportCategory>(
                    initialValue: selectedCategory,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    decoration: InputDecoration(
                      labelText: 'Document Type',
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
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Document Title (e.g. Complete Blood Count, Hospital Discharge)',
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
                    label: 'Save & Ingest Record',
                    icon: LucideIcons.check,
                    onPressed: () async {
                      if (uid == null || titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a document title')));
                        return;
                      }

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

                      await ref.read(reportRepositoryProvider).uploadReport(report);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Record uploaded and added to Care Timeline!')),
                        );
                      }
                    },
                  ),
                ],
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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
          );
        },
      ),
    );
  }
}
