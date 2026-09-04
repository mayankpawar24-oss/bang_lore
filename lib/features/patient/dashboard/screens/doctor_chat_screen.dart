import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/doctor_chat_model.dart';
import '../../../../data/repositories/doctor_chat_repository.dart';
import '../../../video_call/screens/video_call_screen.dart';

class DoctorChatScreen extends ConsumerStatefulWidget {
  final String doctorId;
  final String? patientId;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorAvatar;
  final String? patientName;
  final String? patientAvatar;

  const DoctorChatScreen({
    super.key,
    required this.doctorId,
    this.patientId,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorAvatar,
    this.patientName,
    this.patientAvatar,
  });

  @override
  ConsumerState<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends ConsumerState<DoctorChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String? _chatId;
  bool _isInitializing = true;
  bool _isSending = false;

  bool get _isDoctorView => widget.patientId != null && widget.patientId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initConversation());
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initConversation() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? user?.id ?? ref.read(currentUidProvider) ?? '';

    final effectivePatientId = _isDoctorView ? widget.patientId! : currentUid;
    final effectiveDoctorId = _isDoctorView ? currentUid : widget.doctorId;

    if (effectivePatientId.isEmpty || effectiveDoctorId.isEmpty) {
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    final doctors = ref.read(doctorsProvider);
    final doctor = doctors.where((d) => d.id == effectiveDoctorId).firstOrNull;

    final docName = widget.doctorName ?? doctor?.name ?? 'Doctor';
    final docSpec = widget.doctorSpecialty ?? doctor?.specialty ?? 'Specialist';
    final docAvatar = widget.doctorAvatar ?? doctor?.avatarUrl;
    final patName = widget.patientName ?? (_isDoctorView ? 'Patient' : (user?.name ?? 'Patient'));
    final patAvatar = widget.patientAvatar ?? (_isDoctorView ? null : user?.avatarUrl);

    try {
      final chatId = await ref.read(doctorChatRepositoryProvider).getOrCreateConversation(
        patientId: effectivePatientId,
        doctorId: effectiveDoctorId,
        doctorName: docName,
        doctorSpecialty: docSpec,
        doctorAvatar: docAvatar,
        patientName: patName,
        patientAvatar: patAvatar,
      );

      if (mounted) {
        setState(() {
          _chatId = chatId;
          _isInitializing = false;
        });
      }
    } catch (e) {
      dev.log('[DOCTOR_CHAT ERROR] _initConversation: $e', name: 'DoctorChatScreen');
      final fallbackId = FirebaseDoctorChatRepository.generateChatId(effectivePatientId, effectiveDoctorId);
      if (mounted) {
        setState(() {
          _chatId = fallbackId;
          _isInitializing = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _chatId == null || _isSending) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final senderId = FirebaseAuth.instance.currentUser?.uid ?? currentUser?.id ?? ref.read(currentUidProvider) ?? '';
    final senderRole = _isDoctorView ? 'doctor' : 'patient';
    final senderName = currentUser?.name ?? (_isDoctorView ? 'Doctor' : 'Patient');
    final senderPhoto = currentUser?.avatarUrl;

    _msgCtrl.clear();
    setState(() => _isSending = true);

    try {
      final receiverId = _isDoctorView ? (widget.patientId ?? '') : widget.doctorId;
      await ref.read(doctorChatRepositoryProvider).sendMessage(
        chatId: _chatId!,
        senderId: senderId,
        receiverId: receiverId,
        senderRole: senderRole,
        senderName: senderName,
        senderPhoto: senderPhoto,
        text: text,
      );
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      dev.log('[DOCTOR_CHAT ERROR] Failed to send: $e', name: 'DoctorChatScreen');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _startVideoCall() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? user?.id ?? ref.read(currentUidProvider) ?? '';
    if (currentUid.isEmpty) return;

    final isDoctor = _isDoctorView;
    final callerName = user?.name ?? (isDoctor ? 'Doctor' : 'Patient');
    final callerRole = isDoctor ? 'doctor' : 'patient';
    final callerPhoto = user?.avatarUrl;

    final receiverId = isDoctor ? (widget.patientId ?? '') : widget.doctorId;
    final receiverName = isDoctor ? (widget.patientName ?? 'Patient') : (widget.doctorName ?? 'Doctor');
    final receiverRole = isDoctor ? 'patient' : 'doctor';

    try {
      final call = await ref.read(callRepositoryProvider).startCall(
        callerId: currentUid,
        callerName: callerName,
        callerRole: callerRole,
        callerPhoto: callerPhoto,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverRole: receiverRole,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              callId: call.id,
              channelId: call.channelId,
              isCaller: true,
              otherUserName: receiverName,
              otherUserAvatar: isDoctor ? widget.patientAvatar : widget.doctorAvatar,
              otherUserRole: receiverRole,
            ),
          ),
        );
      }
    } catch (e) {
      dev.log('[VIDEO_CALL ERROR] Failed to start call: $e', name: 'DoctorChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate video call: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doctors = ref.watch(doctorsProvider);
    final doctor = doctors.where((d) => d.id == widget.doctorId).firstOrNull;

    final displayName = _isDoctorView
        ? (widget.patientName ?? 'Patient')
        : (widget.doctorName ?? doctor?.name ?? 'Doctor');
    final displaySpecialty = _isDoctorView
        ? 'Active Patient Consultation'
        : (widget.doctorSpecialty ?? doctor?.specialty ?? 'Specialist');
    final displayAvatar = _isDoctorView
        ? widget.patientAvatar
        : (widget.doctorAvatar ?? doctor?.avatarUrl);
    final currentUserId = ref.watch(currentUidProvider) ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : AppColors.navy),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : AppColors.softBlue,
              backgroundImage: (displayAvatar != null && displayAvatar.isNotEmpty) ? NetworkImage(displayAvatar) : null,
              child: (displayAvatar == null || displayAvatar.isEmpty)
                  ? Text(
                      displayName.isNotEmpty ? displayName[0] : 'D',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          displaySpecialty,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Live Video Consultation Button
          IconButton(
            icon: const Icon(LucideIcons.video, color: AppColors.primaryBlue, size: 22),
            tooltip: 'Live Video Consultation',
            onPressed: _startVideoCall,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Chat Security Notice (Flexible to prevent right overflow)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: isDark ? const Color(0xFF131C2E).withValues(alpha: 0.6) : AppColors.softBlue.withValues(alpha: 0.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Private & encrypted medical consultation between patient and doctor.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // Real-time Messages Stream
                Expanded(
                  child: _chatId == null
                      ? _buildEmptyState(displayName, isDark)
                      : Consumer(
                          builder: (context, ref, _) {
                            final messagesAsync = ref.watch(doctorChatMessagesStreamProvider(_chatId!));

                            return messagesAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('Error loading messages: $e')),
                              data: (messages) {
                                if (messages.isEmpty) {
                                  return _buildEmptyState(displayName, isDark);
                                }

                                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                                return ListView.builder(
                                  controller: _scrollCtrl,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  itemCount: messages.length,
                                  itemBuilder: (context, idx) {
                                    final msg = messages[idx];
                                    final isMe = msg.senderId == currentUserId ||
                                        (_isDoctorView ? msg.senderRole == 'doctor' : msg.senderRole == 'patient');
                                    return _buildMessageBubble(msg, isMe, isDark);
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),

                // Input Bar
                _buildInputBar(isDark),
              ],
            ),
    );
  }

  Widget _buildEmptyState(String doctorName, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131C2E) : AppColors.softBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.messageSquare, size: 36, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 16),
            Text(
              'Consultation with $doctorName',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Send a message to start your clinical consultation. All conversation history is saved securely.',
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

  Widget _buildMessageBubble(DoctorChatMessage msg, bool isMe, bool isDark) {
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
                      msg.senderName.isNotEmpty ? msg.senderName[0] : 'U',
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : (isDark ? const Color(0xFF94A3B8) : AppColors.muted),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.checkCheck, size: 12, color: Colors.white70),
                      ],
                    ],
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

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
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
                  controller: _msgCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Type your consultation message...',
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
