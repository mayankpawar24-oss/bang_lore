import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/twin_state_model.dart';
import '../../../../data/services/backend_service.dart';

/// Interactive developer & clinician console for triggering and inspecting
/// the 7 TWIN Autonomous Loop scenarios through real backend domain events.
class TwinScenarioConsoleSheet extends StatefulWidget {
  final String patientId;
  final BackendService backendService;
  final VoidCallback? onScenarioTriggered;

  const TwinScenarioConsoleSheet({
    super.key,
    required this.patientId,
    required this.backendService,
    this.onScenarioTriggered,
  });

  static Future<void> show(
    BuildContext context, {
    required String patientId,
    required BackendService backendService,
    VoidCallback? onScenarioTriggered,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TwinScenarioConsoleSheet(
        patientId: patientId,
        backendService: backendService,
        onScenarioTriggered: onScenarioTriggered,
      ),
    );
  }

  @override
  State<TwinScenarioConsoleSheet> createState() => _TwinScenarioConsoleSheetState();
}

class _TwinScenarioConsoleSheetState extends State<TwinScenarioConsoleSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = false;
  String? _loadingScenario;
  int _countdownSeconds = 0;
  Timer? _countdownTimer;

  TwinScenarioResult? _lastResult;
  List<Map<String, dynamic>> _recentTraces = [];
  List<TwinInAppNotification> _activeNotifications = [];
  String? _statusMessage;
  bool _statusIsError = false;

  final List<Map<String, dynamic>> _scenarios = [
    {
      'id': 'sedentary',
      'title': '1. Prolonged Sedentary Period',
      'icon': LucideIcons.armchair,
      'badge': 'SITUATION',
      'badgeColor': AppColors.warning,
      'description':
          'Inactivity ≥ 60m → Situation Evaluation → Contextual Opportunity → FollowUpPlan created → Notification queued.',
      'expectedOutcome': 'Proactive movement break recommendation with 7-stage trace.',
    },
    {
      'id': 'low-activity',
      'title': '2. Low Daily Activity',
      'icon': LucideIcons.footprints,
      'badge': 'OPPORTUNITY',
      'badgeColor': AppColors.info,
      'description':
          'Step progress behind daily target in late afternoon → Context window evaluated → Non-intrusive activity suggestion.',
      'expectedOutcome': 'Goal catch-up recommendation with daylight feasibility check.',
    },
    {
      'id': 'appointment',
      'title': '3. Upcoming Appointment',
      'icon': LucideIcons.calendarClock,
      'badge': 'SENTINEL',
      'badgeColor': AppColors.primary,
      'description':
          'APPOINTMENT_CREATED → SENTINEL routing → FollowUpEngine schedules plan → DurableScheduler claims → In-App Notification dispatched.',
      'expectedOutcome': 'Automated 2-hour appointment reminder banner ready for patient response.',
    },
    {
      'id': 'missed-appointment',
      'title': '4. Missed Appointment Recovery',
      'icon': LucideIcons.calendarX,
      'badge': 'CARE GAP',
      'badgeColor': AppColors.danger,
      'description':
          'MISSED_APPOINTMENT event → Autonomous care-gap follow-up registered with HIGH priority → Reschedule action prompted.',
      'expectedOutcome': 'Urgent care recovery alert with one-tap reschedule prompt.',
    },
    {
      'id': 'elevated-heart-rate',
      'title': '5. Elevated Resting HR Context',
      'icon': LucideIcons.heartPulse,
      'badge': 'SAFETY/GUARDIAN',
      'badgeColor': AppColors.danger,
      'description':
          'HR 115 BPM detected while STATIONARY → Evaluated against personal resting baseline (72 BPM) → Cautious non-diagnostic prompt.',
      'expectedOutcome': 'Rest & hydration wellness advice (GUARDIAN non-diagnostic policy verified).',
    },
    {
      'id': 'real-sensor-outcome',
      'title': '6. Real Sensor Closed-Loop & Learning',
      'icon': LucideIcons.sparkles,
      'badge': 'CLOSED-LOOP',
      'badgeColor': AppColors.success,
      'description':
          'Movement rec accepted → User walks (+165 steps detected by phone sensors) → Closed-loop outcome COMPLETED → Behavioral memory reinforced.',
      'expectedOutcome': 'Closed-loop outcome marked COMPLETED; learning pattern updated.',
    },
    {
      'id': 'negative-suppression',
      'title': '7. Negative Decisions & Suppressions',
      'icon': LucideIcons.shieldAlert,
      'badge': 'GOVERNANCE',
      'badgeColor': Colors.purple,
      'description':
          'Tests 4 suppression gates: Rapid phone rotation (suppressed), High HR during exercise (benign), Active cooldown (cooldown gate), Quiet hours (night silence).',
      'expectedOutcome': '4 deterministic NO ACTION / SUPPRESSED records with audit reasons.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTraces();
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTraces() async {
    try {
      final traces = await widget.backendService.getTwinScenarioTraces(widget.patientId);
      if (mounted) {
        setState(() {
          _recentTraces = traces.reversed.toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadNotifications() async {
    try {
      final notifs = await widget.backendService.getActiveNotifications(widget.patientId);
      if (mounted) {
        setState(() {
          _activeNotifications = notifs;
        });
      }
    } catch (_) {}
  }

  void _triggerScenario(String scenarioId, {int delaySeconds = 0}) {
    if (_isLoading) return;

    if (delaySeconds > 0) {
      setState(() {
        _loadingScenario = scenarioId;
        _countdownSeconds = delaySeconds;
        _statusMessage = 'Triggering $scenarioId in $delaySeconds seconds...';
        _statusIsError = false;
      });

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _countdownSeconds--;
        });
        if (_countdownSeconds <= 0) {
          timer.cancel();
          _executeScenario(scenarioId);
        }
      });
    } else {
      _executeScenario(scenarioId);
    }
  }

  Future<void> _executeScenario(String scenarioId) async {
    setState(() {
      _isLoading = true;
      _loadingScenario = scenarioId;
      _statusMessage = 'Executing scenario: $scenarioId through real event engine...';
      _statusIsError = false;
    });

    try {
      final result = await widget.backendService.triggerTwinScenario(
        patientId: widget.patientId,
        scenarioName: scenarioId,
      );

      if (mounted) {
        setState(() {
          _lastResult = result;
          _isLoading = false;
          _loadingScenario = null;
          _statusMessage = '✓ Scenario "$scenarioId" completed successfully!';
          _statusIsError = false;
        });
        _loadTraces();
        _loadNotifications();
        widget.onScenarioTriggered?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingScenario = null;
          _statusMessage = 'Error running scenario: $e';
          _statusIsError = true;
        });
      }
    }
  }

  Future<void> _triggerSchedulerCycle() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Running DurableScheduler scan-and-claim cycle...';
      _statusIsError = false;
    });

    try {
      final res = await widget.backendService.triggerDurableScheduler(widget.patientId);
      final claimed = res['claimed_plans_count'] ?? 0;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '✓ Scheduler cycle finished. Claimed plans: $claimed';
          _statusIsError = false;
        });
        _loadTraces();
        _loadNotifications();
        widget.onScenarioTriggered?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Scheduler error: $e';
          _statusIsError = true;
        });
      }
    }
  }

  Future<void> _acknowledgeNotification(String notifId) async {
    try {
      final ok = await widget.backendService.acknowledgeNotification(
        patientId: widget.patientId,
        notificationId: notifId,
      );
      if (ok && mounted) {
        setState(() {
          _activeNotifications.removeWhere((n) => n.notificationId == notifId);
          _statusMessage = '✓ Notification acknowledged & follow-up updated';
          _statusIsError = false;
        });
        widget.onScenarioTriggered?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Ack error: $e';
          _statusIsError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.terminal, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TWIN Autonomous Console',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '7 Real Domain Scenarios • Patient: ${widget.patientId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _statusIsError
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _statusIsError
                      ? AppColors.danger.withValues(alpha: 0.3)
                      : AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIsError ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
                    color: _statusIsError ? AppColors.danger : AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusIsError ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ),
                  if (_countdownSeconds > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_countdownSeconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              const Tab(text: 'Scenarios'),
              Tab(
                text: _lastResult != null
                    ? 'Pipeline Flow (${_lastResult!.pipelineStages.length})'
                    : 'Pipeline Flow',
              ),
              Tab(text: 'Traces (${_recentTraces.length})'),
              Tab(
                text: _activeNotifications.isNotEmpty
                    ? 'Alerts (${_activeNotifications.length})'
                    : 'Scheduler & Alerts',
              ),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScenariosTab(),
                _buildPipelineTab(),
                _buildTracesTab(),
                _buildSchedulerAndAlertsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenariosTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _scenarios.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == _scenarios.length) {
          return _buildSchedulerTriggerCard();
        }
        final scen = _scenarios[index];
        final id = scen['id'] as String;
        final isSelectedLoading = _isLoading && _loadingScenario == id;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelectedLoading
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.6),
              width: isSelectedLoading ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (scen['badgeColor'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      scen['icon'] as IconData,
                      color: scen['badgeColor'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scen['title'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (scen['badgeColor'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            scen['badge'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: scen['badgeColor'] as Color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                scen['description'] as String,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.arrowRight, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        scen['expectedOutcome'] as String,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _triggerScenario(id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isSelectedLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Trigger Now',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _triggerScenario(id, delaySeconds: 5),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'in 5s',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _triggerScenario(id, delaySeconds: 10),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'in 10s',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSchedulerTriggerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.clock, color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Text(
                'DurableScheduler Engine',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Force an immediate scan-and-claim cycle on the persistent task scheduler to publish FOLLOW_UP_DUE for any pending care tasks.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _triggerSchedulerCycle,
              icon: const Icon(LucideIcons.play, size: 16),
              label: const Text('Run Scheduler Cycle Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineTab() {
    if (_lastResult == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.gitFork, size: 48, color: AppColors.border),
              const SizedBox(height: 16),
              const Text(
                'No Active Pipeline Execution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select any of the 7 scenarios in the Scenarios tab to see the live 10-stage autonomous pipeline progression.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final res = _lastResult!;
    final stages = res.pipelineStages;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      res.scenario.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      res.status,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                res.summary,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Correlation ID: ${res.correlationId}',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                ),
              ),
              if (res.eventId != null)
                Text(
                  'Event ID: ${res.eventId}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
              if (res.recommendationId != null)
                Text(
                  'Rec ID: ${res.recommendationId}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Pipeline Execution Stages',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        ...stages.asMap().entries.map((entry) {
          final idx = entry.key;
          final stage = entry.value;
          final isLast = idx == stages.length - 1;

          Color badgeColor = AppColors.primary;
          IconData stageIcon = LucideIcons.circleDot;
          if (stage.status.contains('TRIGGERED') || stage.status.contains('OPTIMAL')) {
            badgeColor = AppColors.info;
            stageIcon = LucideIcons.zap;
          } else if (stage.status.contains('ACTIVE') || stage.status.contains('DISPATCHED')) {
            badgeColor = AppColors.primary;
            stageIcon = LucideIcons.bell;
          } else if (stage.status.contains('COMPLETED') || stage.status.contains('UPDATED') || stage.status.contains('ACCEPTED')) {
            badgeColor = AppColors.success;
            stageIcon = LucideIcons.checkCircle2;
          } else if (stage.status.contains('SUPPRESSED') || stage.status.contains('NO_ACTION')) {
            badgeColor = Colors.purple;
            stageIcon = LucideIcons.shieldCheck;
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: badgeColor, width: 2),
                      ),
                      child: Icon(stageIcon, size: 16, color: badgeColor),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${idx + 1}. ${stage.stage}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  stage.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            stage.detail,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          if (stage.timestamp.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              stage.timestamp,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textLight,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        if (res.suppressionReasons.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Audited Suppression Gates (NO ACTION Decisions)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...res.suppressionReasons.map((gate) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.shieldAlert, size: 16, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        gate['gate'] ?? 'Gate',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        gate['decision'] ?? 'SUPPRESSED',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gate['reason'] ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildTracesTab() {
    if (_recentTraces.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.listTree, size: 48, color: AppColors.border),
              const SizedBox(height: 16),
              const Text(
                'No Technical Traces Recorded',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Trigger any scenario to see its technical trace containing event identifiers, timestamps, and routing info.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _recentTraces.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trace = _recentTraces[index];
        final scen = trace['scenario'] as String? ?? 'unknown';
        final crl = trace['correlation_id'] as String? ?? '';
        final evtId = trace['event_id'] as String? ?? '';
        final recId = trace['recommendation_id'] as String? ?? '';
        final tech = trace['technical_trace'] as Map<String, dynamic>? ?? {};

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      scen.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(LucideIcons.cpu, size: 14, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Correlation: $crl',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              if (evtId.isNotEmpty)
                Text(
                  'Event ID: $evtId',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              if (recId.isNotEmpty)
                Text(
                  'Rec ID: $recId',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              if (tech.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tech.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSchedulerAndAlertsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSchedulerTriggerCard(),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              'Dispatched In-App Notifications',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              onPressed: _loadNotifications,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_activeNotifications.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No active dispatched notifications.\nRun Scenario 3 (Upcoming Appointment) or 4 (Missed Appointment) to generate live notifications.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ..._activeNotifications.map((notif) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.bellRing, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notif.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notif.type,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notif.body,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _acknowledgeNotification(notif.notificationId),
                        icon: const Icon(LucideIcons.check, size: 16),
                        label: const Text('Acknowledge'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
