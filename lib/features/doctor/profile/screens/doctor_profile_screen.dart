import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../data/providers/providers.dart';

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final doctor = ref.watch(currentDoctorStreamProvider).valueOrNull;
    final docName = doctor?.name ?? user?.name ?? 'Dr. Aisha Patel';
    final specialty = doctor?.specialty ?? 'General Practice';
    final hospital = doctor?.hospital ?? 'City Clinic';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Doctor Profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Medical credentials & clinic configuration',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              // Doctor Hero Profile Card
              AppCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 24,
                elevation: 1,
                borderColor: isDark
                    ? const Color(0xFF334155)
                    : AppColors.primaryBlue.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF1E293B) : AppColors.softBlue,
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: (doctor != null && doctor.avatarUrl.isNotEmpty)
                                ? Image.network(doctor.avatarUrl, fit: BoxFit.cover)
                                : Center(
                                    child: Text(
                                      docName.replaceAll('Dr. ', '').split(' ').first.isNotEmpty
                                          ? docName.replaceAll('Dr. ', '').split(' ').first[0]
                                          : 'D',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.check, color: Colors.white, size: 10),
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
                            docName.startsWith('Dr.') ? docName : 'Dr. $docName',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            specialty,
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.building2,
                                size: 13,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  hospital,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: isDark ? 0.25 : 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.star, color: AppColors.warning, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '4.9 (142 reviews)',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.navy,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.05),
              const SizedBox(height: 20),

              // Quick Actions Row
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Edit Profile',
                      icon: LucideIcons.edit3,
                      onPressed: () => _showEditProfileSheet(context, isDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SecondaryButton(
                      text: 'Settings',
                      icon: LucideIcons.settings,
                      onPressed: () => _showSettingsSheet(context, ref, isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Professional Credentials Section
              Text(
                'Professional Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoTile('Medical License', 'MD-94827104 (Active)', LucideIcons.shieldCheck, AppColors.success, isDark),
              _buildInfoTile('Experience', '15 Years (Interventional Cardiology)', LucideIcons.award, AppColors.primaryBlue, isDark),
              _buildInfoTile('Education', 'Harvard Medical School (Class of 2011)', LucideIcons.graduationCap, const Color(0xFF8B5CF6), isDark),
              _buildInfoTile('Contact Phone', '+1 (555) 019-2831', LucideIcons.phone, AppColors.accentCyan, isDark),

              const SizedBox(height: 24),

              // Weekly Consultation Hours
              Text(
                'Weekly Availability Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                elevation: 1,
                child: Column(
                  children: [
                    _buildScheduleRow('Monday', '9:00 AM – 5:00 PM', true, isDark),
                    Divider(height: 16, color: isDark ? const Color(0xFF334155) : AppColors.border),
                    _buildScheduleRow('Tuesday', '9:00 AM – 1:00 PM', true, isDark),
                    Divider(height: 16, color: isDark ? const Color(0xFF334155) : AppColors.border),
                    _buildScheduleRow('Wednesday', '9:00 AM – 5:00 PM', true, isDark),
                    Divider(height: 16, color: isDark ? const Color(0xFF334155) : AppColors.border),
                    _buildScheduleRow('Thursday', '1:00 PM – 6:00 PM', true, isDark),
                    Divider(height: 16, color: isDark ? const Color(0xFF334155) : AppColors.border),
                    _buildScheduleRow('Friday', '9:00 AM – 3:00 PM', true, isDark),
                    Divider(height: 16, color: isDark ? const Color(0xFF334155) : AppColors.border),
                    _buildScheduleRow('Saturday & Sunday', 'Unavailable', false, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Log Out Button
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    dev.log('[AUTH UI] Doctor requested logout', name: 'DoctorProfileScreen');
                    await ref.read(authProvider.notifier).logout();
                  },
                  icon: const Icon(LucideIcons.logOut, color: AppColors.danger, size: 18),
                  label: const Text(
                    'Log Out of Doctor Account',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ).animate().fadeIn(duration: 300.ms),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String subtitle, IconData icon, Color color, bool isDark) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      elevation: 0.5,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String day, String hours, bool isOpen, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.navy,
            fontSize: 14,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOpen
                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : AppColors.softBlue)
                : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            hours,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isOpen ? AppColors.primaryBlue : AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditProfileSheet(BuildContext context, bool isDark) {
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
              'Edit Doctor Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Full Name', hintText: 'Dr. Aisha Patel, MD')),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Specialty', hintText: 'Senior Cardiologist')),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Hospital', hintText: 'City Heart Center')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Changes',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Doctor profile updated!'), backgroundColor: AppColors.primaryBlue),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref, bool isDark) {
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
            SwitchListTile(
              title: Text(
                'Dark / Night Mode',
                style: TextStyle(color: isDark ? Colors.white : AppColors.navy, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                ref.watch(themeModeProvider) == ThemeMode.dark ? 'Enabled (Night palette)' : 'Disabled (Light palette)',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
              ),
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              activeThumbColor: AppColors.primaryBlue,
              onChanged: (v) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
            SwitchListTile(
              title: Text(
                'Emergency SOS Alerts',
                style: TextStyle(color: isDark ? Colors.white : AppColors.navy, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Receive push alerts when patients trigger SOS',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
              ),
              value: true,
              activeThumbColor: AppColors.primaryBlue,
              onChanged: (v) {},
            ),
            SwitchListTile(
              title: Text(
                'Patient Access Notifications',
                style: TextStyle(color: isDark ? Colors.white : AppColors.navy, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Notify when patient approves record access',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
              ),
              value: true,
              activeThumbColor: AppColors.primaryBlue,
              onChanged: (v) {},
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
