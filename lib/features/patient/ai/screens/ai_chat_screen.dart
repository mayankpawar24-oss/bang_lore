import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers/providers.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

typedef AIChatScreen = AiChatScreen;

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<String> _suggestions = [
    'Did I take my medicine?',
    'When is my appointment?',
    'Find a cardiologist.',
    'Explain my report.'
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    _controller.clear();
    ref.read(chatMessagesProvider.notifier).sendMessage(text);
    
    setState(() {
      _isTyping = true;
    });
    
    _scrollToBottom();

    // Simulate AI thinking
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      setState(() {
        _isTyping = false;
      });
      // The provider handles AI response internally, but if it doesn't in our mock, 
      // we might need to add one. Assuming provider does it or we add a mock reply here.
      // We will let the provider handle it, or if it's dumb, we just mock it here if needed.
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    // Reverse messages for bottom-up scrolling
    final displayMessages = messages.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(LucideIcons.bot, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            const Text('Health Assistant', style: TextStyle(color: AppColors.textDark)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          if (messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((s) => ActionChip(
                  label: Text(s),
                  backgroundColor: AppColors.softBlue.withOpacity(0.3),
                  labelStyle: const TextStyle(color: AppColors.primaryBlue),
                  onPressed: () => _sendMessage(s),
                )).toList(),
              ).animate().fadeIn().slideY(),
            ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: displayMessages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == 0) {
                  return _buildTypingIndicator();
                }
                
                final msgIndex = _isTyping ? index - 1 : index;
                final message = displayMessages[msgIndex];
                
                return _buildMessageBubble(
                  message.content, 
                  message.isUser,
                ).animate().fadeIn().slideX(begin: message.isUser ? 0.2 : -0.2);
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Ask anything...',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.blueGradient,
                        ),
                        child: IconButton(
                          icon: const Icon(LucideIcons.send, color: Colors.white),
                          onPressed: () => _sendMessage(_controller.text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('AI insights are not medical diagnoses', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String content, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryBlue,
              child: Icon(LucideIcons.bot, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? null : Colors.white,
                gradient: isUser ? AppColors.blueGradient : null,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                  bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(20),
                ),
                boxShadow: isUser ? null : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                content,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.textDark,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 24), // Offset for symmetry
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryBlue,
            child: Icon(LucideIcons.bot, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20).copyWith(bottomLeft: const Radius.circular(4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) => 
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                ).animate(onPlay: (c) => c.repeat()).fade(duration: 400.ms, delay: (index * 150).ms)
              ),
            ),
          ),
        ],
      ),
    );
  }
}
