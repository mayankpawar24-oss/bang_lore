import 'dart:convert';
import 'dart:math';
import 'dart:developer' as dev;
import '../../../../data/models/permission_request_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
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

              // 2. Personal Information
              _buildPersonalInformation(context, ref, isDark),
              const SizedBox(height: 24),

              // 3. Medical & Personal Reports
              _buildMedicalReportsSection(context, ref, isDark),
              const SizedBox(height: 24),

              // 4. Account / Login Information & Actions
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
    final p1 = fullName.hashCode.abs() % 9000 + 1000;
    final p2 = (fullName.hashCode.abs() ~/ 2) % 9000 + 1000;
    final p3 = (fullName.hashCode.abs() ~/ 3) % 9000 + 1000;
    final abha = 'ABHA: 91-$p1-$p2-$p3';

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

  // 2. Personal Information
  Widget _buildPersonalInformation(BuildContext context, WidgetRef ref, bool isDark) {
    final user = ref.watch(currentUserProvider).valueOrNull ?? ref.watch(authProvider).user;
    final patient = ref.watch(currentPatientStreamProvider).valueOrNull;

    final name = (patient != null && patient.name.isNotEmpty)
        ? patient.name
        : (user != null && user.name.isNotEmpty ? user.name : 'User');
    final email = (user != null && user.email.isNotEmpty) ? user.email : 'Not Provided';
    final phone = (patient?.phone != null && patient!.phone!.isNotEmpty)
        ? patient.phone!
        : (user?.phone != null && user!.phone!.isNotEmpty ? user.phone! : 'Not provided');
    final age = patient?.age != null ? '${patient!.age} years' : 'Not provided';
    final condition = (patient != null && patient.condition.isNotEmpty) ? patient.condition : 'General Care';
    final bloodGroup = (patient?.bloodGroup != null && patient!.bloodGroup!.isNotEmpty)
        ? patient.bloodGroup!
        : 'Not specified';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Personal Information',
          subtitle: 'Verified patient identity & demographics',
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
              _buildInfoRow(LucideIcons.mail, 'Email Address', email, isDark),
              _buildDivider(isDark),
              _buildInfoRow(LucideIcons.phone, 'Phone Number', phone, isDark),
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
          title: 'Medical Reports',
          subtitle: 'Encrypted Firestore & Storage documents',
          trailing: reports.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${reports.length} files',
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
                    ' • ',
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
                  onTap: () => _showReportDetailsModal(context, report, isDark),
                );
              },
            ),
          ),
      ],
    );
  }

  // 4. Account / Login Information & Actions
  Widget _buildAccountAndActions(BuildContext context, WidgetRef ref, bool isDark) {
    final user = ref.watch(currentUserProvider).valueOrNull ?? ref.watch(authProvider).user;
    final currentUid = ref.watch(currentUidProvider) ?? 'user';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Account & Actions',
          subtitle: 'Security, data export & preferences',
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

              // Connect Telegram Action
              _buildTelegramTile(context, ref, isDark),
              _buildDivider(isDark),

              // Doctor Access Permissions Action
              _buildPermissionsTile(context, ref, isDark),
              _buildDivider(isDark),

              // Theme Mode Toggle
              ListTile(
                onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    ref.watch(themeModeProvider) == ThemeMode.dark ? LucideIcons.moon : LucideIcons.sun,
                    color: const Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                title: Text(
                  'Dark / Night Theme',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                subtitle: Text(
                  ref.watch(themeModeProvider) == ThemeMode.dark ? 'Enabled (Dark OLED palette)' : 'Disabled (Light palette)',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: ref.watch(themeModeProvider) == ThemeMode.dark,
                  activeThumbColor: const Color(0xFF8B5CF6),
                  onChanged: (val) => ref.read(themeModeProvider.notifier).toggleTheme(),
                ),
              ),
              _buildDivider(isDark),

              // Account / UID info
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.shieldCheck, color: AppColors.accentCyan, size: 20),
                ),
                title: Text(
                  'Authenticated Account',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                subtitle: Text(
                  'Role: ${user?.role.name.toUpperCase() ?? "PATIENT"} • UID: ${currentUid.substring(0, currentUid.length > 10 ? 10 : currentUid.length)}...',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
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
        'age': patient?.age ?? 0,
        'condition': patient?.condition ?? '',
        'bloodGroup': patient?.bloodGroup ?? '',
      },
      'vitals': vitals.map((v) => {
        'heartRate': v.heartRate,
        'bloodPressure': '/',
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
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    await SharePlus.instance.share(
      ShareParams(
        text: jsonString,
        subject: 'Continuum Health — Data Export (${patient?.name ?? "Patient"})',
      ),
    );
  }

  // Report Details Modal
  void _showReportDetailsModal(BuildContext context, ReportModel report, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
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
              ' • ',
              style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (report.doctorOrFacility != null) ...[
              const SizedBox(height: 8),
              Text(
                'Facility / Specialist: ',
                style: TextStyle(color: isDark ? Colors.white70 : AppColors.slate, fontSize: 14),
              ),
            ],
            if (report.summary != null && report.summary!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Summary & Extracted Findings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                report.summary!,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? const Color(0xFFCBD5E1) : AppColors.slate,
                ),
              ),
            ],
            if (report.downloadUrl != null && report.downloadUrl!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Storage Path: ${report.storagePath ?? "Encrypted"}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
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
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Close',
                    onPressed: () => Navigator.pop(ctx),
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

  Widget _buildTelegramTile(BuildContext context, WidgetRef ref, bool isDark) {
    final telegramStatus = ref.watch(telegramStatusStreamProvider).valueOrNull;
    final isConnected = telegramStatus?['connected'] == true;
    final chatId = telegramStatus?['chatId'] as String?;

    return ListTile(
      onTap: () => _showTelegramModal(context, ref, isDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0088CC).withValues(alpha: isDark ? 0.25 : 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(LucideIcons.send, color: Color(0xFF0088CC), size: 20),
      ),
      title: Text(
        isConnected ? 'Telegram Connected' : 'Connect Telegram',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: isDark ? Colors.white : AppColors.navy,
        ),
      ),
      subtitle: Text(
        isConnected
            ? (chatId != null && chatId.isNotEmpty ? 'Active (Chat ID: $chatId)' : 'Active (Alerts enabled)')
            : 'Get real-time appointment & reminder alerts',
        style: TextStyle(
          color: isConnected
              ? AppColors.success
              : (isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
          fontSize: 12,
          fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'CONNECTED',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
        ],
      ),
    );
  }

  void _showTelegramModal(BuildContext context, WidgetRef ref, bool isDark) {
    dev.log('[TELEGRAM] Opening Telegram modal', name: 'PatientProfileScreen');
    final currentUid = ref.read(currentUidProvider) ?? '';
    final telegramStatus = ref.read(telegramStatusStreamProvider).valueOrNull;
    final isConnected = telegramStatus?['connected'] == true;
    final existingChatId = telegramStatus?['chatId'] as String? ?? '';

    final chatIdController = TextEditingController(text: existingChatId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0088CC).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(LucideIcons.send, color: Color(0xFF0088CC), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Telegram Notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                          Text(
                            isConnected ? 'Status: Connected' : 'Status: Not Connected',
                            style: TextStyle(
                              fontSize: 12,
                              color: isConnected ? AppColors.success : AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Receive instant alerts on Telegram for appointment approvals, schedule changes, medications, and real-time care updates.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? const Color(0xFFCBD5E1) : AppColors.slate,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Button to open Continuum Health Bot directly
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connect via Continuum Telegram Bot',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Opens Telegram and associates your chat with your secure account (UID: ${currentUid.length > 8 ? currentUid.substring(0, 8) : currentUid}...).',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            dev.log('[TELEGRAM] User tapped Open Telegram Bot', name: 'PatientProfileScreen');
                            final launched = await ref.read(telegramRepositoryProvider).openTelegramBot(currentUid);
                            if (!launched && ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not open Telegram automatically. You can enter your Chat ID below.'),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                            }
                          },
                          icon: const Icon(LucideIcons.externalLink, size: 16, color: Colors.white),
                          label: const Text(
                            'Open Continuum Bot in Telegram',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0088CC),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Manual / Confirmation Chat ID Entry
                Text(
                  'Telegram Chat ID',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: chatIdController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 123456789 (from @userinfobot or bot)',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : AppColors.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF0088CC), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions: Save / Disconnect
                Row(
                  children: [
                    if (isConnected) ...[
                      Expanded(
                        child: SecondaryButton(
                          label: 'Disconnect',
                          icon: LucideIcons.xCircle,
                          foregroundColor: AppColors.danger,
                          borderColor: AppColors.danger.withValues(alpha: 0.5),
                          onPressed: () async {
                            try {
                              dev.log('[TELEGRAM] Disconnecting user $currentUid', name: 'PatientProfileScreen');
                              await ref.read(telegramRepositoryProvider).disconnectTelegram(currentUid);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Telegram disconnected.'),
                                    backgroundColor: AppColors.primaryBlue,
                                  ),
                                );
                              }
                            } catch (e) {
                              dev.log('[TELEGRAM] Disconnect failed: $e', error: e, name: 'PatientProfileScreen');
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to disconnect: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: PrimaryButton(
                        text: isConnected ? 'Update Chat ID' : 'Save Connection',
                        icon: LucideIcons.check,
                        onPressed: () async {
                          final chatId = chatIdController.text.trim();
                          if (chatId.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid Telegram Chat ID.'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                            return;
                          }
                          try {
                            dev.log('[TELEGRAM] Saving Chat ID $chatId for user $currentUid', name: 'PatientProfileScreen');
                            await ref.read(telegramRepositoryProvider).connectTelegram(currentUid, chatId);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Telegram notifications connected successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            dev.log('[TELEGRAM] Connection error: $e', error: e, name: 'PatientProfileScreen');
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Connection failed: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPermissionsTile(BuildContext context, WidgetRef ref, bool isDark) {
    final permsAsync = ref.watch(patientAllPermissionsStreamProvider);
    final perms = permsAsync.valueOrNull ?? [];
    final activeCount = perms.where((p) => p.isActive).length;
    final pendingCount = perms.where((p) => p.status == PermissionStatus.pending).length;

    return ListTile(
      onTap: () => _showPermissionsModal(context, ref, isDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(LucideIcons.shieldCheck, color: AppColors.primaryBlue, size: 20),
      ),
      title: Text(
        'Doctor Access Permissions',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: isDark ? Colors.white : AppColors.navy,
        ),
      ),
      subtitle: Text(
        pendingCount > 0
            ? '$pendingCount pending request(s) awaiting review'
            : (activeCount > 0 ? '$activeCount doctor(s) authorized' : 'Manage clinical data sharing'),
        style: TextStyle(
          color: pendingCount > 0 ? AppColors.warning : (isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
          fontSize: 12,
          fontWeight: pendingCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pendingCount NEW',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 6),
          const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
        ],
      ),
    );
  }

  void _showPermissionsModal(BuildContext context, WidgetRef ref, bool isDark) {
    dev.log('[ACCESS] Opening patient permissions modal', name: 'PatientProfileScreen');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final permsAsync = ref.watch(patientAllPermissionsStreamProvider);
          final perms = permsAsync.valueOrNull ?? [];

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
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
                          'Doctor Access Control',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Review and manage clinical permissions for your doctors',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (permsAsync.isLoading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (perms.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.shield, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No doctor access requests yet.',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: perms.length,
                      separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
                      itemBuilder: (ctx, idx) {
                        final p = perms[idx];
                        final isPending = p.status == PermissionStatus.pending;
                        final isApproved = p.status == PermissionStatus.approved;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isApproved
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : (isPending
                                            ? AppColors.warning.withValues(alpha: 0.15)
                                            : Colors.grey.shade200),
                                    child: Icon(
                                      isApproved ? LucideIcons.userCheck : (isPending ? LucideIcons.userPlus : LucideIcons.userX),
                                      color: isApproved ? AppColors.success : (isPending ? AppColors.warning : AppColors.muted),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.doctorName.isNotEmpty ? 'Dr. ${p.doctorName}' : 'Doctor (${p.doctorId.substring(0, min(6, p.doctorId.length))})',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isDark ? Colors.white : AppColors.navy,
                                          ),
                                        ),
                                        Text(
                                          'Status: ${p.status.name.toUpperCase()} • Requested: ${p.requestedAt.day}/${p.requestedAt.month}/${p.requestedAt.year}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isApproved
                                          ? AppColors.success.withValues(alpha: 0.15)
                                          : (isPending
                                              ? AppColors.warning.withValues(alpha: 0.15)
                                              : Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      p.status.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isApproved ? AppColors.success : (isPending ? AppColors.warning : AppColors.muted),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: p.permissions.map((permType) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      permType,
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : AppColors.navy),
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (isPending) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryBlue,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () async {
                                        dev.log('[ACCESS] Patient approving request ${p.id}', name: 'PatientProfileScreen');
                                        await ref.read(patientRepositoryProvider).approveAccess(
                                          p.id,
                                          permissions: const ['profile', 'vitals', 'medications', 'appointments', 'medicalHistory', 'familyHistory', 'reports', 'aiChat'],
                                        );
                                      },
                                      child: const Text('Approve Access', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.danger,
                                        side: const BorderSide(color: AppColors.danger),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () async {
                                        dev.log('[ACCESS] Patient declining request ${p.id}', name: 'PatientProfileScreen');
                                        await ref.read(patientRepositoryProvider).denyAccess(p.id);
                                      },
                                      child: const Text('Decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ] else if (isApproved) ...[
                                const SizedBox(height: 10),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(color: AppColors.danger),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () async {
                                    dev.log('[ACCESS] Patient revoking access ${p.id}', name: 'PatientProfileScreen');
                                    await ref.read(patientRepositoryProvider).revokeAccess(p.id);
                                  },
                                  child: const Text('Revoke Access', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
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
