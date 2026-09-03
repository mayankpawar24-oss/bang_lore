import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/patient_model.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/permission_request_model.dart';
import '../../../../data/models/ai_chat_model.dart';
import '../../../../data/models/report_model.dart';
import '../../../../data/models/activity_log_model.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final String patientId;
  final PatientModel? patient;

  const PatientDetailScreen({super.key, required this.patientId, this.patient});

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  Future<void> _toggleAdmissionStatus(PatientModel patient) async {
    final newStatus = patient.isAdmitted ? 'discharged' : 'admitted';
    final isAdmitting = newStatus == 'admitted';

    try {
      final db = FirebaseFirestore.instance;
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isAdmitting) {
        updateData['admittedAt'] = FieldValue.serverTimestamp();
      } else {
        updateData['dischargedAt'] = FieldValue.serverTimestamp();
      }

      await db.collection('patients').doc(patient.id).update(updateData);

      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await ref.read(activityLogServiceProvider).logEvent(
        patientId: patient.id,
        eventType: ActivityEventType.admissionChanged,
        title: isAdmitting ? 'Patient Admitted' : 'Patient Discharged',
        description: isAdmitting
            ? 'Admitted for in-hospital observation and clinical management.'
            : 'Discharged from in-hospital care to outpatient monitoring.',
        actorUid: currentUid,
        actorRole: 'doctor',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAdmitting ? 'Patient marked as Admitted.' : 'Patient discharged.'),
            backgroundColor: isAdmitting ? AppColors.primaryBlue : AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update admission status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadDocumentForPatient(PatientModel patient) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'txt'],
      );

      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();

      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final report = ReportModel(
        id: '',
        patientId: patient.id,
        title: file.name.split('.').first,
        category: ReportCategory.emr,
        date: DateTime.now(),
        doctorOrFacility: 'Attending Physician',
        summary: 'In-hospital clinical document uploaded during admission.',
        uploadedBy: currentUid,
        uploaderId: currentUid,
        uploaderRole: 'doctor',
      );

      await ref.read(reportRepositoryProvider).uploadReport(
        report,
        fileBytes: bytes,
        fileName: file.name,
        fileType: file.extension == 'pdf' ? 'application/pdf' : 'image/${file.extension}',
        uploaderRole: 'doctor',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded & OCR processed successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
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
          orElse: () => PatientModel(
            id: widget.patientId,
            name: 'Patient ${widget.patientId.length > 6 ? widget.patientId.substring(0, 6) : widget.patientId}',
            age: 30,
            condition: 'Medical Consultation',
            status: 'stable',
            isAuthorized: false,
            conditions: const ['Medical Consultation'],
            medicationAdherence: 100.0,
          ),
        );

    final isAuthorized = (perm != null && perm.status == PermissionStatus.approved) ||
        (perm == null && (widget.patient?.isAuthorized ?? false));

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
                          final docUid = FirebaseAuth.instance.currentUser?.uid ?? ref.read(currentUidProvider);
                          if (docUid != null && docUid.isNotEmpty) {
                            dev.log('[ACCESS] Doctor $docUid requesting access to patient ${widget.patientId}', name: 'PatientDetailScreen');
                            try {
                              await ref.read(patientRepositoryProvider).requestAccess(
                                    docUid,
                                    widget.patientId,
                                    permissions: const ['profile', 'vitals', 'medications', 'appointments', 'medicalHistory', 'familyHistory', 'reports', 'aiChat'],
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Access request sent to ${currentPatient.name}'),
                                    backgroundColor: AppColors.primaryBlue,
                                  ),
                                );
                              }
                            } catch (e) {
                              dev.log('[ACCESS] [FIRESTORE] Exception requesting access: $e', name: 'PatientDetailScreen');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to request access: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
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

    final hasVitalsPerm = perm == null || perm.hasPermission('vitals');
    final hasMedsPerm = perm == null || perm.hasPermission('medications');
    final hasHistoryPerm = perm == null || perm.hasPermission('familyHistory');
    final hasReportsPerm = perm == null || perm.hasPermission('reports');
    final hasChatPerm = perm?.hasPermission('aiChat') ?? false;

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
            const SizedBox(height: 16),

            // In-Hospital Care / Admission Card
            AppCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 20,
              elevation: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            currentPatient.isAdmitted ? LucideIcons.bedDouble : LucideIcons.home,
                            size: 20,
                            color: currentPatient.isAdmitted ? AppColors.danger : AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            currentPatient.isAdmitted ? 'Inpatient (Admitted)' : 'Outpatient (Discharged)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        icon: Icon(
                          currentPatient.isAdmitted ? LucideIcons.logOut : LucideIcons.logIn,
                          size: 16,
                          color: currentPatient.isAdmitted ? AppColors.success : AppColors.primaryBlue,
                        ),
                        label: Text(
                          currentPatient.isAdmitted ? 'Discharge' : 'Mark Admitted',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: currentPatient.isAdmitted ? AppColors.success : AppColors.primaryBlue,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: currentPatient.isAdmitted ? AppColors.success : AppColors.primaryBlue,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _toggleAdmissionStatus(currentPatient),
                      ),
                    ],
                  ),
                  if (currentPatient.isAdmitted) ...[
                    const SizedBox(height: 12),
                    Divider(color: isDark ? const Color(0xFF334155) : AppColors.border),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Patient is currently admitted. Inpatient clinical records and notes can be uploaded.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(LucideIcons.uploadCloud, size: 16, color: Colors.white),
                          label: const Text('Upload Doc', style: TextStyle(color: Colors.white, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: () => _uploadDocumentForPatient(currentPatient),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 20),

            // Medication Adherence Section
            const SectionHeader(title: 'Medication Adherence'),
            const SizedBox(height: 12),
            if (hasMedsPerm)
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
              ).animate().fadeIn().slideY(begin: 0.05)
            else
              AppCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                elevation: 1,
                child: Row(
                  children: [
                    const Icon(LucideIcons.lock, size: 20, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Medication adherence records not shared by patient.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Recent Vitals Grid
            const SectionHeader(title: 'Current Vitals'),
            const SizedBox(height: 12),
            if (hasVitalsPerm)
              Row(
                children: [
                  Expanded(child: _buildVitalTile('Heart Rate', '${currentPatient.vitals?['hr'] ?? 74} bpm', LucideIcons.activity, AppColors.danger, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildVitalTile('SpO₂', '${currentPatient.vitals?['spo2'] ?? 98}%', LucideIcons.wind, AppColors.primaryBlue, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildVitalTile('Weight', '${currentPatient.vitals?['weight'] ?? 68} kg', LucideIcons.scale, AppColors.success, isDark)),
                ],
              ).animate().fadeIn().slideY(begin: 0.05)
            else
              AppCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                elevation: 1,
                child: Row(
                  children: [
                    const Icon(LucideIcons.lock, size: 20, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vitals telemetry access not shared by patient.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Family Medical Context
            const SectionHeader(title: 'Generational Family History', subtitle: 'Hereditary risk indicators'),
            const SizedBox(height: 12),
            if (hasHistoryPerm)
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
              )
            else
              AppCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                elevation: 1,
                child: Row(
                  children: [
                    const Icon(LucideIcons.lock, size: 20, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Generational family history access not shared by patient.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          fontSize: 13,
                        ),
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
                    icon: hasReportsPerm ? LucideIcons.fileText : LucideIcons.lock,
                    onPressed: hasReportsPerm
                        ? () => _showRecordsSheet(context, currentPatient.name, isDark)
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Medical records permission not granted by patient.'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: hasChatPerm ? 'Chat History' : 'Chat History (Locked)',
                    icon: hasChatPerm ? LucideIcons.messagesSquare : LucideIcons.lock,
                    onPressed: () => _showChatHistorySheet(
                      context,
                      currentPatient.id,
                      currentPatient.name,
                      hasChatPerm,
                      isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryButton(
                    text: 'Video Call',
                    icon: LucideIcons.video,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Telehealth video consultation room link is generated 15 minutes prior to scheduled appointments.'),
                          backgroundColor: AppColors.primaryBlue,
                        ),
                      );
                    },
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
    final reasonCtrl = TextEditingController(text: 'Clinical Consultation Follow-up');
    final currentDoctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doctorName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Doctor';

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
              'Schedule Consultation with $patientName',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Consultation Reason', hintText: 'e.g. ECG Review'),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Confirm Consultation Slot',
              onPressed: () async {
                final apptId = const Uuid().v4();
                final appt = AppointmentModel(
                  id: apptId,
                  patientId: widget.patientId,
                  doctorId: currentDoctorUid,
                  doctorName: doctorName,
                  patientName: patientName,
                  specialty: 'Clinical Follow-up',
                  dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
                  durationMinutes: 30,
                  status: AppointmentStatus.approved,
                  notes: reasonCtrl.text.trim(),
                );

                try {
                  await ref.read(appointmentRepositoryProvider).bookAppointment(appt);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Appointment scheduled in Firestore!'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  dev.log('[APPOINTMENT] exception: $e', name: 'PatientDetailScreen');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger),
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

  void _showReminderSheet(BuildContext context, bool isDark) {
    final reminderCtrl = TextEditingController();
    final currentDoctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doctorName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Doctor';

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
              'Send Patient Care Reminder',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reminderCtrl,
              decoration: const InputDecoration(labelText: 'Reminder Message', hintText: 'e.g. Take evening BP reading'),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Send Push Reminder',
              onPressed: () async {
                final text = reminderCtrl.text.trim();
                if (text.isEmpty) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('patients')
                      .doc(widget.patientId)
                      .collection('notifications')
                      .add({
                    'title': 'Doctor Care Reminder',
                    'message': text,
                    'type': 'doctor_reminder',
                    'doctorId': currentDoctorUid,
                    'doctorName': doctorName,
                    'isRead': false,
                    'timestamp': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminder sent to patient!'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  dev.log('[NOTIFICATION] exception: $e', name: 'PatientDetailScreen');
                }
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
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final reportsAsync = ref.watch(patientReportsFamilyStreamProvider(widget.patientId));
          final reports = reportsAsync.valueOrNull ?? [];

          return Padding(
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
                if (reports.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No medical records uploaded for this patient.',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                      ),
                    ),
                  )
                else
                  ...reports.take(5).map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue),
                    title: Text(r.title, style: TextStyle(color: isDark ? Colors.white : AppColors.navy)),
                    subtitle: Text('${r.category.name} • ${r.date.day}/${r.date.month}/${r.date.year}'),
                    trailing: const Icon(LucideIcons.download),
                  )),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showChatHistorySheet(
    BuildContext context,
    String patientId,
    String patientName,
    bool hasChatPerm,
    bool isDark,
  ) {
    dev.log('[CHAT] [ACCESS] Opening chat history for patientId: $patientId, permitted: $hasChatPerm', name: 'PatientDetailScreen');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        if (!hasChatPerm) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: isDark ? 0.25 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.lock, size: 36, color: AppColors.warning),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chat History Restricted',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Patient $patientName has not granted "aiChat" permission. To view AI consultation history, request updated permissions from the patient.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
              ],
            ),
          );
        }

        return Consumer(
          builder: (context, ref, _) {
            final chatsAsync = ref.watch(patientAiChatsFamilyStreamProvider(patientId));
            final chats = chatsAsync.valueOrNull ?? [];

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Consultation History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Permitted chat records for $patientName',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (chatsAsync.isLoading)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (chats.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No AI chat history recorded for this patient.',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        itemBuilder: (context, idx) {
                          final chat = chats[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(LucideIcons.bot, color: AppColors.primaryBlue, size: 20),
                            ),
                            title: Text(
                              chat.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.navy,
                              ),
                            ),
                            subtitle: Text(
                              '${chat.createdAt.day}/${chat.createdAt.month}/${chat.createdAt.year} ${chat.createdAt.hour.toString().padLeft(2, '0')}:${chat.createdAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                              ),
                            ),
                            trailing: const Icon(LucideIcons.chevronRight, size: 18),
                            onTap: () => _showChatMessagesDialog(context, patientId, chat, isDark),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showChatMessagesDialog(BuildContext context, String patientId, AIChat chat, bool isDark) {
    dev.log('[CHAT] [FIRESTORE] Opening messages for chat: ${chat.id} of patient: $patientId', name: 'PatientDetailScreen');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final messagesAsync = ref.watch(patientChatMessagesFamilyStreamProvider((patientId: patientId, chatId: chat.id)));
          final messages = messagesAsync.valueOrNull ?? [];

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        chat.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.navy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
                if (messagesAsync.isLoading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (messages.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No messages in this chat session.',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, idx) {
                        final msg = messages[idx];
                        final isUser = msg.isUser;
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AppColors.primaryBlue
                                  : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isUser ? 'Patient' : 'AI Assistant',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isUser ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg.content,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isUser ? Colors.white : (isDark ? Colors.white : AppColors.navy),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
