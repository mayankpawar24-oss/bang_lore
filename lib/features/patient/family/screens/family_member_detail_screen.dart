import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/family_member_model.dart';

class FamilyMemberDetailScreen extends ConsumerWidget {
  final String memberId;
  const FamilyMemberDetailScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider);
    final member = members.firstWhere(
      (m) => m.id == memberId,
      orElse: () => members.isNotEmpty ? members.first : FamilyMemberModel(
        id: memberId, name: 'Unknown', relationship: 'Unknown', generation: 0,
        avatarUrl: null, knownConditions: [], familyHistory: [], careNeeds: 'None',
        careTasks: [], hydration: HydrationStatus.needed, walking: WalkingStatus.needed, medication: MedicationStatus.needed,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(member.name, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Profile Card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.softBlue,
                    backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                    child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                        ? Text(
                            member.name.isNotEmpty ? member.name[0] : '?',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
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
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${member.relationship} • Generation ${member.generation}',
                          style: const TextStyle(fontSize: 14, color: AppColors.secondaryText),
                        ),
                        if (member.careNeeds != null && member.careNeeds!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Needs: ${member.careNeeds}',
                            style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
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
                Expanded(child: _buildWellnessBadge('Hydration', member.hydration.name, LucideIcons.droplet, AppColors.accentCyan)),
                const SizedBox(width: 10),
                Expanded(child: _buildWellnessBadge('Walking', member.walking.name, LucideIcons.footprints, AppColors.success)),
                const SizedBox(width: 10),
                Expanded(child: _buildWellnessBadge('Medication', member.medication.name, LucideIcons.pill, AppColors.primaryBlue)),
              ],
            ),
            const SizedBox(height: 24),

            // Known Conditions
            if (member.knownConditions.isNotEmpty) ...[
              const SectionHeader(title: 'Known Conditions'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: member.knownConditions.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    c,
                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.softBlue.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...member.familyHistory.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.activity, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 10),
                          Text(h, style: const TextStyle(fontSize: 15, color: AppColors.navy, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )),
                    const Divider(height: 16),
                    const Text(
                      'Family history context — not a diagnosis.',
                      style: TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
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
            _buildCareTasksList(context, ref, member),
          ],
        ),
      ),
    );
  }

  Widget _buildWellnessBadge(String title, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
          const SizedBox(height: 2),
          Text(
            status.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCareTasksList(BuildContext context, WidgetRef ref, FamilyMemberModel member) {
    if (member.careTasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: const Center(
          child: Text('No active care tasks assigned.', style: TextStyle(color: AppColors.secondaryText)),
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

        return GestureDetector(
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
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(color: AppColors.navy.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
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
                          color: task.status == CareTaskStatus.done ? AppColors.secondaryText : AppColors.navy,
                          decoration: task.status == CareTaskStatus.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (task.assignedTo != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Assigned to ${task.assignedTo}',
                          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
