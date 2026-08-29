import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/vital_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';

class PatientProfileScreen extends ConsumerWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHero(context),
                  const SizedBox(height: 24),
                  _buildCurrentVitals(),
                  const SizedBox(height: 24),
                  _buildHealthInformation(context),
                  const SizedBox(height: 24),
                  _buildDataPrivacySection(context, ref),
                  const SizedBox(height: 100), // FAB padding
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
            ),
            Positioned(
              bottom: 24,
              right: 20,
              child: _buildAIChatButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
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
            child: const CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white24,
              child: Text(
                'MC',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Margaret Chen',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '72 years old • Heart Failure',
            style: TextStyle(fontSize: 14, color: Colors.white70),
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
              '🟢 Stable Status',
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
                  onTap: () => _showQrCode(context),
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
                        Icon(LucideIcons.qrCode, color: Colors.white, size: 20),
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
                      Icon(LucideIcons.edit2, color: Colors.white, size: 18),
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

  Widget _buildCurrentVitals() {
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

  Widget _buildHealthInformation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Health Information',
          subtitle: 'Personal medical documentation',
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildListTile(
                icon: LucideIcons.fileText,
                iconColor: AppColors.primaryBlue,
                title: 'Health Information',
                subtitle: 'Vitals, conditions, allergies',
                onTap: () => _showDetailModal(context, 'Health Information', 'Conditions: Heart Failure, Hypertension\nAllergies: Penicillin\nBlood Group: O+'),
              ),
              const Divider(indent: 64, endIndent: 20),
              _buildListTile(
                icon: LucideIcons.pill,
                iconColor: AppColors.accentCyan,
                title: 'Medications',
                subtitle: 'Furosemide, Lisinopril, Metoprolol',
                onTap: () => _showDetailModal(context, 'Current Medications', '1. Furosemide 40mg - Morning\n2. Lisinopril 10mg - Evening\n3. Metoprolol 25mg - Night'),
              ),
              const Divider(indent: 64, endIndent: 20),
              _buildListTile(
                icon: LucideIcons.barChart2,
                iconColor: AppColors.success,
                title: 'Reports',
                subtitle: 'Blood test (Aug 15), ECG (Aug 10)',
                onTap: () => _showDetailModal(context, 'Medical Reports', '• Blood Panel - Normal (Aug 15)\n• ECG Scan - Stable Sinus Rhythm (Aug 10)\n• Chest X-Ray - No congestion (Jul 28)'),
              ),
              const Divider(indent: 64, endIndent: 20),
              _buildListTile(
                icon: LucideIcons.history,
                iconColor: AppColors.warning,
                title: 'Medical History',
                subtitle: 'Past surgeries & procedures',
                onTap: () => _showDetailModal(context, 'Medical History', '2019: Coronary Angioplasty\n2015: Appendectomy'),
              ),
              const Divider(indent: 64, endIndent: 20),
              _buildListTile(
                icon: LucideIcons.phoneCall,
                iconColor: AppColors.danger,
                title: 'Emergency Contacts',
                subtitle: 'Sarah Chen (Daughter), David Chen (Father)',
                onTap: () => _showDetailModal(context, 'Emergency Contacts', '1. Sarah Chen (Daughter): +1 (555) 234-5678\n2. David Chen (Father): +1 (555) 876-5432'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataPrivacySection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Data & Privacy',
          subtitle: 'Export records & manage permissions',
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildListTile(
                icon: ref.watch(themeModeProvider) == ThemeMode.dark ? LucideIcons.moon : LucideIcons.sun,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Dark / Night Mode',
                subtitle: ref.watch(themeModeProvider) == ThemeMode.dark ? 'Enabled (Night palette)' : 'Disabled (Light palette)',
                onTap: () {
                  ref.read(themeModeProvider.notifier).toggleTheme();
                },
              ),
              const Divider(indent: 64, endIndent: 20),
              _buildListTile(
                icon: LucideIcons.download,
                iconColor: AppColors.primaryBlue,
                title: 'Download Health Data',
                subtitle: 'Export encrypted medical records (PDF/JSON)',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Downloading health data package...'),
                      backgroundColor: AppColors.primaryBlue,
                    ),
                  );
                },
              ),
              const Divider(indent: 64, endIndent: 20),
              _buildListTile(
                icon: LucideIcons.database,
                iconColor: AppColors.accentCyan,
                title: 'FHIR Data Export',
                subtitle: 'HL7 FHIR v4.0.1 standardized export',
                onTap: () => _showDetailModal(context, 'FHIR Data Export', 'FHIR R4 Endpoint: Active\nLast Sync: 10 minutes ago\nData standard: HL7 FHIR v4.0.1'),
              ),
              const Divider(indent: 64, endIndent: 20),
              _buildListTile(
                icon: LucideIcons.shieldCheck,
                iconColor: AppColors.success,
                title: 'Privacy & Permissions',
                subtitle: 'Dr. Aisha Patel (Authorized)',
                onTap: () => _showDetailModal(context, 'Privacy & Permissions', 'Authorized Doctor: Dr. Aisha Patel\nStatus: Approved\nAccess level: Full Clinical Brief'),
              ),
              const Divider(indent: 64, endIndent: 20),
              _buildListTile(
                icon: LucideIcons.logOut,
                iconColor: AppColors.danger,
                title: 'Log Out',
                subtitle: 'Switch account or end session',
                onTap: () => context.go('/login'),
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
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppColors.navy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 13,
        ),
      ),
      trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
    );
  }

  void _showDetailModal(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            Text(content, style: const TextStyle(fontSize: 15, color: AppColors.slate, height: 1.5)),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _showQrCode(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 16),
            const Text('Your Health QR', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 6),
            const Text(
              'Show this to your doctor to securely share your health profile',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.navy.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 6)),
                ],
                border: Border.all(color: AppColors.softBlue, width: 2),
              ),
              child: QrImageView(
                data: 'continuum://patient/margaret-chen/connect',
                version: QrVersions.auto,
                size: 200.0,
                foregroundColor: AppColors.navy,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Doctor scans → Request sent → You approve → Connected',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 12),
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildAIChatButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/patient/dashboard/ai-chat'),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.blueToCyan,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Icon(LucideIcons.bot, color: Colors.white, size: 26),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 2.seconds),
    );
  }
}
