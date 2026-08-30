import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/family_member_model.dart';

class FamilyMemberDetailScreen extends ConsumerWidget {
  final String memberId;
  const FamilyMemberDetailScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final members = ref.watch(familyMembersProvider);
    final member = members.firstWhere(
      (m) => m.id == memberId,
      orElse: () => members.isNotEmpty
          ? members.first
          : FamilyMemberModel(
              id: memberId,
              name: 'Unknown',
              relationship: 'Unknown',
              generation: 0,
              avatarUrl: null,
              knownConditions: [],
              familyHistory: [],
              careNeeds: 'None',
              careTasks: [],
              hydration: HydrationStatus.needed,
              walking: WalkingStatus.needed,
              medication: MedicationStatus.needed,
            ),
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      appBar: AppBar(
        title: Text(
          member.name,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.navy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : AppColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Profile Card
            AppCard(
              padding: const EdgeInsets.all(22),
              borderRadius: 24,
              elevation: 1,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                        : AppColors.softBlue,
                    backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                    child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                        ? Text(
                            member.name.isNotEmpty ? member.name[0] : '?',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.navy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${member.relationship} • Generation ${member.generation}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          ),
                        ),
                        if (member.careNeeds != null && member.careNeeds!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                                  : AppColors.softBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Needs: ${member.careNeeds}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.05),
            const SizedBox(height: 20),

            // Wellness Status Row
            const SectionHeader(title: 'Daily Wellness Status'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildWellnessBadge('Hydration', member.hydration.name, LucideIcons.droplet, AppColors.accentCyan, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildWellnessBadge('Walking', member.walking.name, LucideIcons.footprints, AppColors.success, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildWellnessBadge('Medication', member.medication.name, LucideIcons.pill, AppColors.primaryBlue, isDark)),
              ],
            ),
            const SizedBox(height: 24),

            // Known Conditions
            if (member.knownConditions.isNotEmpty) ...[
              const SectionHeader(title: 'Known Conditions'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: member.knownConditions.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    c,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Family Medical History (Hereditary context)
            if (member.familyHistory.isNotEmpty) ...[
              const SectionHeader(
                title: 'Family Medical History',
                subtitle: 'Hereditary health indicators',
              ),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                elevation: 1,
                borderColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...member.familyHistory.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.activity, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              h,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : AppColors.navy,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                    Divider(height: 16, color: isDark ? const Color(0xFF334155) : AppColors.border),
                    const Text(
                      'Family history context — not a clinical diagnosis.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryBlue,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Care Board (Tasks)
            const SectionHeader(
              title: 'Care Board',
              subtitle: 'Tap tasks to cycle status (To Do → Active → Done)',
            ),
            const SizedBox(height: 14),
            _buildCareTasksList(context, ref, member, isDark),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildWellnessBadge(String title, String status, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      elevation: 0.5,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.25 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareTasksList(BuildContext context, WidgetRef ref, FamilyMemberModel member, bool isDark) {
    if (member.careTasks.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        child: Center(
          child: Text(
            'No active care tasks assigned.',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
          ),
        ),
      );
    }

    return Column(
      children: member.careTasks.map((task) {
        Color statusColor;
        String statusLabel;

        switch (task.status) {
          case CareTaskStatus.todo:
            statusColor = AppColors.warning;
            statusLabel = 'TO DO';
            break;
          case CareTaskStatus.active:
            statusColor = AppColors.primaryBlue;
            statusLabel = 'ACTIVE';
            break;
          case CareTaskStatus.done:
            statusColor = AppColors.success;
            statusLabel = 'DONE';
            break;
        }

        return AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          elevation: 0.5,
          borderColor: statusColor.withValues(alpha: 0.35),
          onTap: () {
            CareTaskStatus nextStatus;
            if (task.status == CareTaskStatus.todo) {
              nextStatus = CareTaskStatus.active;
            } else if (task.status == CareTaskStatus.active) {
              nextStatus = CareTaskStatus.done;
            } else {
              nextStatus = CareTaskStatus.todo;
            }
            ref.read(familyMembersProvider.notifier).updateCareTaskStatus(member.id, task.id, nextStatus);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: task.status == CareTaskStatus.done
                            ? (isDark ? const Color(0xFF64748B) : AppColors.secondaryText)
                            : (isDark ? Colors.white : AppColors.navy),
                        decoration: task.status == CareTaskStatus.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.assignedTo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Assigned to ${task.assignedTo}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
