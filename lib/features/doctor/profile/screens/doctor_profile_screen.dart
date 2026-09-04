import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/app_layout_insets.dart';
import '../../../../data/providers/providers.dart';

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider).valueOrNull ?? ref.watch(authProvider).user;
    final doctor = ref.watch(currentDoctorStreamProvider).valueOrNull;
    final docName = doctor?.name ?? user?.name ?? 'Doctor';
    final specialty = doctor?.specialty ?? 'General Practice';
    final hospital = doctor?.hospital ?? 'City Clinic';
    final phone = doctor?.phone.isNotEmpty == true ? doctor!.phone : (user?.phone ?? '+91 98765 43210');
    final email = user?.email ?? 'doctor@continuum.health';
    final uid = user?.id ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, AppLayoutInsets.bottomSafeInset(context) + 24),
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
              ).animate().fadeIn(),
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
              _buildInfoTile('Email Address', email, LucideIcons.mail, AppColors.primaryBlue, isDark),
              _buildInfoTile('Contact Phone', phone, LucideIcons.phone, AppColors.accentCyan, isDark),
              _buildInfoTile('Clinical Specialty', '$specialty • $hospital', LucideIcons.building2, const Color(0xFF8B5CF6), isDark),
              _buildInfoTile('Practitioner UID', uid.isNotEmpty ? uid : 'Verified Account', LucideIcons.shieldCheck, AppColors.success, isDark),

              const SizedBox(height: 24),

              // Telegram Notifications Section
              Text(
                'Telegram Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              _buildTelegramCard(context, ref, isDark),

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
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, AppLayoutInsets.bottomSafeInset(ctx) + 20),
            child: SingleChildScrollView(
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
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Doctor profile updated!'), backgroundColor: AppColors.primaryBlue),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, AppLayoutInsets.bottomSafeInset(ctx) + 20),
            child: SingleChildScrollView(
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
                  PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTelegramCard(BuildContext context, WidgetRef ref, bool isDark) {
    final telegramStatus = ref.watch(telegramStatusStreamProvider).valueOrNull;
    final isConnected = telegramStatus?['connected'] == true;
    final chatId = telegramStatus?['chatId'] as String?;

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0088CC).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.send, color: Color(0xFF0088CC), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? 'Telegram Connected' : 'Connect Telegram',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected
                          ? (chatId != null && chatId.isNotEmpty ? 'Active (Chat ID: $chatId)' : 'Active (Alerts enabled)')
                          : 'Get real-time appointment request & approval alerts',
                      style: TextStyle(
                        color: isConnected
                            ? AppColors.success
                            : (isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                        fontSize: 12,
                        fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
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
            ],
          ),
          const SizedBox(height: 14),
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
                      final uid = ref.read(currentUidProvider) ?? '';
                      try {
                        dev.log('[TELEGRAM] Doctor disconnecting Telegram $uid', name: 'DoctorProfileScreen');
                        await ref.read(telegramRepositoryProvider).disconnectTelegram(uid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Telegram disconnected.'),
                              backgroundColor: AppColors.primaryBlue,
                            ),
                          );
                        }
                      } catch (e) {
                        dev.log('[TELEGRAM] Doctor disconnect failed: $e', error: e, name: 'DoctorProfileScreen');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
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
                  text: isConnected ? 'Manage Settings' : 'Connect Telegram',
                  icon: isConnected ? LucideIcons.settings : LucideIcons.send,
                  onPressed: () => _showTelegramModal(context, ref, isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTelegramModal(BuildContext context, WidgetRef ref, bool isDark) {
    dev.log('[TELEGRAM] Opening doctor Telegram modal', name: 'DoctorProfileScreen');
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
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: AppLayoutInsets.bottomSafeInset(ctx) + 20,
                ),
                child: SingleChildScrollView(
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
                            'Telegram Doctor Alerts',
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
                  'Receive instant alerts on Telegram when patients request appointments, cancel bookings, or share emergency updates.',
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
                        'Opens Telegram and associates your chat with your doctor account (UID: ${currentUid.length > 8 ? currentUid.substring(0, 8) : currentUid}...).',
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
                            dev.log('[TELEGRAM] Doctor tapped Open Telegram Bot', name: 'DoctorProfileScreen');
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
                              dev.log('[TELEGRAM] Disconnecting doctor $currentUid', name: 'DoctorProfileScreen');
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
                              dev.log('[TELEGRAM] Doctor disconnect failed: $e', error: e, name: 'DoctorProfileScreen');
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
                            dev.log('[TELEGRAM] Saving Chat ID $chatId for doctor $currentUid', name: 'DoctorProfileScreen');
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
                            dev.log('[TELEGRAM] Doctor connection error: $e', error: e, name: 'DoctorProfileScreen');
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
          ),
        ),
      ),
    );
  },
),
);
  }
}
