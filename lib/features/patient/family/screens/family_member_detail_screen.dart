import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/family_member_model.dart';
import '../../../../data/models/reminder_model.dart';
import '../../../../data/models/medication_model.dart';

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
        actions: [
          TextButton.icon(
            onPressed: () => _showAddReminderForMember(context, ref, member, isDark),
            icon: const Icon(LucideIcons.bellPlus, size: 16, color: AppColors.primaryBlue),
            label: const Text('Add Reminder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
          ),
          const SizedBox(width: 8),
        ],
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

  void _showAddReminderForMember(
    BuildContext context,
    WidgetRef ref,
    FamilyMemberModel member,
    bool isDark,
  ) {
    final titleCtrl = TextEditingController();
    final dosageCtrl = TextEditingController(text: '1 tablet');
    final notesCtrl = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 2)));
    String selectedFrequency = 'Daily';
    bool isSaving = false;
    String? formError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final now = DateTime.now();
          final tempDate = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
          final timeDisplay = DateFormat('hh:mm a').format(tempDate);

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131C2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reminder for ${member.name.split(" ").first}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.navy,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(LucideIcons.x, size: 20, color: isDark ? Colors.white70 : AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (formError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Medicine Name Field
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Medicine Name *',
                      hintText: 'e.g. Metformin, Dolo, BP Tablet',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dosage Field
                  TextField(
                    controller: dosageCtrl,
                    decoration: InputDecoration(
                      labelText: 'Dosage *',
                      hintText: 'e.g. 500mg, 1 tablet',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Time Picker
                  Text(
                    'Reminder Time *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.clock, size: 18, color: AppColors.primaryBlue),
                              const SizedBox(width: 10),
                              Text(
                                timeDisplay,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Change Time',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Frequency Selection
                  Text(
                    'Frequency *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Once', 'Daily', 'Twice daily', 'Weekly'].map((freq) {
                      final isSelected = selectedFrequency == freq;
                      return ChoiceChip(
                        label: Text(freq),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.navy),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedFrequency = freq);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Save Button with Real Firestore Targeting
                  PrimaryButton(
                    label: isSaving ? 'Scheduling Reminder...' : 'Save Reminder for ${member.name.split(" ").first}',
                    onPressed: isSaving
                        ? null
                        : () async {
                            final medicine = titleCtrl.text.trim();
                            final dose = dosageCtrl.text.trim();

                            if (medicine.isEmpty) {
                              setModalState(() => formError = 'Please enter medicine name.');
                              return;
                            }
                            if (dose.isEmpty) {
                              setModalState(() => formError = 'Please enter dosage.');
                              return;
                            }

                            final creatorUid = ref.read(currentUidProvider) ?? '';
                            final targetUid = member.memberUid != null && member.memberUid!.isNotEmpty
                                ? member.memberUid!
                                : member.id;
                            final patientId = targetUid;

                            if (targetUid.isEmpty) {
                              setModalState(() => formError = 'Family member user ID not found.');
                              return;
                            }

                            setModalState(() {
                              isSaving = true;
                              formError = null;
                            });

                            try {
                              final scheduledDateTime = DateTime(
                                now.year,
                                now.month,
                                now.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                              final docId = 'rem_${DateTime.now().millisecondsSinceEpoch}';

                              // REQUIRED VERIFICATION LOGS
                              dev.log('''
[FAMILY_REMINDER]
creatorUid = $creatorUid
targetUid = $targetUid
patientId = $patientId
reminderId = $docId
reminderTime = $timeDisplay
'''.trim(), name: 'FamilyReminder');

                              dev.log('[FAMILY_TARGET] targetUid = $targetUid', name: 'FamilyReminder');

                              // 1. Save to reminders collection
                              final reminder = Reminder(
                                id: docId,
                                title: '$medicine ($dose)',
                                medicineName: medicine,
                                dosage: dose,
                                type: ReminderType.medication,
                                dateTime: scheduledDateTime,
                                reminderTime: timeDisplay,
                                frequency: selectedFrequency,
                                status: 'pending',
                                isCompleted: false,
                                patientId: targetUid,
                                targetUid: targetUid,
                                createdBy: creatorUid,
                                creatorUid: creatorUid,
                                targetPatientName: member.name,
                                telegramEnabled: true,
                              );
                              await ref.read(reminderRepositoryProvider).addReminder(targetUid, reminder);

                              // 2. Save medication to target member's medications collection
                              // So it directly appears in target's Today's Medication!
                              final med = Medication(
                                id: docId,
                                name: medicine,
                                dosage: dose,
                                time: timeDisplay,
                                isTaken: false,
                                isSkipped: false,
                                date: scheduledDateTime,
                                patientId: targetUid,
                                frequency: selectedFrequency,
                                notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                startDate: scheduledDateTime,
                                active: true,
                              );
                              await ref.read(medicationRepositoryProvider).addMedication(targetUid, med);

                              // 3. Create target-addressed notification record in patientNotifications
                              final creatorName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Family Caregiver';
                              final notifRef = FirebaseFirestore.instance.collection('patientNotifications').doc();
                              await notifRef.set({
                                'notificationId': notifRef.id,
                                'recipientUid': targetUid,
                                'recipientRole': 'patient',
                                'senderUid': creatorUid,
                                'type': 'family_medication_reminder',
                                'title': '💊 Family Medication Reminder',
                                'message': 'Medication reminder from $creatorName: $medicine ($dose) at $timeDisplay.',
                                'reminderId': docId,
                                'status': 'sent',
                                'createdAt': FieldValue.serverTimestamp(),
                                'isRead': false,
                              });

                              dev.log('''
[FAMILY_NOTIFICATION]
creatorUid = $creatorUid
targetUid = $targetUid
patientId = $targetUid
reminderId = $docId
reminderTime = $timeDisplay
'''.trim(), name: 'FamilyReminder');

                              // Note: Creator's device schedules NOTHING (per Requirement 3).
                              // Target member's device schedules when receiving the reminder.

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Family reminder for ${member.name} ($medicine) scheduled for $timeDisplay.'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              dev.log('[FAMILY_REMINDER ERROR] $e', error: e, name: 'FamilyReminder');
                              setModalState(() {
                                isSaving = false;
                                formError = 'Failed to save reminder: $e';
                              });
                            }
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
