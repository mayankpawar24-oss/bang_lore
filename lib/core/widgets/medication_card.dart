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
  final bool isSkipped;
  final VoidCallback? onMarkAsTaken;
  final VoidCallback? onMarkAsSkipped;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const MedicationCard({
    super.key,
    required this.name,
    required this.dosage,
    required this.time,
    this.instructions,
    this.isTaken = false,
    this.isSkipped = false,
    this.onMarkAsTaken,
    this.onMarkAsSkipped,
    this.onEdit,
    this.onDelete,
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
          : isSkipped
              ? AppColors.warning.withValues(alpha: isDark ? 0.35 : 0.25)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border.withValues(alpha: 0.7)),
      onTap: onTap ?? onEdit,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isTaken
                  ? AppColors.success.withValues(alpha: isDark ? 0.2 : 0.12)
                  : isSkipped
                      ? AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.12)
                      : (isDark ? const Color(0xFF1E293B) : AppColors.softBlue),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSkipped ? LucideIcons.skipForward : LucideIcons.pill,
              color: isTaken
                  ? AppColors.success
                  : isSkipped
                      ? AppColors.warning
                      : AppColors.primaryBlue,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                      Flexible(
                        child: Text(
                          instructions!,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          else if (isSkipped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.skipForward, color: AppColors.warning, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Skipped',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 200.ms)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onMarkAsSkipped != null) ...[
                  InkWell(
                    onTap: onMarkAsSkipped,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : AppColors.softBlue.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white24 : AppColors.border,
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onMarkAsTaken,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        'Take',
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
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(
                LucideIcons.moreVertical,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.muted,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit?.call();
                } else if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (ctx) => [
                if (onEdit != null)
                  PopupMenuItem(
                    value: 'edit',
                    height: 38,
                    child: Row(
                      children: [
                        Icon(LucideIcons.pencil, size: 14, color: isDark ? Colors.white70 : AppColors.navy),
                        const SizedBox(width: 8),
                        Text('Edit', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppColors.navy)),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    height: 38,
                    child: Row(
                      children: const [
                        Icon(LucideIcons.trash2, size: 14, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
