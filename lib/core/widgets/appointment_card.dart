import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

enum AppointmentCardVariant { hero, compact }

class AppointmentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime dateTime;
  final String? avatarUrl;
  final String? typeLabel;
  final VoidCallback? onTap;
  final VoidCallback? onJoinCall;
  final VoidCallback? onReschedule;
  final AppointmentCardVariant variant;

  const AppointmentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.dateTime,
    this.avatarUrl,
    this.typeLabel,
    this.onTap,
    this.onJoinCall,
    this.onReschedule,
    this.variant = AppointmentCardVariant.hero,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('EEE, MMM d • h:mm a').format(dateTime);

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      elevation: 2,
      borderRadius: 20,
      gradient: isDark
          ? const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF131C2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : const LinearGradient(
              colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      borderColor: isDark
          ? const Color(0xFF334155)
          : AppColors.softBlue,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.border.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            LucideIcons.calendar,
                            color: AppColors.primaryBlue,
                            size: 22,
                          ),
                        ),
                      )
                    : const Icon(
                        LucideIcons.calendar,
                        color: AppColors.primaryBlue,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Next Appointment',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.navy,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Icon(LucideIcons.arrowRight, color: AppColors.primaryBlue, size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$title • $subtitle',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
