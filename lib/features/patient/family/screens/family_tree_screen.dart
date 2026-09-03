import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/notification_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/family_member_model.dart';
import '../../../../data/models/reminder_model.dart';
import '../../../../data/models/user_model.dart';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/models/patient_model.dart';
import '../../../../data/models/medication_model.dart';
import '../../../../data/models/family_relationship_model.dart';
import 'package:intl/intl.dart';
import '../widgets/family_chat_view.dart';

class FamilyTreeScreen extends ConsumerStatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  ConsumerState<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends ConsumerState<FamilyTreeScreen> {
  int _selectedTab = 0; // 0: Tree, 1: Reminders, 2: Features
  final TransformationController _transformationController = TransformationController();

  // Editor State
  bool _isEditMode = false;
  String? _selectedMemberId;
  String? _connectingSourceId; // For drawing custom connection links
  String? _draggingMemberId;
  final Map<String, Offset> _localPositions = {};
  bool _didInitializeCanvasCenter = false;

  void _centerCanvasOnce(double canvasWidth, double canvasHeight, double virtualWidth, double virtualHeight) {
    if (_didInitializeCanvasCenter) return;
    _didInitializeCanvasCenter = true;
    final initialX = (canvasWidth / 2) - (virtualWidth / 2);
    final initialY = (canvasHeight / 2) - 380.0;
    _transformationController.value = Matrix4.identity()..setTranslationRaw(initialX, initialY, 0.0);
  }

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        ref.read(familyMembersProvider.notifier).loadFamilyMembers(uid);
        ref.read(remindersProvider.notifier).loadReminders(uid);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final members = ref.watch(familyMembersProvider);
    final reminders = ref.watch(remindersProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildHeader(context, isDark),
                  const SizedBox(height: 16),
                  _buildSegmentedTab(isDark),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: _isEditMode ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() => _selectedTab = idx);
                },
                children: [
                  // Tab 0: Family Tree Canvas (with member list at bottom)
                  _buildTreeTabContent(context, members, isDark),

                  // Tab 1: Family Reminders
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: _buildRemindersTabContent(context, members, reminders, isDark),
                  ),

                  // Tab 2: Family Group Chat
                  FamilyChatView(members: members),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Family',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Care together, stay stronger',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Emergency SOS',
              onPressed: () => _showEmergencyContactsModal(context, isDark),
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131C2E) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: isDark ? 0.2 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.phoneCall, color: AppColors.danger, size: 20),
              ),
            ),
            IconButton(
              onPressed: () => NotificationSheet.show(context),
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131C2E) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.border.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(LucideIcons.bell, color: isDark ? Colors.white : AppColors.navy, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentedTab(bool isDark) {
    final tabs = ['Tree', 'Reminders', 'Chat'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131C2E)
            : AppColors.softBlue.withValues(alpha: 0.5),
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
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.05),
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
                      color: isSelected
                          ? (isDark ? Colors.white : AppColors.primaryBlue)
                          : (isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
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

  Widget _buildTreeTabContent(BuildContext context, List<FamilyMemberModel> members, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Toolbar Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Canvas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    Text(
                      '${members.length} Members • Drag to position',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  if (_isEditMode) ...[
                    GestureDetector(
                      onTap: () => _showAddMemberSheet(context, isDark),
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
                        color: _isEditMode
                            ? (isDark ? const Color(0xFF2563EB) : AppColors.navy)
                            : (isDark ? const Color(0xFF131C2E) : AppColors.softBlue),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isEditMode ? LucideIcons.check : LucideIcons.edit3,
                            color: _isEditMode
                                ? Colors.white
                                : (isDark ? Colors.white : AppColors.primaryBlue),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isEditMode ? 'Done' : 'Edit Tree',
                            style: TextStyle(
                              color: _isEditMode
                                  ? Colors.white
                                  : (isDark ? Colors.white : AppColors.primaryBlue),
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
                  Text(
                    '🔗 Tap a target node to connect link',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _connectingSourceId = null),
                    child: Icon(LucideIcons.x, size: 16, color: isDark ? Colors.white : AppColors.navy),
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
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.border.withValues(alpha: 0.7),
                  ),
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF131C2E), Color(0xFF0B1329)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFF0FDF4), Color(0xFFEFF6FF), Color(0xFFFAF5FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.3 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasWidth = constraints.maxWidth;
                    final canvasHeight = constraints.maxHeight;

                    if (members.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.users,
                              size: 48,
                              color: isDark ? const Color(0xFF64748B) : AppColors.muted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Family Members Added Yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add your family members to start building your care tree.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddMemberSheet(context, isDark),
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('Add First Family Member'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    const virtualWidth = 1600.0;
                    const virtualHeight = 1200.0;
                    _centerCanvasOnce(canvasWidth, canvasHeight, virtualWidth, virtualHeight);

                    final calculatedPositions = _getCalculatedPositions(members, virtualWidth, virtualHeight);
                    for (final m in members) {
                      if (_draggingMemberId != m.id) {
                        if (m.positionX != null && m.positionY != null) {
                          _localPositions[m.id] = Offset(m.positionX!, m.positionY!);
                        } else if (!_localPositions.containsKey(m.id)) {
                          _localPositions[m.id] = calculatedPositions[m.id] ?? const Offset(100, 100);
                        }
                      }
                    }

                    final positions = _localPositions;

                    return InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(600),
                      minScale: 0.35,
                      maxScale: 2.5,
                      panAxis: PanAxis.free,
                      panEnabled: !_isEditMode && _draggingMemberId == null,
                      scaleEnabled: !_isEditMode && _draggingMemberId == null,
                      constrained: false,
                      child: SizedBox(
                        width: virtualWidth,
                        height: virtualHeight,
                        child: Stack(
                          children: [
                            // Background Tree Silhouette Painter
                            CustomPaint(
                              size: Size(virtualWidth, virtualHeight),
                              painter: TreeBackgroundPainter(),
                            ),

                            // Curved Connection Lines Painter
                            CustomPaint(
                              size: Size(virtualWidth, virtualHeight),
                              painter: TreeConnectorPainter(members: members, positions: positions),
                            ),

                            // Interactive Draggable Node Cards
                            ...members.map((m) {
                              final pos = positions[m.id] ?? calculatedPositions[m.id] ?? const Offset(100, 100);
                              final isSelected = _selectedMemberId == m.id;
                              final isDragging = _draggingMemberId == m.id;

                              return AnimatedPositioned(
                                duration: isDragging ? Duration.zero : const Duration(milliseconds: 180),
                                curve: Curves.easeOutQuad,
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
                                  onPanStart: _isEditMode
                                      ? (_) => setState(() {
                                          _draggingMemberId = m.id;
                                          _selectedMemberId = m.id;
                                          _localPositions[m.id] = pos;
                                        })
                                      : null,
                                  onPanUpdate: _isEditMode
                                      ? (details) {
                                          final currentPos = _localPositions[m.id] ?? pos;
                                          final scale = _transformationController.value.getMaxScaleOnAxis();
                                          final effectiveScale = scale > 0 ? scale : 1.0;
                                          final newX = (currentPos.dx + details.delta.dx / effectiveScale).clamp(20.0, virtualWidth - 140.0);
                                          final newY = (currentPos.dy + details.delta.dy / effectiveScale).clamp(20.0, virtualHeight - 90.0);
                                          setState(() {
                                            _localPositions[m.id] = Offset(newX, newY);
                                          });
                                        }
                                      : null,
                                  onPanEnd: _isEditMode
                                      ? (_) {
                                          final finalPos = _localPositions[m.id];
                                          setState(() => _draggingMemberId = null);
                                          if (finalPos != null) {
                                            final updated = m.copyWith(positionX: finalPos.dx, positionY: finalPos.dy);
                                            ref.read(familyMembersProvider.notifier).updateMember(updated);
                                            final currentUid = ref.read(currentUidProvider);
                                            if (currentUid != null && m.memberUid != null && m.memberUid!.isNotEmpty) {
                                              final relId = 'rel_${currentUid}_${m.memberUid}';
                                              ref.read(patientResolutionServiceProvider).updateNodePosition(relId, finalPos.dx, finalPos.dy);
                                            }
                                          }
                                        }
                                      : null,
                                  child: AnimatedScale(
                                    scale: isSelected ? 1.04 : 1.0,
                                    duration: const Duration(milliseconds: 150),
                                    curve: Curves.easeOut,
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
                                                  onTap: () => _showEditMemberSheet(context, m, isDark),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(LucideIcons.edit2, color: Colors.white, size: 14),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                InkWell(
                                                  onTap: () => setState(() => _connectingSourceId = m.id),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(4),
                                                    child: Icon(
                                                      LucideIcons.link,
                                                      color: _connectingSourceId == m.id ? AppColors.accentCyan : Colors.white,
                                                      size: 14,
                                                    ),
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

                                        // Node Body Card
                                        Container(
                                          width: 120,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.primaryBlue
                                                  : (m.relationship == 'Self'
                                                      ? AppColors.primaryBlue.withValues(alpha: 0.5)
                                                      : (isDark
                                                          ? Colors.white.withValues(alpha: 0.1)
                                                          : AppColors.border)),
                                              width: isSelected ? 2 : 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isSelected
                                                    ? AppColors.primaryBlue.withValues(alpha: 0.25)
                                                    : const Color(0xFF0F172A).withValues(alpha: isDark ? 0.3 : 0.04),
                                                blurRadius: isSelected ? 12 : 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: isDark
                                                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                                                    : AppColors.softBlue,
                                                backgroundImage: (m.avatarUrl != null && m.avatarUrl!.isNotEmpty)
                                                    ? NetworkImage(m.avatarUrl!)
                                                    : null,
                                                child: (m.avatarUrl == null || m.avatarUrl!.isEmpty)
                                                    ? Text(
                                                        m.name.isNotEmpty ? m.name[0] : '?',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primaryBlue,
                                                          fontSize: 12,
                                                        ),
                                                      )
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
                                                        color: m.relationship == 'Self'
                                                            ? AppColors.primaryBlue
                                                            : (isDark ? Colors.white : AppColors.navy),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      m.relationship,
                                                      style: TextStyle(
                                                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                                                        fontSize: 9,
                                                      ),
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
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
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
    final gen4 = members.where((m) => m.generation >= 4).toList();

    void layoutGen(List<FamilyMemberModel> list, double y) {
      if (list.isEmpty) return;
      final step = width / (list.length + 1);
      for (int i = 0; i < list.length; i++) {
        final m = list[i];
        if (m.positionX != null && m.positionY != null) {
          result[m.id] = Offset(
            m.positionX!.clamp(20.0, width - 140.0),
            m.positionY!.clamp(20.0, height - 90.0),
          );
        } else {
          final x = (step * (i + 1)) - 60;
          result[m.id] = Offset(x.clamp(20.0, width - 140.0), y.clamp(20.0, height - 90.0));
        }
      }
    }

    layoutGen(gen0, 80.0);
    layoutGen(gen1, 220.0);
    layoutGen(gen2, 380.0);
    layoutGen(gen3, 540.0);
    layoutGen(gen4, 700.0);

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
    bool isDark,
  ) {
    final memberNames = members.map((m) => m.name.split(' ')[0]).toList();
    final userName = ref.watch(currentUserProvider).valueOrNull?.name.split(' ')[0] ?? 'Self';
    if (!memberNames.contains(userName)) memberNames.insert(0, userName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Family Reminders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Grouped by family member',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showAddFamilyReminderSheet(context, members, isDark),
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
          return AppCard(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            elevation: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                          : AppColors.softBlue,
                      child: Text(
                        name[0],
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (familyReminders.isEmpty)
                  Text(
                    'No active reminders for this member.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : AppColors.muted,
                      fontSize: 12,
                    ),
                  )
                else
                  ...familyReminders.map((r) => _buildReminderTile(context, r, isDark)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReminderTile(BuildContext context, ReminderModel reminder, bool isDark) {
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
              color: color.withValues(alpha: isDark ? 0.25 : 0.12),
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
                    color: reminder.isCompleted
                        ? (isDark ? const Color(0xFF64748B) : AppColors.muted)
                        : (isDark ? Colors.white : AppColors.navy),
                    decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  _formatTime(reminder.dateTime),
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
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
            icon: Icon(
              LucideIcons.trash2,
              size: 16,
              color: isDark ? const Color(0xFF64748B) : AppColors.muted,
            ),
            onPressed: () {
              ref.read(remindersProvider.notifier).deleteReminder(reminder.id);
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODAL SHEETS & FORM ACTIONS
  // ==========================================

  void _showAddMemberSheet(BuildContext context, bool isDark) {
    int linkMethod = 0; // 0: ABHA ID, 1: Phone, 2: QR Code
    final abhaCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final qrCtrl = TextEditingController();
    String selectedRel = 'Parent';
    bool isSearching = false;
    UserModel? retrievedUser;
    PatientModel? retrievedPatient;
    String? searchError;

    final relationships = [
      'Parent',
      'Child',
      'Spouse',
      'Sibling',
      'Grandparent',
      'Grandchild',
      'Father',
      'Mother',
      'Son',
      'Daughter',
      'Brother',
      'Sister',
      'Other',
    ];

    int getGeneration(String rel) {
      if (['Grandparent', 'Grandfather', 'Grandmother'].contains(rel)) return 0;
      if (['Parent', 'Father', 'Mother'].contains(rel)) return 1;
      if (['Spouse', 'Sibling', 'Brother', 'Sister'].contains(rel)) return 2;
      if (['Child', 'Son', 'Daughter'].contains(rel)) return 3;
      if (['Grandchild'].contains(rel)) return 4;
      return 2;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> performLookup() async {
            setModalState(() {
              isSearching = true;
              searchError = null;
              retrievedUser = null;
              retrievedPatient = null;
            });

            try {
              final resService = ref.read(patientResolutionServiceProvider);
              Map<String, dynamic>? profile;

              if (linkMethod == 0) {
                final query = abhaCtrl.text.trim();
                if (query.isEmpty) {
                  setModalState(() {
                    searchError = 'Please enter an ABHA ID';
                    isSearching = false;
                  });
                  return;
                }
                profile = await resService.findPatientByQuery(abha: query);
              } else if (linkMethod == 1) {
                final query = phoneCtrl.text.trim();
                if (query.isEmpty) {
                  setModalState(() {
                    searchError = 'Please enter a phone number';
                    isSearching = false;
                  });
                  return;
                }
                profile = await resService.findPatientByQuery(phone: query);
              } else {
                final query = qrCtrl.text.trim();
                if (query.isEmpty) {
                  setModalState(() {
                    searchError = 'Please enter or scan QR code payload';
                    isSearching = false;
                  });
                  return;
                }
                profile = await resService.findPatientByQuery(qrCode: query);
              }

              if (profile != null) {
                final uid = profile['uid'] as String? ?? profile['id'] as String? ?? '';
                retrievedUser = UserModel(
                  id: uid,
                  name: profile['name'] as String? ?? 'Family Member',
                  email: profile['email'] as String? ?? '',
                  role: UserRole.patient,
                  phoneNumber: profile['phone'] as String? ?? profile['phoneNumber'] as String?,
                  abhaId: profile['abhaNumber'] as String? ?? profile['abhaId'] as String?,
                );
                retrievedPatient = PatientModel(
                  id: uid,
                  name: retrievedUser!.name,
                  age: profile['age'] as int? ?? 35,
                  condition: profile['condition'] as String? ?? 'General Care',
                  status: profile['status'] as String? ?? 'stable',
                  medicationAdherence: 100.0,
                  isAuthorized: true,
                  conditions: [profile['condition'] as String? ?? 'General Care'],
                  phoneNumber: retrievedUser!.phoneNumber,
                  abhaId: retrievedUser!.abhaId,
                  phone: retrievedUser!.phoneNumber,
                  avatarUrl: profile['avatar'] as String?,
                  bloodGroup: profile['bloodGroup'] as String? ?? 'Not specified',
                );
              } else {
                searchError = 'Family member not found';
              }
            } catch (e) {
              searchError = 'Lookup failed: $e';
            } finally {
              setModalState(() => isSearching = false);
            }
          }

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
                  Center(
                    child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Family Node',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Link verified family members using their ABHA ID, phone number, or QR code.',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText, fontSize: 12),
                  ),
                  const SizedBox(height: 18),

                  // Relationship Selection
                  Text(
                    'Relationship to You',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRel,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.navy, fontWeight: FontWeight.bold),
                        items: relationships.map((rel) {
                          return DropdownMenuItem(value: rel, child: Text(rel));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedRel = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Verified Identifier Method Selector
                  Text(
                    'Verified Continuum Identifier',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildAddOptionChip(
                        label: 'ABHA ID',
                        icon: LucideIcons.creditCard,
                        isSelected: linkMethod == 0,
                        isDark: isDark,
                        onTap: () => setModalState(() {
                          linkMethod = 0;
                          retrievedUser = null;
                          searchError = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildAddOptionChip(
                        label: 'Phone',
                        icon: LucideIcons.phone,
                        isSelected: linkMethod == 1,
                        isDark: isDark,
                        onTap: () => setModalState(() {
                          linkMethod = 1;
                          retrievedUser = null;
                          searchError = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildAddOptionChip(
                        label: 'QR Code',
                        icon: LucideIcons.qrCode,
                        isSelected: linkMethod == 2,
                        isDark: isDark,
                        onTap: () => setModalState(() {
                          linkMethod = 2;
                          retrievedUser = null;
                          searchError = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (linkMethod == 0) ...[
                    TextField(
                      controller: abhaCtrl,
                      decoration: const InputDecoration(
                        labelText: '14-Digit ABHA ID',
                        hintText: 'e.g. 91-8472-9182-4412',
                        prefixIcon: Icon(LucideIcons.shieldCheck, color: AppColors.primaryBlue),
                      ),
                    ),
                  ] else if (linkMethod == 1) ...[
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Registered Mobile Number',
                        hintText: '+91 98765 43210',
                        prefixIcon: Icon(LucideIcons.phoneCall, color: AppColors.primaryBlue),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: qrCtrl,
                      decoration: const InputDecoration(
                        labelText: 'QR Payload / Continuum UID',
                        hintText: 'Paste scanned QR code payload',
                        prefixIcon: Icon(LucideIcons.qrCode, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isSearching ? null : performLookup,
                      icon: isSearching
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.search, size: 16),
                      label: Text(isSearching ? 'Verifying on Continuum...' : 'Retrieve Continuum Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: const BorderSide(color: AppColors.primaryBlue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  if (searchError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              searchError!,
                              style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (retrievedUser != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Verified Continuum User',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            retrievedUser!.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Age: ${retrievedPatient?.age != null ? "${retrievedPatient!.age} yrs" : "Registered"} • Blood Group: ${retrievedPatient?.bloodGroup ?? "Not specified"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                            ),
                          ),
                          if (retrievedPatient != null && retrievedPatient!.condition.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Clinical Status: ${retrievedPatient!.condition}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'UID: ${retrievedUser!.id}',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Add Node to Canvas',
                    icon: LucideIcons.userPlus,
                    onPressed: (retrievedUser == null)
                        ? null
                        : () {
                            final gen = getGeneration(selectedRel);
                            final currentMembers = ref.read(familyMembersProvider);
                            final rootSelf = currentMembers.firstWhere(
                              (m) => m.relationship == 'Self',
                              orElse: () => currentMembers.isNotEmpty
                                  ? currentMembers.first
                                  : FamilyMemberModel(
                                      id: '',
                                      name: '',
                                      relationship: '',
                                      generation: 2,
                                      knownConditions: [],
                                      familyHistory: [],
                                      careTasks: [],
                                      hydration: HydrationStatus.done,
                                      walking: WalkingStatus.done,
                                      medication: MedicationStatus.done,
                                    ),
                            );

                            final siblingCount = currentMembers.where((m) => m.relationship.toLowerCase() == selectedRel.toLowerCase()).length;
                            final center = Offset(rootSelf.positionX ?? 1200.0, rootSelf.positionY ?? 800.0);
                            final sensiblePos = FamilyRelationshipModel.calculateSensiblePosition(
                              selectedRel,
                              center: center,
                              siblingIndex: siblingCount,
                            );

                            final newM = FamilyMemberModel(
                              id: const Uuid().v4(),
                              memberUid: retrievedUser!.id,
                              name: retrievedUser!.name,
                              relationship: selectedRel,
                              generation: gen,
                              avatarUrl: 'https://i.pravatar.cc/150?u=${retrievedUser!.id.hashCode}',
                              knownConditions: retrievedPatient?.conditions ??
                                  (retrievedPatient?.condition != null && retrievedPatient!.condition.isNotEmpty
                                      ? [retrievedPatient!.condition]
                                      : []),
                              familyHistory: [],
                              careNeeds: retrievedPatient?.condition ?? 'Health Monitored',
                              careTasks: [],
                              hydration: HydrationStatus.done,
                              walking: WalkingStatus.done,
                              medication: MedicationStatus.done,
                              positionX: sensiblePos.dx,
                              positionY: sensiblePos.dy,
                              connectedToIds: rootSelf.id.isNotEmpty ? [rootSelf.id] : [],
                              phoneNumber: retrievedUser!.phoneNumber,
                              abhaId: retrievedUser!.abhaId,
                              age: retrievedPatient?.age,
                              gender: null,
                              familyId: (() {
                                final currentUidNow = ref.read(currentUidProvider) ?? '';
                                if (currentUidNow.isNotEmpty && retrievedUser!.id.isNotEmpty) {
                                  final sortedUids = [currentUidNow, retrievedUser!.id]..sort();
                                  return 'family_${sortedUids.join("_")}';
                                }
                                return null;
                              })(),
                            );
                            ref.read(familyMembersProvider.notifier).addMember(newM);
                            final currentUid = ref.read(currentUidProvider);
                            if (currentUid != null && currentUid.isNotEmpty) {
                              ref.read(patientResolutionServiceProvider).linkFamilyMember(
                                patientId: currentUid,
                                familyMemberId: retrievedUser!.id,
                                relationship: selectedRel,
                                customX: sensiblePos.dx,
                                customY: sensiblePos.dy,
                              );
                            }
                            Navigator.pop(context);
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

  Widget _buildAddOptionChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryBlue
                : (isDark ? const Color(0xFF1E293B) : AppColors.surfaceBlue),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white10 : AppColors.border),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primaryBlue),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.navy),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMemberSheet(BuildContext context, FamilyMemberModel member, bool isDark) {
    final nameCtrl = TextEditingController(text: member.name);
    final relCtrl = TextEditingController(text: member.relationship);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              Text(
                'Edit ${member.name}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
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
      ),
    );
  }

  void _showAddFamilyReminderSheet(
    BuildContext context,
    List<FamilyMemberModel> members,
    bool isDark, {
    FamilyMemberModel? preselectedMember,
  }) {
    final titleCtrl = TextEditingController();
    final dosageCtrl = TextEditingController(text: '1 tablet');
    final notesCtrl = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 2)));
    String selectedFrequency = 'Daily';
    int reminderTypeIndex = 0; // 0: Medicine, 1: Appointment, 2: General Health
    bool isSaving = false;
    String? formError;

    // Filter to linked members (excluding 'Self')
    final realMembers = members.where((m) => m.relationship != 'Self').toList();
    if (realMembers.isEmpty && members.isNotEmpty) {
      realMembers.addAll(members);
    }

    FamilyMemberModel? selectedMember = preselectedMember ?? (realMembers.isNotEmpty ? realMembers.first : null);

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
                        'Add Family Reminder',
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

                  // 1. Reminder Type Selector
                  Text(
                    'Reminder Type *',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildAddOptionChip(
                        label: 'Medicine',
                        icon: LucideIcons.pill,
                        isSelected: reminderTypeIndex == 0,
                        isDark: isDark,
                        onTap: () => setModalState(() {
                          reminderTypeIndex = 0;
                          titleCtrl.clear();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildAddOptionChip(
                        label: 'Appointment',
                        icon: LucideIcons.calendar,
                        isSelected: reminderTypeIndex == 1,
                        isDark: isDark,
                        onTap: () => setModalState(() {
                          reminderTypeIndex = 1;
                          titleCtrl.clear();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildAddOptionChip(
                        label: 'Health Goal',
                        icon: LucideIcons.activity,
                        isSelected: reminderTypeIndex == 2,
                        isDark: isDark,
                        onTap: () => setModalState(() {
                          reminderTypeIndex = 2;
                          titleCtrl.clear();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Target Family Member Selector
                  Text(
                    'Target Family Member *',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (realMembers.isEmpty)
                    Text(
                      'No family members linked yet. Please add a member first.',
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText, fontSize: 12),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: realMembers.map((m) {
                        final isSelected = selectedMember?.id == m.id;
                        return ChoiceChip(
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: isSelected ? Colors.white : AppColors.primaryBlue,
                            child: Text(
                              m.name.isNotEmpty ? m.name[0] : '?',
                              style: TextStyle(fontSize: 10, color: isSelected ? AppColors.primaryBlue : Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          label: Text('${m.name} (${m.relationship})'),
                          selected: isSelected,
                          selectedColor: AppColors.primaryBlue,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.navy),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedMember = m);
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),

                  // 3. Title / Medicine Field
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: reminderTypeIndex == 0
                          ? 'Medicine Name *'
                          : (reminderTypeIndex == 1 ? 'Doctor / Clinic / Appointment Title *' : 'Health Task / Goal Title *'),
                      hintText: reminderTypeIndex == 0
                          ? 'e.g. Metformin, Dolo 650, BP Tablet'
                          : (reminderTypeIndex == 1 ? 'e.g. Dr. Sharma - Cardiology Checkup' : 'e.g. 20 min Morning Walk, Check Blood Sugar'),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Dosage Field (Medicine only)
                  if (reminderTypeIndex == 0) ...[
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
                    const SizedBox(height: 12),
                  ],

                  // Notes / Instructions Field
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: reminderTypeIndex == 1 ? 'Location / Notes' : 'Instructions / Notes (optional)',
                      hintText: reminderTypeIndex == 1 ? 'e.g. Room 204, City Clinic' : 'e.g. After breakfast with water',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Time Picker
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

                  // 6. Frequency Selection
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

                  // 7. Save Button with Real Firestore Targeting
                  PrimaryButton(
                    label: isSaving ? 'Scheduling Reminder...' : 'Save Family Reminder',
                    onPressed: isSaving
                        ? null
                        : () async {
                            final rawTitle = titleCtrl.text.trim();
                            final dose = dosageCtrl.text.trim();

                            if (rawTitle.isEmpty) {
                              setModalState(() => formError = 'Please enter a reminder title.');
                              return;
                            }
                            if (reminderTypeIndex == 0 && dose.isEmpty) {
                              setModalState(() => formError = 'Please enter dosage.');
                              return;
                            }
                            if (selectedMember == null) {
                              setModalState(() => formError = 'Please select a target family member.');
                              return;
                            }

                            final creatorUid = ref.read(currentUidProvider) ?? '';
                            final targetUid = selectedMember!.memberUid != null && selectedMember!.memberUid!.isNotEmpty
                                ? selectedMember!.memberUid!
                                : selectedMember!.id;
                            final patientId = targetUid;
                            final familyId = selectedMember!.familyId ?? (creatorUid.isNotEmpty ? 'family_$creatorUid' : 'family_default');

                            if (targetUid.isEmpty) {
                              setModalState(() => formError = 'Selected member does not have a valid user ID.');
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

                              final typeStr = reminderTypeIndex == 0
                                  ? 'medicine'
                                  : (reminderTypeIndex == 1 ? 'appointment' : 'generalHealth');
                              final typeEnum = reminderTypeIndex == 0
                                  ? ReminderType.medication
                                  : (reminderTypeIndex == 1 ? ReminderType.appointment : ReminderType.custom);

                              final displayTitle = reminderTypeIndex == 0 ? '$rawTitle ($dose)' : rawTitle;

                              // REQUIRED VERIFICATION LOGS
                              dev.log('''
[FAMILY_REMINDER]
creatorUid = $creatorUid
targetUid = $targetUid
patientId = $patientId
reminderId = $docId
reminderTime = $timeDisplay
type = $typeStr
'''.trim(), name: 'FamilyReminder');

                              dev.log('[FAMILY_TARGET] targetUid = $targetUid', name: 'FamilyReminder');

                              // 1. Create reminder model
                              final reminder = Reminder(
                                id: docId,
                                title: displayTitle,
                                medicineName: reminderTypeIndex == 0 ? rawTitle : null,
                                dosage: reminderTypeIndex == 0 ? dose : null,
                                description: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                type: typeEnum,
                                dateTime: scheduledDateTime,
                                reminderTime: timeDisplay,
                                frequency: selectedFrequency,
                                status: 'pending',
                                isCompleted: false,
                                patientId: targetUid,
                                targetUid: targetUid,
                                createdBy: creatorUid,
                                creatorUid: creatorUid,
                                familyId: familyId,
                                targetPatientName: selectedMember!.name,
                                telegramEnabled: true,
                              );

                              // Save to reminders collection and patient's reminders subcollection
                              await FirebaseFirestore.instance.collection('reminders').doc(docId).set({
                                ...reminder.toFirestoreCreate(),
                                'createdByUserId': creatorUid,
                                'targetUserId': targetUid,
                                'familyId': familyId,
                                'type': typeStr,
                              }, SetOptions(merge: true));

                              await FirebaseFirestore.instance.collection('patients').doc(targetUid).collection('reminders').doc(docId).set({
                                ...reminder.toFirestoreCreate(),
                                'createdByUserId': creatorUid,
                                'targetUserId': targetUid,
                                'familyId': familyId,
                                'type': typeStr,
                              }, SetOptions(merge: true));

                              // 2. If medicine: save medication to target member's medications collection
                              if (reminderTypeIndex == 0) {
                                final med = Medication(
                                  id: docId,
                                  name: rawTitle,
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
                              }

                              // 3. Create target-addressed notification record in patientNotifications
                              final creatorName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Family Member';
                              final notifRef = FirebaseFirestore.instance.collection('patientNotifications').doc();
                              await notifRef.set({
                                'notificationId': notifRef.id,
                                'recipientUid': targetUid,
                                'recipientRole': 'patient',
                                'senderUid': creatorUid,
                                'type': 'family_${typeStr}_reminder',
                                'title': reminderTypeIndex == 0 ? '💊 Family Medication Reminder' : (reminderTypeIndex == 1 ? '📅 Family Appointment Reminder' : '❤️ Family Health Goal Reminder'),
                                'message': 'Reminder from $creatorName: $displayTitle at $timeDisplay.',
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

                              // Note: Creator's device schedules NOTHING (per Requirement 2 & 3).
                              // Target member's device schedules when receiving the reminder.

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Reminder for ${selectedMember!.name} ($displayTitle) scheduled for $timeDisplay.'),
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

  void _showEmergencyContactsModal(BuildContext context, bool isDark) {
    final currentUid = ref.read(currentUidProvider) ?? '';
    final patient = ref.read(currentPatientStreamProvider).valueOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.phoneCall, color: AppColors.danger, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Emergency Contacts & SOS',
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
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (patient?.emergencyContact != null && patient!.emergencyContact!.isNotEmpty)
              ListTile(
                leading: const Icon(LucideIcons.phone, color: AppColors.danger),
                title: Text(
                  'Designated Emergency Contact',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navy),
                ),
                subtitle: Text(
                  patient.emergencyContact!,
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No specific emergency contact phone saved in profile.',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),

            // Emergency SOS Trigger
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await ref.read(emergencyServiceProvider).triggerEmergencyAlert(
                    patientUid: currentUid,
                  );

                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          Icon(result.success ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
                              color: result.success ? AppColors.success : AppColors.danger),
                          const SizedBox(width: 8),
                          Text(result.success ? 'SOS Alert Dispatched' : 'Alert Notice'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.success
                                ? 'Emergency broadcast sent to care team and family.'
                                : (result.errorMessage ?? 'Failed to dispatch SOS.'),
                            style: TextStyle(color: isDark ? Colors.white : AppColors.navy),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            result.locationText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          if (result.telegramSent) ...[
                            const SizedBox(height: 8),
                            const Text(
                              '✓ Telegram emergency message delivered to connected chat.',
                              style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(LucideIcons.shieldAlert, color: Colors.white),
                label: const Text(
                  'TRIGGER EMERGENCY SOS ALERT',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
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
