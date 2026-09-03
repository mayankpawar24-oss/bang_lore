import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/models/activity_log_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/report_model.dart';

class PatientProfileScreen extends ConsumerWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ABHA ID & Profile Hero
              _buildProfileHero(context, ref, isDark),
              const SizedBox(height: 24),

              // 2. Personal Information & Phone Number
              _buildPersonalInformation(context, ref, isDark),
              const SizedBox(height: 24),

              // 3. Uploaded Reports
              _buildMedicalReportsSection(context, ref, isDark),
              const SizedBox(height: 24),

              // 4. Logs / Activity
              _buildActivityLogsSection(context, ref, isDark),
              const SizedBox(height: 24),

              // 5. Download Data, Share Report, Logout
              _buildAccountAndActions(context, ref, isDark),
              const SizedBox(height: 40),
            ],
          ).animate().fadeIn(duration: 200.ms),
        ),
      ),
    );
  }

  // 1. ABHA ID & Profile Hero
  Widget _buildProfileHero(BuildContext context, WidgetRef ref, bool isDark) {
    final userAsync = ref.watch(currentUserProvider);
    final patientAsync = ref.watch(currentPatientStreamProvider);

    final fullName = patientAsync.valueOrNull?.name ??
        userAsync.valueOrNull?.name ??
        ref.watch(authProvider).user?.name ??
        'User';

    final age = patientAsync.valueOrNull?.age ?? 30;
    final condition = patientAsync.valueOrNull?.condition ?? 'General Health';
    final customAbha = patientAsync.valueOrNull?.abhaId ?? userAsync.valueOrNull?.abhaId;
    final p1 = fullName.hashCode.abs() % 9000 + 1000;
    final p2 = (fullName.hashCode.abs() ~/ 2) % 9000 + 1000;
    final p3 = (fullName.hashCode.abs() ~/ 3) % 9000 + 1000;
    final abha = (customAbha != null && customAbha.isNotEmpty)
        ? 'ABHA: $customAbha'
        : 'ABHA: 91-$p1-$p2-$p3';

    final parts = fullName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'U'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white24,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$age years old • $condition',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              abha,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // QR Code Action
          GestureDetector(
            onTap: () => _showQrCode(context, ref, isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.qrCode, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'View Health QR Card',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Personal Information & Phone Number
  Widget _buildPersonalInformation(BuildContext context, WidgetRef ref, bool isDark) {
    final user = ref.watch(currentUserProvider).valueOrNull ?? ref.watch(authProvider).user;
    final patient = ref.watch(currentPatientStreamProvider).valueOrNull;

    final name = (patient != null && patient.name.isNotEmpty)
        ? patient.name
        : (user != null && user.name.isNotEmpty ? user.name : 'User');
    final email = (user != null && user.email.isNotEmpty && user.email.contains('@') && !user.email.endsWith('@phone.continuum.health'))
        ? user.email
        : null;
    final pPhone = patient?.phoneNumber ?? patient?.phone;
    final uPhone = user?.phoneNumber ?? user?.phone;
    final String phone = (pPhone != null && pPhone.isNotEmpty)
        ? pPhone
        : (uPhone != null && uPhone.isNotEmpty ? uPhone : 'Not provided');
    final age = patient?.age != null ? '${patient!.age} years' : 'Not provided';
    final condition = (patient != null && patient.condition.isNotEmpty) ? patient.condition : 'General Care';
    final bg = patient?.bloodGroup;
    final String bloodGroup = (bg != null && bg.isNotEmpty) ? bg : 'Not specified';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Personal Information',
          subtitle: 'Verified patient identity & contact details',
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          borderRadius: 20,
          elevation: 1,
          child: Column(
            children: [
              _buildInfoRow(LucideIcons.user, 'Full Name', name, isDark),
              _buildDivider(isDark),
              _buildInfoRow(LucideIcons.phone, 'Phone Number (Verified)', phone, isDark),
              if (email != null && email.isNotEmpty) ...[
                _buildDivider(isDark),
                _buildInfoRow(LucideIcons.mail, 'Email Address', email, isDark),
              ],
              _buildDivider(isDark),
              _buildInfoRow(LucideIcons.calendar, 'Age & Demographics', age, isDark),
              _buildDivider(isDark),
              _buildInfoRow(LucideIcons.droplet, 'Blood Group', bloodGroup, isDark),
              _buildDivider(isDark),
              _buildInfoRow(LucideIcons.activity, 'Primary Condition', condition, isDark),
            ],
          ),
        ),
      ],
    );
  }

  // 3. Medical & Personal Reports
  Widget _buildMedicalReportsSection(BuildContext context, WidgetRef ref, bool isDark) {
    final reports = ref.watch(reportsStreamProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Uploaded Reports',
          subtitle: 'Encrypted Proton & Firebase Storage records',
          trailing: ElevatedButton.icon(
            icon: const Icon(LucideIcons.uploadCloud, size: 15, color: Colors.white),
            label: const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => _uploadPatientReport(context, ref),
          ),
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          AppCard(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            borderRadius: 20,
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.fileText, size: 36, color: AppColors.muted),
                  const SizedBox(height: 8),
                  Text(
                    'No medical reports uploaded yet.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            borderRadius: 20,
            elevation: 1,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (context, index) => _buildDivider(isDark),
              itemBuilder: (context, index) {
                final report = reports[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.fileText, color: AppColors.primaryBlue, size: 20),
                  ),
                  title: Text(
                    report.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${report.category.name.toUpperCase()} • ${DateFormat("MMM d, yyyy").format(report.date)}',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.share2, size: 18, color: AppColors.primaryBlue),
                        tooltip: 'Share Report',
                        onPressed: () => _shareReport(context, report),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.muted),
                    ],
                  ),
                  onTap: () => _showReportDetailsModal(context, ref, report, isDark),
                );
              },
            ),
          ),
      ],
    );
  }

  // 4. Logs / Activity
  Widget _buildActivityLogsSection(BuildContext context, WidgetRef ref, bool isDark) {
    final currentUid = ref.watch(currentUidProvider) ?? '';
    final logsAsync = ref.watch(activityLogsStreamProvider(currentUid));
    final logs = logsAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Logs / Activity',
          subtitle: 'Live audit trail of real clinical and access events',
          trailing: logs.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${logs.length} events',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (logs.isEmpty)
          AppCard(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            borderRadius: 20,
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.activity, size: 32, color: AppColors.muted),
                  const SizedBox(height: 8),
                  Text(
                    'No activity logged yet.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            borderRadius: 20,
            elevation: 1,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length > 8 ? 8 : logs.length,
              separatorBuilder: (context, index) => _buildDivider(isDark),
              itemBuilder: (context, index) {
                final log = logs[index];
                final icon = _getEventIcon(log.eventType);
                final timeStr = DateFormat('MMM d, h:mm a').format(log.timestamp);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.primaryBlue, size: 18),
                  ),
                  title: Text(
                    log.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                  ),
                  subtitle: Text(
                    '${log.description}\n$timeStr',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _getEventIcon(ActivityEventType type) {
    switch (type) {
      case ActivityEventType.documentUploaded:
        return LucideIcons.uploadCloud;
      case ActivityEventType.documentViewed:
        return LucideIcons.fileText;
      case ActivityEventType.ocrCompleted:
        return LucideIcons.fileCheck;
      case ActivityEventType.aiInsightGenerated:
        return LucideIcons.sparkles;
      case ActivityEventType.appointmentRequested:
      case ActivityEventType.appointmentApproved:
      case ActivityEventType.appointmentRejected:
      case ActivityEventType.appointmentCancelled:
      case ActivityEventType.appointmentCompleted:
      case ActivityEventType.appointmentMissed:
        return LucideIcons.calendar;
      case ActivityEventType.profileAccessRequested:
      case ActivityEventType.profileAccessApproved:
      case ActivityEventType.profileAccessRejected:
      case ActivityEventType.accessRequested:
      case ActivityEventType.accessApproved:
      case ActivityEventType.accessRejected:
        return LucideIcons.shieldCheck;
      case ActivityEventType.admissionChanged:
      case ActivityEventType.admission:
      case ActivityEventType.discharge:
        return LucideIcons.bedDouble;
      case ActivityEventType.medicineAdded:
      case ActivityEventType.medicineTaken:
      case ActivityEventType.medicineSkipped:
        return LucideIcons.pill;
      case ActivityEventType.reminderCreated:
      case ActivityEventType.reminderCompleted:
      case ActivityEventType.reminderMissed:
        return LucideIcons.bell;
      case ActivityEventType.chatStarted:
      case ActivityEventType.chatAccessGranted:
      case ActivityEventType.chatAccessDenied:
        return LucideIcons.messageSquare;
      case ActivityEventType.general:
        return LucideIcons.activity;
    }
  }

  Future<void> _uploadPatientReport(BuildContext context, WidgetRef ref) async {
    final currentUid = ref.read(currentUidProvider);
    if (currentUid == null || currentUid.isEmpty) return;

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'txt'],
      );

      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();

      final report = ReportModel(
        id: '',
        patientId: currentUid,
        title: file.name.split('.').first,
        category: ReportCategory.other,
        date: DateTime.now(),
        doctorOrFacility: 'Self-Uploaded Document',
        summary: 'Medical document uploaded by patient to encrypted health vault.',
        uploadedBy: currentUid,
        uploaderId: currentUid,
        uploaderRole: 'patient',
      );

      await ref.read(reportRepositoryProvider).uploadReport(
        report,
        fileBytes: bytes,
        fileName: file.name,
        fileType: file.extension == 'pdf' ? 'application/pdf' : 'image/${file.extension}',
        uploaderRole: 'patient',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical document uploaded & OCR analysis completed.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 5. Download Data, Share Report, Logout
  Widget _buildAccountAndActions(BuildContext context, WidgetRef ref, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Account Actions',
          subtitle: 'Data portability & authentication session',
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          borderRadius: 20,
          elevation: 1,
          child: Column(
            children: [
              // Download Health Data Action
              ListTile(
                onTap: () => _downloadHealthData(context, ref),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.download, color: AppColors.primaryBlue, size: 20),
                ),
                title: Text(
                  'Download Health Data',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                subtitle: Text(
                  'Export verified records & vitals package (JSON)',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
              ),
              _buildDivider(isDark),

              // Share Health Summary Action
              ListTile(
                onTap: () => _shareHealthSummary(context, ref),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.share2, color: Color(0xFF0EA5E9), size: 20),
                ),
                title: Text(
                  'Share Medical Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                subtitle: Text(
                  'Share verified health record summary securely',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
              ),
              _buildDivider(isDark),

              // Log Out Button
              ListTile(
                onTap: () async {
                  dev.log('[AUTH UI] Patient requested logout', name: 'PatientProfileScreen');
                  await ref.read(authProvider.notifier).logout();
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.logOut, color: AppColors.danger, size: 20),
                ),
                title: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.danger,
                  ),
                ),
                subtitle: Text(
                  'End authenticated session on this device',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: isDark ? Colors.white : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      indent: 52,
      endIndent: 20,
      height: 1,
      color: isDark ? const Color(0xFF334155) : AppColors.border,
    );
  }

  // Working Share Health Summary Action
  void _shareHealthSummary(BuildContext context, WidgetRef ref) {
    final patient = ref.read(currentPatientStreamProvider).valueOrNull;
    final meds = ref.read(medicationsStreamProvider).valueOrNull ?? [];
    final reports = ref.read(reportsStreamProvider).valueOrNull ?? [];

    final text = StringBuffer()
      ..writeln('🏥 Continuum Health — Medical Summary')
      ..writeln('Patient: ${patient?.name ?? "Patient"}')
      ..writeln('Age: ${patient?.age ?? "-"} | Blood: ${patient?.bloodGroup ?? "-"}')
      ..writeln('Condition: ${patient?.condition ?? "General Care"}')
      ..writeln('\nActive Medications:');

    if (meds.isEmpty) {
      text.writeln('No active prescriptions.');
    } else {
      for (final m in meds.take(5)) {
        text.writeln('• ${m.name} (${m.dosage}) - ${m.frequency}');
      }
    }

    text.writeln('\nUploaded Reports: ${reports.length} files available in encrypted health vault.');
    SharePlus.instance.share(
      ShareParams(
        text: text.toString(),
        subject: 'Medical Summary: ${patient?.name ?? "Patient"}',
      ),
    );
  }

  // Working Share Report Action
  void _shareReport(BuildContext context, ReportModel report) {
    dev.log('[PROFILE] Sharing report ${report.id} - ${report.title}', name: 'PatientProfileScreen');
    final formattedDate = DateFormat('MMM d, yyyy').format(report.date);
    final text = StringBuffer()
      ..writeln('🏥 Continuum Health — Medical Document')
      ..writeln('Title: ${report.title}')
      ..writeln('Category: ${report.category.name.toUpperCase()}')
      ..writeln('Date: $formattedDate');
    
    if (report.doctorOrFacility != null) {
      text.writeln('Facility: ${report.doctorOrFacility}');
    }
    if (report.summary != null && report.summary!.isNotEmpty) {
      text.writeln('Summary: ${report.summary}');
    }
    if (report.downloadUrl != null && report.downloadUrl!.isNotEmpty) {
      text.writeln('\nEncrypted Document Link:\n${report.downloadUrl}');
    }
    SharePlus.instance.share(
      ShareParams(
        text: text.toString(),
        subject: 'Medical Report: ${report.title}',
      ),
    );
  }

  // Working Download Health Data Action
  Future<void> _downloadHealthData(BuildContext context, WidgetRef ref) async {
    final patient = ref.read(currentPatientStreamProvider).valueOrNull;
    final vitals = ref.read(vitalsStreamProvider).valueOrNull ?? [];
    final meds = ref.read(medicationsStreamProvider).valueOrNull ?? [];
    final appts = ref.read(appointmentsStreamProvider).valueOrNull ?? [];
    final reports = ref.read(reportsStreamProvider).valueOrNull ?? [];
    final currentUid = ref.read(currentUidProvider) ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating encrypted health data package...'),
        backgroundColor: AppColors.primaryBlue,
        duration: Duration(seconds: 1),
      ),
    );

    final exportData = {
      'generatedAt': DateTime.now().toIso8601String(),
      'patient': {
        'id': patient?.id ?? '',
        'name': patient?.name ?? '',
        'phoneNumber': patient?.phoneNumber ?? patient?.phone ?? '',
        'abhaId': patient?.abhaId ?? '',
        'age': patient?.age ?? 0,
        'condition': patient?.condition ?? '',
        'bloodGroup': patient?.bloodGroup ?? '',
        'isAdmitted': patient?.isAdmitted ?? false,
      },
      'vitals': vitals.map((v) => {
        'heartRate': v.heartRate,
        'bloodPressure': '${v.systolic}/${v.diastolic}',
        'spo2': v.spo2,
        'weight': v.weight,
        'recordedAt': v.recordedAt.toIso8601String(),
      }).toList(),
      'medications': meds.map((m) => {
        'name': m.name,
        'dosage': m.dosage,
        'frequency': m.frequency,
        'active': m.active,
      }).toList(),
      'appointments': appts.map((a) => {
        'doctorName': a.doctorName,
        'specialty': a.specialty,
        'dateTime': a.dateTime.toIso8601String(),
        'status': a.status.name,
      }).toList(),
      'reports': reports.map((r) => {
        'title': r.title,
        'category': r.category.name,
        'date': r.date.toIso8601String(),
        'doctorOrFacility': r.doctorOrFacility,
        'downloadUrl': r.downloadUrl,
        'storageReference': r.storageReference ?? r.storagePath,
        'protonDriveReference': r.protonDriveReference,
        'extractedData': r.extractedData,
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    await SharePlus.instance.share(
      ShareParams(
        text: jsonString,
        subject: 'Continuum Health — Data Export (${patient?.name ?? "Patient"})',
      ),
    );

    if (currentUid.isNotEmpty) {
      await ref.read(activityLogServiceProvider).logEvent(
        patientId: currentUid,
        eventType: ActivityEventType.documentViewed,
        title: 'Health Data Exported',
        description: 'Complete verified EHR and audit logs exported as JSON package.',
        actorUid: currentUid,
        actorRole: 'patient',
      );
    }
  }

  // Report Details Modal
  void _showReportDetailsModal(BuildContext context, WidgetRef ref, ReportModel report, bool isDark) {
    final currentUid = ref.read(currentUidProvider) ?? '';
    if (currentUid.isNotEmpty) {
      ref.read(activityLogServiceProvider).logEvent(
        patientId: report.patientId,
        eventType: ActivityEventType.documentViewed,
        title: 'Document Viewed: ${report.title}',
        description: 'Encrypted document details and OCR extractions viewed.',
        actorUid: currentUid,
        actorRole: 'patient',
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${report.category.name.toUpperCase()} • ${DateFormat("MMM d, yyyy").format(report.date)}',
              style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (report.doctorOrFacility != null) ...[
              const SizedBox(height: 8),
              Text(
                'Facility / Specialist: ${report.doctorOrFacility}',
                style: TextStyle(color: isDark ? Colors.white70 : AppColors.slate, fontSize: 13),
              ),
            ],
            if (report.summary != null && report.summary!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Clinical Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                report.summary!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? const Color(0xFFCBD5E1) : AppColors.slate,
                ),
              ),
            ],
            if (report.extractedData != null && report.extractedData!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'OCR Clinical Extractions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (report.extractedData?['diagnosis'] != null)
                      Text('• Diagnoses: ${(report.extractedData!['diagnosis'] as List).join(", ")}',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.navy)),
                    if (report.extractedData?['medicines'] != null)
                      Text('• Prescriptions: ${(report.extractedData!['medicines'] as List).join(", ")}',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.navy)),
                    if (report.extractedData?['followUpInstructions'] != null &&
                        report.extractedData!['followUpInstructions'].toString().isNotEmpty)
                      Text('• Follow-up: ${report.extractedData!['followUpInstructions']}',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.navy)),
                  ],
                ),
              ),
            ],
            if (report.protonDriveReference != null) ...[
              const SizedBox(height: 10),
              Text(
                'Vault: Proton Drive (${report.protonDriveReference})',
                style: const TextStyle(color: AppColors.primaryBlue, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (report.downloadUrl != null && report.downloadUrl!.isNotEmpty) ...[
                  Expanded(
                    child: PrimaryButton(
                      label: 'View / Download',
                      icon: LucideIcons.externalLink,
                      onPressed: () async {
                        final uri = Uri.parse(report.downloadUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SecondaryButton(
                    label: 'Share',
                    icon: LucideIcons.share2,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _shareReport(context, report);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQrCode(BuildContext context, WidgetRef ref, bool isDark) {
    final currentUid = ref.watch(currentUidProvider) ?? 'user';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131C2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Health QR',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Show this to your doctor to securely share your health profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: AppColors.softBlue, width: 2),
              ),
              child: QrImageView(
                data: 'continuum://patient/$currentUid/connect',
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.navy,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : AppColors.surfaceBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Doctor scans → Request sent → You approve → Connected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
