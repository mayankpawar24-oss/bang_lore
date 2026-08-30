import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

class MedicationCard extends StatelessWidget {
  final String name;
  final String dosage;
  final String time;
  final String? instructions;
  final bool isTaken;
  final VoidCallback? onMarkAsTaken;
  final VoidCallback? onTap;

  const MedicationCard({
    super.key,
    required this.name,
    required this.dosage,
    required this.time,
    this.instructions,
    this.isTaken = false,
    this.onMarkAsTaken,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 18,
      elevation: 0.5,
      borderColor: isTaken
          ? AppColors.success.withValues(alpha: isDark ? 0.35 : 0.25)
          : (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border.withValues(alpha: 0.7)),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isTaken
                  ? AppColors.success.withValues(alpha: isDark ? 0.2 : 0.12)
                  : (isDark ? const Color(0xFF1E293B) : AppColors.softBlue),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.pill,
              color: isTaken ? AppColors.success : AppColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name $dosage',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.navy,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 12,
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (instructions != null && instructions!.isNotEmpty) ...[
                      Text(
                        ' • ',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        ),
                      ),
                      Text(
                        instructions!,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isTaken)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.check, color: AppColors.success, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Taken',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 200.ms)
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMarkAsTaken,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2563EB) : const Color(0xFF0B0C0E),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? const Color(0xFF2563EB) : const Color(0xFF0B0C0E))
                            .withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Mark as taken',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
