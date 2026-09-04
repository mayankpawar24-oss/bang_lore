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
import '../../../../core/widgets/app_layout_insets.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/report_model.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/medication_model.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  ConsumerState<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  String _selectedLogCategory = 'All';
  String? _currentLinkingCode;
  bool _isGeneratingCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final uid = ref.read(currentUidProvider);
        if (uid != null && uid.isNotEmpty) {
          ref.read(missedEventsServiceProvider).checkAndProcessMissedEvents(uid);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, AppLayoutInsets.bottomSafeInset(context) + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ABHA ID & Profile Hero
              _buildProfileHero(context, ref, isDark),
              const SizedBox(height: 24),

              // 2. Personal Information & Phone Number
              _buildPersonalInformation(context, ref, isDark),
              const SizedBox(height: 24),

              // 2.5 Telegram Notifications (Patient-Specific)
              SectionHeader(
                title: 'Telegram Notifications',
                subtitle: 'Connect your personal Telegram for medication reminders & appointment alerts',
              ),
              const SizedBox(height: 12),
              _buildTelegramCard(context, ref, isDark),
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

  // 2.5 Telegram Notifications (Patient-Specific)
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
                      isConnected ? 'Telegram Connected' : 'Connect Personal Telegram',
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
                          : 'Get instant medication reminders & appointment alerts',
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
                        await ref.read(telegramRepositoryProvider).disconnectTelegram(uid, role: 'patient');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Telegram disconnected.'),
                              backgroundColor: AppColors.primaryBlue,
                            ),
                          );
                        }
                      } catch (e) {
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
    final currentUid = ref.read(currentUidProvider) ?? '';
    final telegramStatus = ref.read(telegramStatusStreamProvider).valueOrNull;
    final isConnected = telegramStatus?['connected'] == true;
    final existingChatId = telegramStatus?['chatId'] as String? ?? '';
    final chatIdController = TextEditingController(text: existingChatId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                ),
                child: Container(
                  padding: EdgeInsets.only(
                    top: 24,
                    left: 20,
                    right: 20,
                    bottom: AppLayoutInsets.bottomSafeInset(ctx) + 20,
                  ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0088CC).withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.send, color: Color(0xFF0088CC), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Personal Telegram Alerts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Receive instant alerts for your prescribed medication reminders, upcoming consultations, and missed appointment notifications.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Method 1: Instant Bot Launch with Code
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF0088CC).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.sparkles, color: Color(0xFF0088CC), size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Option 1: Connect via Telegram Bot',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Generate a secure linking code and tap Open Bot to link your personal chat in one tap.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_currentLinkingCode != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0088CC).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Code: $_currentLinkingCode',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 1.5,
                                      color: Color(0xFF0088CC),
                                    ),
                                  ),
                                  const Text(
                                    'Valid for 30m',
                                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0088CC),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: _isGeneratingCode
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(LucideIcons.send, size: 16),
                              label: Text(_currentLinkingCode == null ? 'Generate Code & Open Bot' : 'Open Continuum Bot in Telegram'),
                              onPressed: _isGeneratingCode
                                  ? null
                                  : () async {
                                      setModalState(() => _isGeneratingCode = true);
                                      try {
                                        final code = _currentLinkingCode ??
                                            await ref.read(telegramRepositoryProvider).generateLinkingCode(currentUid, role: 'patient');
                                        setModalState(() {
                                          _currentLinkingCode = code;
                                          _isGeneratingCode = false;
                                        });
                                        await ref.read(telegramRepositoryProvider).openTelegramBot(currentUid, linkingCode: code);
                                      } catch (e) {
                                        setModalState(() => _isGeneratingCode = false);
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Method 2: Manual Chat ID
                    Text(
                      'Option 2: Enter Telegram Chat ID Directly',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: chatIdController,
                      keyboardType: TextInputType.text,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.navy),
                      decoration: InputDecoration(
                        hintText: 'e.g., 123456789 or @username',
                        hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.muted),
                        prefixIcon: const Icon(LucideIcons.hash, size: 18, color: Color(0xFF0088CC)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (isConnected) ...[
                          Expanded(
                            child: SecondaryButton(
                              label: 'Unlink',
                              icon: LucideIcons.trash2,
                              foregroundColor: AppColors.danger,
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await ref.read(telegramRepositoryProvider).disconnectTelegram(currentUid, role: 'patient');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: PrimaryButton(
                            text: 'Save & Connect',
                            icon: LucideIcons.check,
                            onPressed: () async {
                              final chatId = chatIdController.text.trim();
                              if (chatId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid Telegram Chat ID.')),
                                );
                                return;
                              }
                              Navigator.of(ctx).pop();
                              await ref.read(telegramRepositoryProvider).connectTelegram(currentUid, chatId, role: 'patient');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Personal Telegram connected successfully!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
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
    );
  },
);
  }

  // 4. Logs / Activity with Category Filtering & Analytics
  Widget _buildActivityLogsSection(BuildContext context, WidgetRef ref, bool isDark) {
    final currentUid = ref.watch(currentUidProvider) ?? '';
    final logsAsync = ref.watch(activityLogsStreamProvider(currentUid));
    final rawLogs = logsAsync.valueOrNull ?? [];

    final apptsAsync = ref.watch(patientAppointmentsStreamProvider(currentUid));
    final rawAppointments = apptsAsync.valueOrNull ?? [];

    final medsAsync = ref.watch(patientMedicationsStreamProvider(currentUid));
    final rawMedications = medsAsync.valueOrNull ?? [];

    final rawReports = ref.watch(reportsStreamProvider).valueOrNull ?? [];

    final categories = [
      'All',
      'Appointments',
      'Medication',
      'Reports',
      'Notifications',
      'Adherence',
      'Alerts',
      'Telegram'
    ];

    final filteredLogs = rawLogs.where((log) {
      if (_selectedLogCategory == 'All') return true;
      final typeStr = log.eventType.name.toLowerCase();
      switch (_selectedLogCategory) {
        case 'Appointments':
          return typeStr.contains('appointment');
        case 'Medication':
          return typeStr.contains('med') || typeStr.contains('pill');
        case 'Reports':
          return typeStr.contains('doc') || typeStr.contains('report') || typeStr.contains('ocr') || typeStr.contains('insight');
        case 'Notifications':
          return typeStr.contains('notif') || typeStr.contains('remind');
        case 'Adherence':
          return typeStr.contains('taken') || typeStr.contains('skipped') || typeStr.contains('missed');
        case 'Alerts':
          return typeStr.contains('missed') || typeStr.contains('alert') || typeStr.contains('failed');
        case 'Telegram':
          return typeStr.contains('telegram');
        default:
          return true;
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Logs / Activity',
          subtitle: 'Live audit trail of real clinical, medication, and alert events',
          trailing: rawLogs.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${rawLogs.length} events',
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

        // CARE ACTIVITY ANALYTICS SUMMARY CARD
        _buildCareActivitySummary(
          context,
          isDark,
          rawLogs,
          rawAppointments,
          rawMedications,
          rawReports,
        ),
        const SizedBox(height: 14),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = _selectedLogCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  onSelected: (_) {
                    setState(() => _selectedLogCategory = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        if (filteredLogs.isEmpty)
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
                    _selectedLogCategory == 'All'
                        ? 'No activity logged yet.'
                        : 'No events found for $_selectedLogCategory.',
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
              itemCount: filteredLogs.length > 50 ? 50 : filteredLogs.length,
              separatorBuilder: (context, index) => _buildDivider(isDark),
              itemBuilder: (context, index) {
                final log = filteredLogs[index];
                final icon = _getEventIcon(log.eventType);
                final timeStr = DateFormat('MMM d, h:mm a').format(log.timestamp);
                final statusBadge = _getEventStatusBadge(log, isDark);

                return InkWell(
                  onTap: () => _showLogDetailModal(context, log, isDark),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: AppColors.primaryBlue, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      log.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: isDark ? Colors.white : AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF64748B) : AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                log.description,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  statusBadge,
                                  const SizedBox(width: 8),
                                  Text(
                                    log.actorRole.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF64748B) : AppColors.muted,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
    );
  }

  Widget _buildCareActivitySummary(
    BuildContext context,
    bool isDark,
    List<ActivityLogModel> logs,
    List<Appointment> appointments,
    List<Medication> medications,
    List<ReportModel> reports,
  ) {
    final apptEvents = logs.where((l) => l.eventType.name.toLowerCase().contains('appointment')).length;
    final medEvents = logs.where((l) => l.eventType.name.toLowerCase().contains('med') || l.eventType.name.toLowerCase().contains('pill')).length;
    final notifEvents = logs.where((l) => l.eventType.name.toLowerCase().contains('notif') || l.eventType.name.toLowerCase().contains('telegram')).length;
    final alertEvents = logs.where((l) => l.eventType.name.toLowerCase().contains('missed') || l.eventType.name.toLowerCase().contains('failed') || l.eventType.name.toLowerCase().contains('alert')).length;

    final upcomingAppts = appointments.where((a) => a.status == AppointmentStatus.approved && a.dateTime.isAfter(DateTime.now())).length;
    final missedAppts = appointments.where((a) => a.status == AppointmentStatus.missed).length;

    final takenCount = medications.where((m) => m.isTaken).length;
    final totalMeds = medications.length;
    final adherencePct = totalMeds > 0 ? ((takenCount / totalMeds) * 100).round() : 100;

    return InkWell(
      onTap: () => _showAnalyticsModal(context, isDark, logs, appointments, medications, reports),
      borderRadius: BorderRadius.circular(20),
      child: AppCard(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.barChart2, color: AppColors.primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'CARE ACTIVITY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'View Trends',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.primaryBlue),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Horizontal Counts
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMiniStat('Appointments', '$apptEvents', AppColors.primaryBlue, isDark),
                  const SizedBox(width: 10),
                  _buildMiniStat('Medication', '$medEvents', const Color(0xFF10B981), isDark),
                  const SizedBox(width: 10),
                  _buildMiniStat('Reports', '${reports.length}', const Color(0xFF8B5CF6), isDark),
                  const SizedBox(width: 10),
                  _buildMiniStat('Alerts', '$alertEvents', const Color(0xFFEF4444), isDark),
                  const SizedBox(width: 10),
                  _buildMiniStat('Notifications', '$notifEvents', const Color(0xFFF59E0B), isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Medication Adherence Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Medication Adherence',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                Text(
                  '$adherencePct%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: adherencePct >= 80 ? const Color(0xFF10B981) : (adherencePct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: adherencePct / 100.0,
                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  adherencePct >= 80 ? const Color(0xFF10B981) : (adherencePct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 14),

            // Upcoming & Missed Appointments
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calendarCheck, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upcoming',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                              ),
                            ),
                            Text(
                              '$upcomingAppts',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Missed Appts',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                              ),
                            ),
                            Text(
                              '$missedAppts',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getEventStatusBadge(ActivityLogModel log, bool isDark) {
    final typeStr = log.eventType.name.toLowerCase();
    Color bg;
    Color fg;
    String label;

    if (typeStr.contains('taken') || typeStr.contains('approved') || typeStr.contains('completed') || typeStr.contains('linked')) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.12);
      fg = const Color(0xFF10B981);
      label = typeStr.contains('taken') ? 'Taken' : (typeStr.contains('approved') ? 'Approved' : 'Completed');
    } else if (typeStr.contains('missed') || typeStr.contains('failed') || typeStr.contains('rejected')) {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      fg = const Color(0xFFEF4444);
      label = typeStr.contains('missed') ? 'Missed' : (typeStr.contains('rejected') ? 'Rejected' : 'Failed');
    } else if (typeStr.contains('remind') || typeStr.contains('requested') || typeStr.contains('pending')) {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      fg = const Color(0xFFF59E0B);
      label = typeStr.contains('remind') ? 'Reminder' : 'Pending';
    } else {
      bg = AppColors.primaryBlue.withValues(alpha: 0.12);
      fg = AppColors.primaryBlue;
      label = 'Logged';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showLogDetailModal(BuildContext context, ActivityLogModel log, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, AppLayoutInsets.bottomSafeInset(ctx) + 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131C2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_getEventIcon(log.eventType), color: AppColors.primaryBlue, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, MMM d, yyyy • h:mm a').format(log.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  log.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? const Color(0xFFE2E8F0) : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Event ID', log.id, isDark),
                if (log.appointmentId != null) _buildDetailRow('Appointment ID', log.appointmentId!, isDark),
                if (log.medicationId != null) _buildDetailRow('Medication ID', log.medicationId!, isDark),
                if (log.reportId != null) _buildDetailRow('Report ID', log.reportId!, isDark),
                _buildDetailRow('Actor Role', log.actorRole.toUpperCase(), isDark),
                if (log.deliveryStatus != null) _buildDetailRow('Delivery Status', log.deliveryStatus!, isDark),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsModal(
    BuildContext context,
    bool isDark,
    List<ActivityLogModel> logs,
    List<Appointment> appointments,
    List<Medication> medications,
    List<ReportModel> reports,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final totalAppts = appointments.length;
          final completedAppts = appointments.where((a) => a.status == AppointmentStatus.completed).length;
          final upcomingAppts = appointments.where((a) => a.status == AppointmentStatus.approved && a.dateTime.isAfter(DateTime.now())).length;
          final missedAppts = appointments.where((a) => a.status == AppointmentStatus.missed).length;
          final cancelledAppts = appointments.where((a) => a.status == AppointmentStatus.cancelled).length;
          final apptAttendancePct = totalAppts > 0 ? ((completedAppts / totalAppts) * 100).round() : 100;

          final totalMeds = medications.length;
          final takenDoses = medications.where((m) => m.isTaken).length;
          final missedDoses = medications.where((m) => m.isMissed || (!m.isTaken && !m.isSkipped && m.date.isBefore(DateTime.now().subtract(const Duration(minutes: 60))))).length;
          final medAdherencePct = totalMeds > 0 ? ((takenDoses / totalMeds) * 100).round() : 100;

          final notifLogs = logs.where((l) => l.eventType.name.toLowerCase().contains('notif') || l.eventType.name.toLowerCase().contains('telegram')).toList();
          final sentNotifs = notifLogs.where((l) => l.deliveryStatus == 'sent').length;
          final inAppNotifs = notifLogs.where((l) => l.deliveryStatus == 'in_app_only' || l.deliveryStatus == null).length;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: AppLayoutInsets.bottomSafeInset(ctx) + 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131C2E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.barChart, color: AppColors.primaryBlue, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Clinical Analytics & Trends',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    children: [
                      // Section 1: Medication Analytics
                      Text(
                        'MEDICATION ADHERENCE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMetricBox('Total Prescriptions', '$totalMeds', AppColors.primaryBlue, isDark),
                                _buildMetricBox('Doses Taken', '$takenDoses', const Color(0xFF10B981), isDark),
                                _buildMetricBox('Doses Missed', '$missedDoses', const Color(0xFFEF4444), isDark),
                                _buildMetricBox('Adherence', '$medAdherencePct%', const Color(0xFF8B5CF6), isDark),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: medAdherencePct / 100.0,
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  medAdherencePct >= 80 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                                minHeight: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 2: Appointments Analytics
                      Text(
                        'APPOINTMENTS ATTENDANCE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMetricBox('Total Consults', '$totalAppts', AppColors.primaryBlue, isDark),
                                _buildMetricBox('Completed', '$completedAppts', const Color(0xFF10B981), isDark),
                                _buildMetricBox('Upcoming', '$upcomingAppts', const Color(0xFF3B82F6), isDark),
                                _buildMetricBox('Missed', '$missedAppts', const Color(0xFFEF4444), isDark),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Attendance Rate: $apptAttendancePct%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.navy,
                                  ),
                                ),
                                Text(
                                  'Cancelled: $cancelledAppts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Health Reports
                      Text(
                        'REPORTS & HEALTH VAULT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetricBox('Total Documents', '${reports.length}', const Color(0xFF8B5CF6), isDark),
                            _buildMetricBox(
                              'Latest Upload',
                              reports.isNotEmpty ? DateFormat('MMM d').format(reports.first.date) : 'None',
                              AppColors.primaryBlue,
                              isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 4: Notifications
                      Text(
                        'AUTOMATION & NOTIFICATIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetricBox('Total Dispatches', '${notifLogs.length}', const Color(0xFFF59E0B), isDark),
                            _buildMetricBox('Telegram Delivered', '$sentNotifs', const Color(0xFF10B981), isDark),
                            _buildMetricBox('In-App Only', '$inAppNotifs', const Color(0xFF64748B), isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
  }

  Widget _buildMetricBox(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  IconData _getEventIcon(ActivityEventType type) {
    switch (type) {
      case ActivityEventType.patientCreated:
      case ActivityEventType.patientUpdated:
        return LucideIcons.userCheck;
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
      case ActivityEventType.medicationEdited:
      case ActivityEventType.medicationDeleted:
      case ActivityEventType.medicineTaken:
      case ActivityEventType.medicineSkipped:
      case ActivityEventType.medicationMissed:
        return LucideIcons.pill;
      case ActivityEventType.reminderCreated:
      case ActivityEventType.reminderCompleted:
      case ActivityEventType.reminderMissed:
        return LucideIcons.bell;
      case ActivityEventType.telegramLinked:
      case ActivityEventType.telegramUnlinked:
        return LucideIcons.send;
      case ActivityEventType.notificationSent:
      case ActivityEventType.notificationFailed:
        return LucideIcons.bellRing;
      case ActivityEventType.chatStarted:
      case ActivityEventType.chatAccessGranted:
      case ActivityEventType.chatAccessDenied:
        return LucideIcons.messageSquare;
      case ActivityEventType.familyMemberAdded:
      case ActivityEventType.familyMemberRemoved:
        return LucideIcons.users;
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
