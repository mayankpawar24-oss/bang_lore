import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/ai_chat_model.dart';
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

  bool _isAnalyzing = false;
  int _analysisStep = 0;
  bool _isListeningVoice = false;
  bool _shareWithDoctor = false;
  String? _expandedReasoningId;

  final List<String> _suggestedPrompts = [
    'What should I do about my headache?',
    "My grandmother isn't drinking enough water.",
    'Why is my heart rate higher today?',
    'When should I take my medicine?',
    'Show me what changed in my health this week.',
  ];

  final List<String> _analysisChips = [
    'Analyzing your vitals...',
    'Checking medications & adherence...',
    'Reviewing family tree & care context...',
    'Synthesizing clinical reasoning...',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final messageText = text.trim();
    _controller.clear();

    // Trigger analysis state animation
    setState(() {
      _isAnalyzing = true;
      _analysisStep = 0;
    });

    _scrollToBottom();

    // Animate context chips
    _runAnalysisSteps();

    // Send message to Riverpod provider / Backend
    await ref.read(chatMessagesProvider.notifier).sendMessage(messageText);

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
      });
      _scrollToBottom();
    }
  }

  void _runAnalysisSteps() async {
    for (int i = 0; i < _analysisChips.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && _isAnalyzing) {
        setState(() {
          _analysisStep = i;
        });
      }
    }
  }

  void _toggleVoiceInput() {
    setState(() {
      _isListeningVoice = !_isListeningVoice;
    });

    if (_isListeningVoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listening... Speak your health question or symptom.'),
          duration: Duration(seconds: 3),
        ),
      );
      // Simulate voice recognition fill after 2.5 seconds
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _isListeningVoice) {
          setState(() {
            _controller.text = 'I feel slightly dizzy after taking my morning medicine.';
            _isListeningVoice = false;
          });
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = ref.watch(chatMessagesProvider);
    final displayMessages = messages.reversed.toList();
    final patientAsync = ref.watch(currentPatientStreamProvider);
    final patientName = patientAsync.valueOrNull?.name ?? 'Margaret';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Healthcare Assistant',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Multi-Agent Clinical Engine',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Development mode badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Development AI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              reverse: messages.isNotEmpty,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              children: [
                if (_isAnalyzing) _buildAnalyzingCard(isDark),

                ...displayMessages.map((msg) {
                  return _buildMessageItem(msg, isDark);
                }),

                if (messages.isEmpty) ...[
                  _buildPersonalizedGreeting(patientName, isDark),
                  const SizedBox(height: 20),
                  _buildSuggestedPrompts(isDark),
                ],
              ],
            ),
          ),
          _buildInputDock(isDark),
        ],
      ),
    );
  }

  Widget _buildPersonalizedGreeting(String name, bool isDark) {
    final firstName = name.split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 22,
          elevation: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.bot,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $firstName',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Your continuous health & family care intelligence center.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: isDark ? const Color(0xFF1E293B) : AppColors.border),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'Context Isolation Active — Accessing profile, vitals & family tree safely.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),
      ],
    );
  }

  Widget _buildSuggestedPrompts(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUGGESTED HEALTH QUESTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.muted,
          ),
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: 10),
        ..._suggestedPrompts.map((prompt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: AppCard(
              onTap: () => _sendMessage(prompt),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: 16,
              child: Row(
                children: [
                  const Icon(LucideIcons.messageSquare, size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      prompt,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.muted),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAnalyzingCard(bool isDark) {
    final currentChip = _analysisChips[_analysisStep % _analysisChips.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 18,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multi-Agent Pipeline Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      currentChip,
                      key: ValueKey(currentChip),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms),
    );
  }

  Widget _buildMessageItem(AIChatMessage msg, bool isDark) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.blueToIndigo,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomRight: const Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  msg.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Assistant message bubble
    final metadata = msg.metadata;
    final confidence = metadata?['confidence'] as String? ?? 'medium';
    final recommendedAction = metadata?['recommendedAction'] as String?;
    final isEmergency = recommendedAction == 'emergency' ||
        msg.content.toLowerCase().contains('emergency') ||
        msg.content.contains('911');
    final isExpanded = _expandedReasoningId == msg.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(LucideIcons.bot, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 20,
                  elevation: 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header badges
                      Row(
                        children: [
                          _ConfidenceBadge(confidence: confidence),
                          const Spacer(),
                          if (_shareWithDoctor)
                            Row(
                              children: const [
                                Icon(LucideIcons.eye, size: 12, color: AppColors.primaryBlue),
                                SizedBox(width: 4),
                                Text(
                                  'Shared with Doctor',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Emergency Warning Card if emergency detected
                      if (isEmergency) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: const [
                              Icon(LucideIcons.alertTriangle, color: Colors.red, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'URGENT MEDICAL ALERT: Call 911 or seek immediate emergency care.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      Text(
                        msg.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isDark ? Colors.white : AppColors.navy,
                        ),
                      ),

                      const SizedBox(height: 12),
                      Divider(color: isDark ? const Color(0xFF1E293B) : AppColors.border),
                      const SizedBox(height: 4),

                      // Expandable reasoning & Source Transparency section
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedReasoningId = isExpanded ? null : msg.id;
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                              size: 14,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isExpanded ? 'Hide clinical source transparency' : 'Why am I suggesting this? (Sources)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (isExpanded) ...[
                        const SizedBox(height: 10),
                        _buildSourceTransparencyCard(context, isDark),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTransparencyCard(BuildContext context, bool isDark) {
    final meds = ref.watch(medicationsStreamProvider).valueOrNull ?? [];
    final vitals = ref.watch(vitalsStreamProvider).valueOrNull ?? [];
    final reports = ref.watch(reportsStreamProvider).valueOrNull ?? [];
    final family = ref.watch(familyMembersStreamProvider).valueOrNull ?? [];

    final hasSources = meds.isNotEmpty || vitals.isNotEmpty || reports.isNotEmpty || family.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0F1D) : AppColors.surfaceBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.success),
              SizedBox(width: 6),
              Text(
                'Verified Clinical Sources Retained',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasSources)
            const Text(
              'No previous health records or vitals recorded. Advice derived from baseline clinical guidelines.',
              style: TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
            )
          else ...[
            if (meds.isNotEmpty) ...[
              _buildSourceLine(
                icon: LucideIcons.pill,
                title: 'Active Medication Context',
                detail: meds.take(2).map((m) => '${m.name} (${m.dosage})').join(', '),
                isDark: isDark,
              ),
              const SizedBox(height: 6),
            ],
            if (vitals.isNotEmpty) ...[
              _buildSourceLine(
                icon: LucideIcons.activity,
                title: 'Latest Vital Telemetry',
                detail: 'HR: ${vitals.first.heartRate} bpm, BP: ${vitals.first.systolic}/${vitals.first.diastolic}, SpO₂: ${vitals.first.spo2}%',
                isDark: isDark,
              ),
              const SizedBox(height: 6),
            ],
            if (reports.isNotEmpty) ...[
              _buildSourceLine(
                icon: LucideIcons.fileText,
                title: 'Ingested Medical Records',
                detail: reports.take(2).map((r) => r.title).join(', '),
                isDark: isDark,
              ),
              const SizedBox(height: 6),
            ],
            if (family.isNotEmpty) ...[
              _buildSourceLine(
                icon: LucideIcons.users,
                title: 'Family Care Context',
                detail: '${family.length} connected family member profiles',
                isDark: isDark,
              ),
            ],
          ],
          const SizedBox(height: 8),
          Divider(color: isDark ? Colors.white10 : AppColors.border, height: 1),
          const SizedBox(height: 6),
          const Text(
            'Multi-Agent Gating: Context Agent -> Clinical Reasoning -> Safety Sentinel. Educational guidance only.',
            style: TextStyle(color: AppColors.muted, fontSize: 10, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceLine({
    required IconData icon,
    required String title,
    required String detail,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : AppColors.navy),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: detail, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputDock(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Share with doctor privacy toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _shareWithDoctor ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 14,
                      color: _shareWithDoctor ? AppColors.primaryBlue : AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Share conversation with Doctor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _shareWithDoctor,
                  activeTrackColor: AppColors.primaryBlue,
                  onChanged: (val) => setState(() => _shareWithDoctor = val),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Input Row
            Row(
              children: [
                // Voice input button
                IconButton(
                  icon: Icon(
                    _isListeningVoice ? LucideIcons.micOff : LucideIcons.mic,
                    color: _isListeningVoice ? Colors.red : AppColors.primaryBlue,
                  ),
                  onPressed: _toggleVoiceInput,
                ),
                const SizedBox(width: 4),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.navy,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ask about symptoms, vitals, family care...',
                        hintStyle: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                GestureDetector(
                  onTap: () => _sendMessage(_controller.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.blueToIndigo,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (confidence.toLowerCase()) {
      case 'high':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green;
        label = 'High Confidence';
        break;
      case 'medium':
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = AppColors.primaryBlue;
        label = 'Clinical Reasoning';
        break;
      default:
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange;
        label = 'General Guidance';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
