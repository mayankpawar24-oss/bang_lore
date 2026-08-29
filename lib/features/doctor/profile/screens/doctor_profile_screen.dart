import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Doctor Profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Medical credentials & clinic configuration',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Doctor Hero Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
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
                    Stack(
                      children: [
                        const CircleAvatar(
                          radius: 38,
                          backgroundColor: AppColors.softBlue,
                          backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=aisha'),
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
                          const Text(
                            'Dr. Aisha Patel, MD',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Senior Cardiologist',
                            style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Icon(LucideIcons.building2, size: 13, color: AppColors.secondaryText),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'City Heart Center',
                                  style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(LucideIcons.star, color: AppColors.warning, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  '4.9 (142 reviews)',
                                  style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 11),
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
              const SizedBox(height: 24),

              // Quick Actions Row
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Edit Profile',
                      icon: LucideIcons.edit3,
                      onPressed: () => _showEditProfileSheet(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppColors.primaryBlue),
                      ),
                      onPressed: () => _showSettingsSheet(context, ref),
                      icon: const Icon(LucideIcons.settings, color: AppColors.primaryBlue, size: 18),
                      label: const Text('Settings', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Professional Credentials Section
              const Text(
                'Professional Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 12),
              _buildInfoTile('Medical License', 'MD-94827104 (Active)', LucideIcons.shieldCheck, AppColors.success),
              _buildInfoTile('Experience', '15 Years (Interventional Cardiology)', LucideIcons.award, AppColors.primaryBlue),
              _buildInfoTile('Education', 'Harvard Medical School (Class of 2011)', LucideIcons.graduationCap, const Color(0xFF8B5CF6)),
              _buildInfoTile('Contact Phone', '+1 (555) 019-2831', LucideIcons.phone, AppColors.accentCyan),

              const SizedBox(height: 24),

              // Weekly Consultation Hours
              const Text(
                'Weekly Availability Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    _buildScheduleRow('Monday', '9:00 AM – 5:00 PM', true),
                    const Divider(height: 16),
                    _buildScheduleRow('Tuesday', '9:00 AM – 1:00 PM', true),
                    const Divider(height: 16),
                    _buildScheduleRow('Wednesday', '9:00 AM – 5:00 PM', true),
                    const Divider(height: 16),
                    _buildScheduleRow('Thursday', '1:00 PM – 6:00 PM', true),
                    const Divider(height: 16),
                    _buildScheduleRow('Friday', '9:00 AM – 3:00 PM', true),
                    const Divider(height: 16),
                    _buildScheduleRow('Saturday & Sunday', 'Unavailable', false),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Log Out Button
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
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

  Widget _buildInfoTile(String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String day, String hours, bool isOpen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 14)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOpen ? AppColors.softBlue : Colors.grey.shade100,
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

  void _showEditProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Doctor Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
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

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Dark / Night Mode'),
              subtitle: Text(ref.watch(themeModeProvider) == ThemeMode.dark ? 'Enabled (Night palette)' : 'Disabled (Light palette)'),
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              activeColor: AppColors.primaryBlue,
              onChanged: (v) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
            SwitchListTile(
              title: const Text('Emergency SOS Alerts'),
              subtitle: const Text('Receive push alerts when patients trigger SOS'),
              value: true,
              activeColor: AppColors.primaryBlue,
              onChanged: (v) {},
            ),
            SwitchListTile(
              title: const Text('Patient Access Notifications'),
              subtitle: const Text('Notify when patient approves record access'),
              value: true,
              activeColor: AppColors.primaryBlue,
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
