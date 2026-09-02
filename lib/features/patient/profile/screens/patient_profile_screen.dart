import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/vital_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';

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
              _buildProfileHero(context, ref, isDark),
              const SizedBox(height: 24),
              _buildCurrentVitals(isDark),
              const SizedBox(height: 24),
              _buildHealthInformation(context, isDark),
              const SizedBox(height: 24),
              _buildDataPrivacySection(context, ref, isDark),
              const SizedBox(height: 40),
            ],
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
        ),
      ),
    );
  }

  Widget _buildProfileHero(BuildContext context, WidgetRef ref, bool isDark) {
    final userAsync = ref.watch(currentUserProvider);
    final patientAsync = ref.watch(currentPatientStreamProvider);

    final fullName = patientAsync.valueOrNull?.name ??
        userAsync.valueOrNull?.name ??
        ref.watch(authProvider).user?.name ??
        'User';

    final age = patientAsync.valueOrNull?.age ?? 30;
    final condition = patientAsync.valueOrNull?.condition ?? 'General Care';

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
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Text(
              '🟢 Stable Health Status',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // QR Code & Edit Profile action row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showQrCode(context, ref, isDark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(LucideIcons.qrCode, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Your Health QR',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening Profile Editor...'), backgroundColor: AppColors.primaryBlue),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(LucideIcons.edit2, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentVitals(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Current Vitals',
          subtitle: 'Real-time telemetry & trends',
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: const [
            VitalCard(
              label: 'Blood Pressure',
              value: '120/80',
              unit: 'mmHg',
              icon: LucideIcons.heartHandshake,
              iconColor: AppColors.primaryBlue,
              trend: 'Normal',
              isPositiveTrend: true,
              lastUpdated: '10m ago',
            ),
            VitalCard(
              label: 'Heart Rate',
              value: '74',
              unit: 'bpm',
              icon: LucideIcons.activity,
              iconColor: AppColors.danger,
              trend: 'Optimal',
              isPositiveTrend: true,
              lastUpdated: '10m ago',
            ),
            VitalCard(
              label: 'SpO₂',
              value: '97',
              unit: '%',
              icon: LucideIcons.wind,
              iconColor: AppColors.accentCyan,
              trend: 'Normal',
              isPositiveTrend: true,
              lastUpdated: '10m ago',
            ),
            VitalCard(
              label: 'Temperature',
              value: '98.4',
              unit: '°F',
              icon: LucideIcons.thermometer,
              iconColor: AppColors.warning,
              trend: 'Normal',
              isPositiveTrend: true,
              lastUpdated: '1h ago',
            ),
            VitalCard(
              label: 'Weight',
              value: '68.4',
              unit: 'kg',
              icon: LucideIcons.scale,
              iconColor: AppColors.success,
              trend: '-0.5 kg',
              isPositiveTrend: true,
              lastUpdated: 'Today, 8 AM',
            ),
            VitalCard(
              label: 'Sleep',
              value: '7.2',
              unit: 'hrs',
              icon: LucideIcons.moon,
              iconColor: Color(0xFF8B5CF6),
              trend: '+0.4 hrs',
              isPositiveTrend: true,
              lastUpdated: 'Last night',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthInformation(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Health Information',
          subtitle: 'Personal medical documentation',
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: EdgeInsets.zero,
          borderRadius: 24,
          elevation: 1,
          child: Column(
            children: [
              _buildListTile(
                icon: LucideIcons.fileText,
                iconColor: AppColors.primaryBlue,
                title: 'Health Information',
                subtitle: 'Vitals, conditions, allergies',
                isDark: isDark,
                onTap: () => _showDetailModal(context, 'Health Information', 'Conditions: Heart Failure, Hypertension\nAllergies: Penicillin\nBlood Group: O+', isDark),
              ),
              Divider(indent: 64, endIndent: 20, height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),
              _buildListTile(
                icon: LucideIcons.pill,
                iconColor: AppColors.accentCyan,
                title: 'Medications',
                subtitle: 'Furosemide, Lisinopril, Metoprolol',
                isDark: isDark,
                onTap: () => _showDetailModal(context, 'Current Medications', '1. Furosemide 40mg - Morning\n2. Lisinopril 10mg - Evening\n3. Metoprolol 25mg - Night', isDark),
              ),
              Divider(indent: 64, endIndent: 20, height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),
              _buildListTile(
                icon: LucideIcons.barChart2,
                iconColor: AppColors.success,
                title: 'Reports',
                subtitle: 'Blood test (Aug 15), ECG (Aug 10)',
                isDark: isDark,
                onTap: () => _showDetailModal(context, 'Medical Reports', '• Blood Panel - Normal (Aug 15)\n• ECG Scan - Stable Sinus Rhythm (Aug 10)\n• Chest X-Ray - No congestion (Jul 28)', isDark),
              ),
              Divider(indent: 64, endIndent: 20, height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),
              _buildListTile(
                icon: LucideIcons.history,
                iconColor: AppColors.warning,
                title: 'Medical History',
                subtitle: 'Past surgeries & procedures',
                isDark: isDark,
                onTap: () => _showDetailModal(context, 'Medical History', '2019: Coronary Angioplasty\n2015: Appendectomy', isDark),
              ),
              Divider(indent: 64, endIndent: 20, height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),
              _buildListTile(
                icon: LucideIcons.phoneCall,
                iconColor: AppColors.danger,
                title: 'Emergency Contacts',
                subtitle: 'Sarah Chen (Daughter), David Chen (Father)',
                isDark: isDark,
                onTap: () => _showDetailModal(context, 'Emergency Contacts', '1. Sarah Chen (Daughter): +1 (555) 234-5678\n2. David Chen (Father): +1 (555) 876-5432', isDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataPrivacySection(BuildContext context, WidgetRef ref, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Data & Privacy',
          subtitle: 'Export records & manage permissions',
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: EdgeInsets.zero,
          borderRadius: 24,
          elevation: 1,
          child: Column(
            children: [
              _buildListTile(
                icon: ref.watch(themeModeProvider) == ThemeMode.dark ? LucideIcons.moon : LucideIcons.sun,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Dark / Night Mode',
                subtitle: ref.watch(themeModeProvider) == ThemeMode.dark ? 'Enabled (Night palette)' : 'Disabled (Light palette)',
                isDark: isDark,
                onTap: () {
                  ref.read(themeModeProvider.notifier).toggleTheme();
                },
              ),
              Divider(indent: 64, endIndent: 20, height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),
              _buildListTile(
                icon: LucideIcons.download,
                iconColor: AppColors.primaryBlue,
                title: 'Download Health Data',
                subtitle: 'Export encrypted medical records (PDF/JSON)',
                isDark: isDark,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Downloading health data package...'),
                      backgroundColor: AppColors.primaryBlue,
                    ),
                  );
                },
              ),
              Divider(indent: 64, endIndent: 20, height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),
              _buildListTile(
                icon: LucideIcons.database,
                iconColor: AppColors.accentCyan,
                title: 'FHIR Data Export',
                subtitle: 'HL7 FHIR v4.0.1 standardized export',
                isDark: isDark,
                onTap: () => _showDetailModal(context, 'FHIR Data Export', 'FHIR R4 Endpoint: Active\nLast Sync: 10 minutes ago\nData standard: HL7 FHIR v4.0.1', isDark),
              ),
              Divider(indent: 64, endIndent: 20, height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),
              _buildListTile(
                icon: LucideIcons.shieldCheck,
                iconColor: AppColors.success,
                title: 'Privacy & Permissions',
                subtitle: 'Dr. Aisha Patel (Authorized)',
                isDark: isDark,
                onTap: () => _showDetailModal(context, 'Privacy & Permissions', 'Authorized Doctor: Dr. Aisha Patel\nStatus: Approved\nAccess level: Full Clinical Brief', isDark),
              ),
              Divider(indent: 64, endIndent: 20, height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),
              _buildListTile(
                icon: LucideIcons.logOut,
                iconColor: AppColors.danger,
                title: 'Log Out',
                subtitle: 'Switch account or end session',
                isDark: isDark,
                onTap: () async {
                  dev.log('[AUTH UI] Patient requested logout', name: 'PatientProfileScreen');
                  await ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: isDark ? Colors.white : AppColors.navy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
          fontSize: 13,
        ),
      ),
      trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
    );
  }

  void _showDetailModal(BuildContext context, String title, String content, bool isDark) {
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
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? const Color(0xFFCBD5E1) : AppColors.slate,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
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
