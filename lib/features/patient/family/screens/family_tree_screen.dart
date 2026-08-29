import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/notification_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/family_member_model.dart';
import '../../../../data/models/reminder_model.dart';

class FamilyTreeScreen extends ConsumerStatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  ConsumerState<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends ConsumerState<FamilyTreeScreen> {
  int _selectedTab = 0; // 0: Tree, 1: Reminders, 2: Features
  late PageController _pageController;

  // Editor State
  bool _isEditMode = false;
  String? _selectedMemberId;
  String? _connectingSourceId; // For drawing custom connection links

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(familyMembersProvider.notifier).loadFamilyMembers('patient_id_margaret');
      ref.read(remindersProvider.notifier).loadReminders('patient_id_margaret');
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _selectedTab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(familyMembersProvider);
    final reminders = ref.watch(remindersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildSegmentedTab(),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _selectedTab = index);
                },
                children: [
                  // Tab 1: Canva-like Interactive Tree Editor
                  _buildTreeTabContent(context, members),

                  // Tab 2: Family Reminders (Grouped & CRUD)
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: _buildRemindersTabContent(context, members, reminders),
                  ),

                  // Tab 3: Family Features (Interactive Modals)
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: _buildFeaturesTabContent(context, members),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Family',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Care together, stay stronger',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => NotificationSheet.show(context),
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(LucideIcons.bell, color: AppColors.navy, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedTab() {
    final tabs = ['Tree', 'Reminders', 'Features'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.softBlue.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isSelected = _selectedTab == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onTabTapped(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primaryBlue : AppColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // TAB 1: CANVA-LIKE INTERACTIVE FAMILY TREE
  // ==========================================

  Widget _buildTreeTabContent(BuildContext context, List<FamilyMemberModel> members) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Toolbar Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Family Canvas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  Text(
                    '${members.length} Members • Drag to position',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_isEditMode) ...[
                    GestureDetector(
                      onTap: () => _showAddMemberSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(LucideIcons.plus, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEditMode = !_isEditMode;
                        if (!_isEditMode) {
                          _selectedMemberId = null;
                          _connectingSourceId = null;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isEditMode ? AppColors.navy : AppColors.softBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isEditMode ? LucideIcons.check : LucideIcons.edit3,
                            color: _isEditMode ? Colors.white : AppColors.primaryBlue,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isEditMode ? 'Done' : 'Edit Tree',
                            style: TextStyle(
                              color: _isEditMode ? Colors.white : AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_connectingSourceId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentCyan),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🔗 Tap a target node to connect link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  GestureDetector(
                    onTap: () => setState(() => _connectingSourceId = null),
                    child: const Icon(LucideIcons.x, size: 16, color: AppColors.navy),
                  ),
                ],
              ),
            ),

          // Interactive Canva Canvas Stack
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFEFF6FF), Color(0xFFFAF5FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasWidth = constraints.maxWidth;
                    final canvasHeight = constraints.maxHeight;

                    // Ensure default positions for members if not set
                    final positions = _getCalculatedPositions(members, canvasWidth, canvasHeight);

                    return Stack(
                      children: [
                        // Background Tree Silhouette Painter
                        CustomPaint(
                          size: Size(canvasWidth, canvasHeight),
                          painter: TreeBackgroundPainter(),
                        ),

                        // Curved Connection Lines Painter
                        CustomPaint(
                          size: Size(canvasWidth, canvasHeight),
                          painter: TreeConnectorPainter(members: members, positions: positions),
                        ),

                        // Interactive Draggable Node Cards
                        ...members.map((m) {
                          final pos = positions[m.id] ?? const Offset(100, 100);
                          final isSelected = _selectedMemberId == m.id;

                          return Positioned(
                            left: pos.dx,
                            top: pos.dy,
                            child: GestureDetector(
                              onTap: () {
                                if (_connectingSourceId != null) {
                                  if (_connectingSourceId != m.id) {
                                    _connectMembers(_connectingSourceId!, m.id);
                                  }
                                  setState(() => _connectingSourceId = null);
                                  return;
                                }

                                if (_isEditMode) {
                                  setState(() => _selectedMemberId = m.id);
                                } else {
                                  context.push('/patient/family/family-member/${m.id}');
                                }
                              },
                              onPanUpdate: _isEditMode
                                  ? (details) {
                                      final newX = (pos.dx + details.delta.dx).clamp(0.0, canvasWidth - 120.0);
                                      final newY = (pos.dy + details.delta.dy).clamp(0.0, canvasHeight - 70.0);
                                      final updated = m.copyWith(positionX: newX, positionY: newY);
                                      ref.read(familyMembersProvider.notifier).updateMember(updated);
                                    }
                                  : null,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Contextual Toolbar above selected node in Edit Mode
                                  if (_isEditMode && isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.navy,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () => _showEditMemberSheet(context, m),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(LucideIcons.edit2, color: Colors.white, size: 14),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () => setState(() => _connectingSourceId = m.id),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(LucideIcons.link, color: AppColors.accentCyan, size: 14),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () => ref.read(familyMembersProvider.notifier).deleteMember(m.id),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(LucideIcons.trash2, color: AppColors.danger, size: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Node Container Card
                                  Container(
                                    width: 125,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: m.relationship == 'Self' ? AppColors.surfaceBlue : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primaryBlue
                                            : (m.relationship == 'Self'
                                                ? AppColors.primaryBlue
                                                : AppColors.border.withValues(alpha: 0.8)),
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected
                                              ? AppColors.primaryBlue.withValues(alpha: 0.25)
                                              : AppColors.navy.withValues(alpha: 0.04),
                                          blurRadius: isSelected ? 12 : 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppColors.softBlue,
                                          backgroundImage: (m.avatarUrl != null && m.avatarUrl!.isNotEmpty)
                                              ? NetworkImage(m.avatarUrl!)
                                              : null,
                                          child: (m.avatarUrl == null || m.avatarUrl!.isEmpty)
                                              ? Text(m.name.isNotEmpty ? m.name[0] : '?', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 12))
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: m.relationship == 'Self' ? AppColors.primaryBlue : AppColors.navy,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                m.relationship,
                                                style: const TextStyle(color: AppColors.secondaryText, fontSize: 9),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Map<String, Offset> _getCalculatedPositions(List<FamilyMemberModel> members, double width, double height) {
    final Map<String, Offset> result = {};

    final gen0 = members.where((m) => m.generation == 0).toList();
    final gen1 = members.where((m) => m.generation == 1).toList();
    final gen2 = members.where((m) => m.generation == 2).toList();
    final gen3 = members.where((m) => m.generation == 3).toList();

    void layoutGen(List<FamilyMemberModel> list, double y) {
      if (list.isEmpty) return;
      final step = width / (list.length + 1);
      for (int i = 0; i < list.length; i++) {
        final m = list[i];
        if (m.positionX != null && m.positionY != null) {
          result[m.id] = Offset(m.positionX!, m.positionY!);
        } else {
          final x = (step * (i + 1)) - 60;
          result[m.id] = Offset(x.clamp(10.0, width - 130.0), y);
        }
      }
    }

    layoutGen(gen0, 20);
    layoutGen(gen1, height * 0.28);
    layoutGen(gen2, height * 0.54);
    layoutGen(gen3, height * 0.78);

    return result;
  }

  void _connectMembers(String sourceId, String targetId) {
    final members = ref.read(familyMembersProvider);
    final source = members.firstWhere((m) => m.id == sourceId);
    if (!source.connectedToIds.contains(targetId)) {
      final updatedList = [...source.connectedToIds, targetId];
      final updated = source.copyWith(connectedToIds: updatedList);
      ref.read(familyMembersProvider.notifier).updateMember(updated);
    }
  }

  // ==========================================
  // TAB 2: REMINDERS CONTENT (GROUPED & CRUD)
  // ==========================================

  Widget _buildRemindersTabContent(
    BuildContext context,
    List<FamilyMemberModel> members,
    List<ReminderModel> reminders,
  ) {
    final memberNames = members.map((m) => m.name.split(' ')[0]).toList();
    if (!memberNames.contains('Margaret')) memberNames.insert(0, 'Margaret');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Family Reminders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                SizedBox(height: 2),
                Text('Grouped by family member', style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              ],
            ),
            GestureDetector(
              onTap: () => _showAddFamilyReminderSheet(context, members),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.blueToIndigo,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: const [
                    Icon(LucideIcons.plus, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Add Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...memberNames.map((name) {
          final familyReminders = reminders.where((r) => r.assignedBy == name || r.title.contains(name)).toList();
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.softBlue,
                      child: Text(name[0], style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (familyReminders.isEmpty)
                  const Text('No active reminders for this member.', style: TextStyle(color: AppColors.muted, fontSize: 12))
                else
                  ...familyReminders.map((r) => _buildReminderTile(context, r)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReminderTile(BuildContext context, ReminderModel reminder) {
    IconData icon;
    Color color;

    switch (reminder.type) {
      case ReminderType.medicine:
        icon = LucideIcons.pill;
        color = AppColors.primaryBlue;
        break;
      case ReminderType.hydration:
        icon = LucideIcons.droplet;
        color = AppColors.accentCyan;
        break;
      case ReminderType.walking:
        icon = LucideIcons.footprints;
        color = AppColors.warning;
        break;
      default:
        icon = LucideIcons.bell;
        color = AppColors.primaryBlue;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: reminder.isCompleted ? AppColors.muted : AppColors.navy,
                    decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  _formatTime(reminder.dateTime),
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          Checkbox(
            value: reminder.isCompleted,
            activeColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (val) {
              ref.read(remindersProvider.notifier).toggleReminder(reminder.id);
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.muted),
            onPressed: () {
              ref.read(remindersProvider.notifier).deleteReminder(reminder.id);
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: FEATURES CONTENT (FUNCTIONAL MODALS)
  // ==========================================

  Widget _buildFeaturesTabContent(BuildContext context, List<FamilyMemberModel> members) {
    final features = [
      {'title': 'Shared Care Board', 'desc': 'Manage family tasks & status', 'icon': LucideIcons.users, 'color': AppColors.success, 'action': () => _showCareBoardModal(context, members)},
      {'title': 'Family Chat & Updates', 'desc': 'Private family messaging', 'icon': LucideIcons.messageCircle, 'color': AppColors.primaryBlue, 'action': () => _showFamilyChatModal(context)},
      {'title': 'Health News', 'desc': 'Family wellness insights', 'icon': LucideIcons.newspaper, 'color': const Color(0xFF8B5CF6), 'action': () => _showHealthNewsModal(context)},
      {'title': 'Emergency Contacts', 'desc': 'One-tap family calling', 'icon': LucideIcons.phoneCall, 'color': AppColors.danger, 'action': () => _showEmergencyContactsModal(context)},
      {'title': 'Care Goals', 'desc': 'Track walking & hydration', 'icon': LucideIcons.target, 'color': AppColors.warning, 'action': () => _showCareGoalsModal(context)},
      {'title': 'Share Records', 'desc': 'Manage record permissions', 'icon': LucideIcons.fileText, 'color': AppColors.accentCyan, 'action': () => _showShareRecordsModal(context)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Family Features', subtitle: 'Integrated care coordination tools'),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: features.map((f) {
            final color = f['color'] as Color;
            final icon = f['icon'] as IconData;
            final title = f['title'] as String;
            final desc = f['desc'] as String;
            final action = f['action'] as VoidCallback;

            return GestureDetector(
              onTap: action,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // MODAL SHEETS & FORM ACTIONS
  // ==========================================

  void _showAddMemberSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    int gen = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Family Member', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Sarah Chen')),
              const SizedBox(height: 12),
              TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship', hintText: 'Parent, Child, Sibling, Partner, Other')),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Generation: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: gen,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Gen 0 (Grandparent)')),
                      DropdownMenuItem(value: 1, child: Text('Gen 1 (Parent/Aunt)')),
                      DropdownMenuItem(value: 2, child: Text('Gen 2 (Self/Sibling)')),
                      DropdownMenuItem(value: 3, child: Text('Gen 3 (Children)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => gen = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Save Member',
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty && relCtrl.text.isNotEmpty) {
                    final newM = FamilyMemberModel(
                      id: 'fm_${DateTime.now().millisecondsSinceEpoch}',
                      name: nameCtrl.text,
                      relationship: relCtrl.text,
                      generation: gen,
                      avatarUrl: 'https://i.pravatar.cc/150?u=${nameCtrl.text}',
                      knownConditions: [],
                      familyHistory: [],
                      careNeeds: 'General Care',
                      careTasks: [],
                      hydration: HydrationStatus.done,
                      walking: WalkingStatus.done,
                      medication: MedicationStatus.done,
                    );
                    ref.read(familyMembersProvider.notifier).addMember(newM);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMemberSheet(BuildContext context, FamilyMemberModel member) {
    final nameCtrl = TextEditingController(text: member.name);
    final relCtrl = TextEditingController(text: member.relationship);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit ${member.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Update Member',
              onPressed: () {
                final updated = member.copyWith(name: nameCtrl.text, relationship: relCtrl.text);
                ref.read(familyMembersProvider.notifier).updateMember(updated);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFamilyReminderSheet(BuildContext context, List<FamilyMemberModel> members) {
    final titleCtrl = TextEditingController();
    ReminderType selectedType = ReminderType.medicine;
    String selectedAssignee = 'Sarah';

    final names = members.map((m) => m.name.split(' ')[0]).toList();
    if (!names.contains('Sarah')) names.add('Sarah');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Family Reminder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 16),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Reminder Title', hintText: 'e.g. Drink water or Take meds')),
              const SizedBox(height: 16),
              const Text('Family Member', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: names.map((n) => ChoiceChip(
                  label: Text(n),
                  selected: selectedAssignee == n,
                  onSelected: (val) { if (val) setModalState(() => selectedAssignee = n); },
                )).toList(),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Save Family Reminder',
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty) {
                    final newR = ReminderModel(
                      id: const Uuid().v4(),
                      title: '$selectedAssignee – ${titleCtrl.text}',
                      description: '',
                      type: selectedType,
                      dateTime: DateTime.now(),
                      isCompleted: false,
                      assignedBy: selectedAssignee,
                    );
                    ref.read(remindersProvider.notifier).addReminder(newR);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Feature Modals
  void _showCareBoardModal(BuildContext context, List<FamilyMemberModel> members) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Shared Care Board', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            const Text('Tasks assigned across family members', style: TextStyle(color: AppColors.secondaryText)),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                children: members.expand((m) => m.careTasks.map((t) => ListTile(
                  title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Assigned to ${t.assignedTo ?? m.name}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(10)),
                    child: Text(t.status.name.toUpperCase(), style: const TextStyle(color: AppColors.primaryBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFamilyChatModal(BuildContext context) {
    final msgCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Family Chat & Updates', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const Divider(height: 24),
            const Expanded(
              child: Center(
                child: Text('Sarah: "Checked Mom\'s blood pressure at 9 AM — 120/80!"', style: TextStyle(color: AppColors.slate, fontSize: 14)),
              ),
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: msgCtrl, decoration: const InputDecoration(hintText: 'Type family update...'))),
                IconButton(icon: const Icon(LucideIcons.send, color: AppColors.primaryBlue), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHealthNewsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Health News For Family', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            SizedBox(height: 16),
            Text('• Heart Health: Importance of low sodium intake in seniors.\n• Hydration Tips: Drinking 8 glasses of water improves mobility.\n• Seasonal Care: Flu vaccination guide for family caregivers.', style: TextStyle(height: 1.6, color: AppColors.slate)),
          ],
        ),
      ),
    );
  }

  void _showEmergencyContactsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Emergency Contacts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(LucideIcons.phone, color: AppColors.danger), title: const Text('Sarah Chen (Daughter)'), subtitle: const Text('+1 (555) 234-5678')),
            ListTile(leading: const Icon(LucideIcons.phone, color: AppColors.danger), title: const Text('David Chen (Father)'), subtitle: const Text('+1 (555) 876-5432')),
          ],
        ),
      ),
    );
  }

  void _showCareGoalsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Care Goals & Trackers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            SizedBox(height: 16),
            Text('🎯 Daily Family Goal: 10,000 steps collective walk\n💧 Hydration Target: 2.5L per day per member\n💊 Medication Adherence: Target 95%+', style: TextStyle(height: 1.6, color: AppColors.slate)),
          ],
        ),
      ),
    );
  }

  void _showShareRecordsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share Records Securely', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            const Text('Grant secure access to family medical records to authorized caregivers.', style: TextStyle(color: AppColors.slate)),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Export Shared PDF', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}

// Tree Background Illustration CustomPainter
class TreeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryBlue.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.cubicTo(
      size.width * 0.35, size.height * 0.7,
      size.width * 0.65, size.height * 0.35,
      size.width / 2, 20,
    );

    canvas.drawPath(path, paint);

    // Soft Leaf Silhouettes
    final leafPaint = Paint()
      ..color = AppColors.success.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.45), 18, leafPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.30), 22, leafPaint);
    canvas.drawCircle(Offset(size.width * 0.48, size.height * 0.15), 14, leafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Connector Lines CustomPainter connecting member nodes
class TreeConnectorPainter extends CustomPainter {
  final List<FamilyMemberModel> members;
  final Map<String, Offset> positions;

  TreeConnectorPainter({required this.members, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.primaryBlue.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dotPaint = Paint()
      ..color = AppColors.primaryBlue
      ..style = PaintingStyle.fill;

    // Draw lines between generations or explicit connectedToIds
    for (var m in members) {
      final startPos = positions[m.id];
      if (startPos == null) continue;

      final startCenter = Offset(startPos.dx + 62, startPos.dy + 25);

      // Connect to explicit connectedToIds
      for (var targetId in m.connectedToIds) {
        final targetPos = positions[targetId];
        if (targetPos != null) {
          final targetCenter = Offset(targetPos.dx + 62, targetPos.dy + 25);
          final path = Path();
          path.moveTo(startCenter.dx, startCenter.dy);
          path.cubicTo(
            startCenter.dx, (startCenter.dy + targetCenter.dy) / 2,
            targetCenter.dx, (startCenter.dy + targetCenter.dy) / 2,
            targetCenter.dx, targetCenter.dy,
          );
          canvas.drawPath(path, linePaint);
          canvas.drawCircle(startCenter, 3, dotPaint);
          canvas.drawCircle(targetCenter, 3, dotPaint);
        }
      }

      // Default generational connections if no explicit connection exists
      if (m.connectedToIds.isEmpty && m.generation < 3) {
        final children = members.where((child) => child.generation == m.generation + 1).toList();
        for (var child in children) {
          final childPos = positions[child.id];
          if (childPos != null) {
            final childCenter = Offset(childPos.dx + 62, childPos.dy + 25);
            final path = Path();
            path.moveTo(startCenter.dx, startCenter.dy);
            path.cubicTo(
              startCenter.dx, (startCenter.dy + childCenter.dy) / 2,
              childCenter.dx, (startCenter.dy + childCenter.dy) / 2,
              childCenter.dx, childCenter.dy,
            );
            canvas.drawPath(path, linePaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TreeConnectorPainter oldDelegate) => true;
}
