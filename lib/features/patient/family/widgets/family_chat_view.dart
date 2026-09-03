import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/family_message_model.dart';
import '../../../../data/models/family_member_model.dart';
import '../../../../data/providers/providers.dart';

class FamilyChatView extends ConsumerStatefulWidget {
  final List<FamilyMemberModel> members;

  const FamilyChatView({super.key, required this.members});

  @override
  ConsumerState<FamilyChatView> createState() => _FamilyChatViewState();
}

class _FamilyChatViewState extends ConsumerState<FamilyChatView> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Resolves a canonical familyId that is IDENTICAL on both devices.
  /// Strategy:
  ///  1. If user doc has explicit familyId → use it.
  ///  2. If any connected member has familyId → use it.
  ///  3. Derive from sorted UIDs: family_{sortedA}_{sortedB} (2-person scenario)
  ///     This guarantees both User A and User B get the same string.
  String _resolveFamilyId() {
    final user = ref.read(currentUserProvider).valueOrNull;
    final currentUid = user?.id ?? ref.read(currentUidProvider) ?? '';

    // 1. Check if user document has explicit familyId
    if (user?.familyId != null && user!.familyId!.isNotEmpty) {
      return user.familyId!;
    }

    // 2. Check if any connected family member has familyId
    for (final m in widget.members) {
      if (m.familyId != null && m.familyId!.isNotEmpty) {
        return m.familyId!;
      }
    }

    // 3. If there are connected members with UIDs, produce a canonical sorted familyId
    final connectedUids = widget.members
        .where((m) => m.memberUid != null && m.memberUid!.isNotEmpty && m.relationship != 'Self')
        .map((m) => m.memberUid!)
        .toList();

    if (connectedUids.isNotEmpty && currentUid.isNotEmpty) {
      // Use all UIDs sorted to get a deterministic ID
      final allUids = {currentUid, ...connectedUids}.toList()..sort();
      return 'family_${allUids.join("_")}';
    }

    // 4. Fallback to canonical family_${currentUid}
    return currentUid.isNotEmpty ? 'family_$currentUid' : 'family_default';
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Ensure the family document exists in Firestore with memberIds populated.
  /// This is needed for Firestore security rules `request.auth.uid in resource.data.memberIds`.
  Future<void> _ensureFamilyDocExists(String familyId, String currentUserId) async {
    try {
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('families').doc(familyId);
      final snap = await docRef.get();
      final memberUids = <String>{currentUserId};
      // Include all connected member UIDs
      for (final m in widget.members) {
        if (m.memberUid != null && m.memberUid!.isNotEmpty) {
          memberUids.add(m.memberUid!);
        }
      }
      if (!snap.exists) {
        await docRef.set({
          'familyId': familyId,
          'ownerUid': currentUserId,
          'memberIds': memberUids.toList(),
          'members': memberUids.toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Merge in current user's UID into memberIds without overwriting other data
        await docRef.update({
          'memberIds': FieldValue.arrayUnion(memberUids.toList()),
          'members': FieldValue.arrayUnion(memberUids.toList()),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      dev.log('[FAMILY_CHAT] ensureFamilyDoc error: $e', name: 'FamilyChatView');
    }
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    final senderId = user?.id ?? ref.read(currentUidProvider) ?? '';
    final senderName = user?.name ?? 'Family Member';
    final senderPhoto = user?.avatarUrl;
    final familyId = _resolveFamilyId();

    _textCtrl.clear();
    setState(() => _isSending = true);

    try {
      // Ensure family doc exists with memberIds to satisfy security rules
      await _ensureFamilyDocExists(familyId, senderId);
      await ref.read(familyChatRepositoryProvider).sendFamilyGroupMessage(
        familyId: familyId,
        senderId: senderId,
        senderName: senderName,
        senderPhoto: senderPhoto,
        text: text,
      );
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      dev.log('[FAMILY_CHAT ERROR] Failed to send group message: $e', name: 'FamilyChatView');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUidProvider) ?? '';
    final familyId = _resolveFamilyId();

    final messagesAsync = ref.watch(familyGroupMessagesStreamProvider(familyId));

    return Column(
      children: [
        // Family Group Header Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131C2E) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : AppColors.softBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.users, size: 18, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Health Circle',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    Text(
                      '${widget.members.length + 1} family members connected',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(LucideIcons.lock, size: 12, color: AppColors.primaryBlue),
                    SizedBox(width: 4),
                    Text('Private', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Real-time Group Chat Messages
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Unable to load family messages: $e',
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return _buildEmptyState(isDark);
              }

              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, idx) {
                  final msg = messages[idx];
                  final isMe = msg.senderId == currentUserId;
                  return _buildGroupMessageTile(msg, isMe, isDark);
                },
              );
            },
          ),
        ),

        // Bottom Message Composer
        _buildComposer(isDark),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131C2E) : AppColors.softBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.messageCircle, size: 40, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages in Family Chat yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Share health updates, medication reminders, and coordinate care together in your private family group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupMessageTile(FamilyMessageModel msg, bool isMe, bool isDark) {
    final timeStr = DateFormat('hh:mm a').format(msg.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : AppColors.softBlue,
              backgroundImage: (msg.senderPhoto != null && msg.senderPhoto!.isNotEmpty)
                  ? NetworkImage(msg.senderPhoto!)
                  : null,
              child: (msg.senderPhoto == null || msg.senderPhoto!.isEmpty)
                  ? Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0] : '?',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primaryBlue
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe
                    ? null
                    : Border.all(color: isDark ? Colors.white10 : AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && msg.senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        msg.senderName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.accentCyan : AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: isMe ? Colors.white : (isDark ? Colors.white : AppColors.navy),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : (isDark ? const Color(0xFF94A3B8) : AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildComposer(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
                ),
                child: TextField(
                  controller: _textCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Message family care group...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _isSending ? null : _sendMessage,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(LucideIcons.send, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
