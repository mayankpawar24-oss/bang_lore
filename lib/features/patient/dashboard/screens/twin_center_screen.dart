import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/twin_state_model.dart';
import '../../../../data/sensors/ble/ble_device_manager.dart';
import '../../../../data/sensors/health/health_platform_service.dart';
import '../../../../data/sensors/twin_sensor_coordinator.dart';
import '../../../../data/sensors/models/sensor_diagnostics_model.dart';
import '../../../../data/sensors/models/twin_sensor_signals.dart';
import '../../../../data/services/backend_service.dart';
import '../widgets/twin_decision_trace_sheet.dart';
import '../widgets/sensor_diagnostics_sheet.dart';

/// Dedicated Personal Activity & Behavior Twin Center.
///
/// Features:
/// - Real-time Multi-Modal Telemetry (Phone Motion, BLE HR, SpO2, ESP32 Climate, Health Platform)
/// - Personal Baselines & Adaptive Deviation Tracking
/// - Clinical Care Context (Recovery Trajectory, Meds, Care Gaps)
/// - Proactive Recommendations with 7-Stage Explainable Decision Tracing
/// - Autonomous Behavioral Memory & Routine Learning Metrics
class TwinCenterScreen extends StatefulWidget {
  final String patientId;
  final BackendService? backendService;
  final TwinSensorCoordinator? sensorCoordinator;

  const TwinCenterScreen({
    super.key,
    required this.patientId,
    this.backendService,
    this.sensorCoordinator,
  });

  @override
  State<TwinCenterScreen> createState() => _TwinCenterScreenState();
}

class _TwinCenterScreenState extends State<TwinCenterScreen> {
  late final BackendService _backend;
  late final TwinSensorCoordinator _coordinator;
  bool _ownsCoordinator = false;

  TwinStateModel? _twinState;
  TwinBehavioralMemoryModel? _memory;
  bool _isLoading = true;
  bool _isResponding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _backend = widget.backendService ?? BackendService();
    if (widget.sensorCoordinator != null) {
      _coordinator = widget.sensorCoordinator!;
      _ownsCoordinator = false;
    } else {
      _coordinator = TwinSensorCoordinator(
        patientId: widget.patientId,
        backendService: _backend,
      );
      _ownsCoordinator = true;
      _coordinator.initialize();
    }

    _coordinator.twinStateNotifier.addListener(_onTwinStateUpdated);
    _loadData();
  }

  void _onTwinStateUpdated() {
    if (mounted && _coordinator.twinStateNotifier.value != null) {
      setState(() {
        _twinState = _coordinator.twinStateNotifier.value;
        _memory = _twinState?.behavioralMemory ?? _memory;
      });
    }
  }

  @override
  void dispose() {
    _coordinator.twinStateNotifier.removeListener(_onTwinStateUpdated);
    if (_ownsCoordinator) {
      _coordinator.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stateFuture = _backend.getTwinState(widget.patientId);
      final memFuture = _backend.getTwinBehavioralMemory(widget.patientId);

      final results = await Future.wait([stateFuture, memFuture]);
      final state = results[0] as TwinStateModel?;
      final mem = results[1] as TwinBehavioralMemoryModel?;

      if (mounted) {
        setState(() {
          _twinState = state;
          _memory = mem ?? state?.behavioralMemory;
          _isLoading = false;
        });
        if (state?.activitySummary.stepsToday != null) {
          _coordinator.seedInitialSteps(state!.activitySummary.stepsToday ?? 0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load TWIN telemetry: $e';
        });
      }
    }
  }

  Future<void> _handleRecommendationAction(String recId, String action) async {
    setState(() => _isResponding = true);
    try {
      await _backend.respondToTwinRecommendation(widget.patientId, recId, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'ACCEPTED'
                  ? 'Recommendation accepted. Follow-up plan scheduled!'
                  : 'Recommendation dismissed. Behavioral backoff registered.',
            ),
            backgroundColor: action == 'ACCEPTED' ? Colors.green.shade800 : Colors.grey.shade800,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TWIN Center',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Personal Context & Behavior Twin',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.gauge, color: Color(0xFF3B82F6)),
            tooltip: 'Sensor Diagnostics (Dev)',
            onPressed: () => SensorDiagnosticsSheet.show(context, _coordinator),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Sync & Refresh',
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Synchronizing Personal Behavior Twin...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertTriangle, size: 16, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 1. Connectivity Status Bar
                  _buildDeviceConnectivityBar(),
                  const SizedBox(height: 16),

                  // 2. Clinical Care Context Banner
                  _buildCareContextBanner(),
                  const SizedBox(height: 16),

                  // 3. Multi-Modal Telemetry Grid (Phone, BLE, SpO2, ESP32)
                  _buildTelemetryGrid(),
                  const SizedBox(height: 16),

                  // 4. Personal Baselines Card
                  _buildBaselinesCard(),
                  const SizedBox(height: 16),

                  // 5. Active Proactive Recommendations
                  _buildRecommendationsSection(),
                  const SizedBox(height: 16),

                  // 6. Autonomous Behavioral Memory & Learning
                  _buildBehavioralMemorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildDeviceConnectivityBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.radio, size: 16, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Device Hardware Integration',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<BleDeviceStatus>(
                  valueListenable: _coordinator.bleHrStatusNotifier,
                  builder: (ctx, status, _) => _buildSensorPill(
                    label: 'BLE Heart Rate',
                    status: status.name.toUpperCase(),
                    isConnected: status == BleDeviceStatus.connected,
                    icon: LucideIcons.heart,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<BleDeviceStatus>(
                  valueListenable: _coordinator.esp32StatusNotifier,
                  builder: (ctx, status, _) => _buildSensorPill(
                    label: 'ESP32 Climate',
                    status: status.name.toUpperCase(),
                    isConnected: status == BleDeviceStatus.connected,
                    icon: LucideIcons.thermometer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<HealthPlatformStatus>(
                  valueListenable: _coordinator.healthStatusNotifier,
                  builder: (ctx, status, _) {
                    final isConnected = status == HealthPlatformStatus.permissionsGranted;
                    return _buildSensorPill(
                      label: 'Watch Platform',
                      status: isConnected ? 'LINKED' : 'STANDBY',
                      isConnected: isConnected,
                      icon: LucideIcons.watch,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<SensorDiagnosticsData>(
            valueListenable: _coordinator.diagnosticsNotifier,
            builder: (ctx, diag, _) {
              final active = diag.accelReceiving;
              final hzText = diag.accelEstimatedHz > 0 ? '~${diag.accelEstimatedHz} Hz' : 'Active';
              return InkWell(
                onTap: () => SensorDiagnosticsSheet.show(context, _coordinator),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? Colors.blue.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? Colors.blue.shade200 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.move, size: 14, color: active ? Colors.blue.shade700 : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Phone IMU Sensors',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.blue.shade900 : Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: active ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          active ? '$hzText • Diagnostics' : 'Standby',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.blue.shade800 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSensorPill({
    required String label,
    required String status,
    required bool isConnected,
    required IconData icon,
  }) {
    final color = isConnected ? Colors.green.shade700 : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConnected ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCareContextBanner() {
    final care = _twinState?.careContext;
    final trajectory = care?.recoveryTrajectory ?? 'STABLE';
    final meds = care?.activeMedications ?? [];
    final gaps = care?.careGaps ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 18),
              const Expanded(
                child: Text(
                  'Clinical Care & Recovery Context',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trajectory,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meds.isNotEmpty
                ? 'Active Medications: ${meds.join(", ")}'
                : 'No active medications currently registered.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
          ),
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Care Gaps: ${gaps.join(", ")}',
              style: TextStyle(color: Colors.amber.shade200, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTelemetryGrid() {
    final stepGoal = _twinState?.activitySummary.stepGoal ?? 6000;
    final spo2 = _twinState?.spo2;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _coordinator.currentActivityNotifier,
        _coordinator.currentStepsNotifier,
        _coordinator.currentHeartRateNotifier,
        _coordinator.currentTemperatureNotifier,
        _coordinator.currentHumidityNotifier,
        _coordinator.diagnosticsNotifier,
      ]),
      builder: (ctx, _) {
        final liveActivity = _coordinator.currentActivityNotifier.value;
        final liveSteps = _coordinator.currentStepsNotifier.value;
        final liveHr = _coordinator.currentHeartRateNotifier.value?.bpm;
        final liveTemp = _coordinator.currentTemperatureNotifier.value ?? _twinState?.temperature;
        final liveHumidity = _coordinator.currentHumidityNotifier.value ?? _twinState?.humidity;
        final diag = _coordinator.diagnosticsNotifier.value;

        final activity = liveActivity != TwinActivityType.unknown
            ? liveActivity.label
            : (_twinState?.activitySummary.currentActivity != null &&
                    _twinState!.activitySummary.currentActivity.isNotEmpty
                ? _twinState!.activitySummary.currentActivity
                : (diag.accelReceiving ? 'Stationary' : 'Unknown'));

        final steps = liveSteps > 0
            ? liveSteps
            : (_twinState?.activitySummary.stepsToday ?? 0);

        final duration = _twinState?.activitySummary.currentDurationMinutes ?? 0;
        final hr = liveHr ?? _twinState?.heartRate;

        final activitySubtitle = liveActivity == TwinActivityType.walking
            ? 'Cadence ~${diag.currentCadence.toInt()} spm'
            : (liveActivity != TwinActivityType.unknown
                ? '${liveActivity.label} Active'
                : (diag.accelReceiving ? 'Phone IMU Active' : '$duration mins current'));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Sensor Telemetry',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Activity',
                    value: activity,
                    subtitle: activitySubtitle,
                    icon: LucideIcons.footprints,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Steps Today',
                    value: '$steps',
                    subtitle: 'Goal: $stepGoal',
                    icon: LucideIcons.flame,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Heart Rate',
                    value: hr != null ? '${hr.toInt()} BPM' : '--',
                    subtitle: liveHr != null
                        ? 'BLE Telemetry'
                        : (hr != null ? 'Telemetry Active' : 'Sensor Ready'),
                    icon: LucideIcons.heartPulse,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Blood Oxygen (SpO2)',
                    value: spo2 != null ? '${spo2.toInt()}%' : '--',
                    subtitle: spo2 != null ? (spo2 >= 95 ? 'Normal Range' : 'Low') : 'Sensor Ready',
                    icon: LucideIcons.activity,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Ambient Temperature',
                    value: liveTemp != null ? '${liveTemp.toStringAsFixed(1)} °C' : '--',
                    subtitle: 'ESP32 Telemetry',
                    icon: LucideIcons.thermometer,
                    color: Colors.indigo.shade600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Ambient Humidity',
                    value: liveHumidity != null ? '${liveHumidity.toInt()}%' : '--',
                    subtitle: 'Indoor Climate',
                    icon: LucideIcons.droplets,
                    color: Colors.cyan.shade700,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildBaselinesCard() {
    final baselines = _twinState?.baselines;
    final rhr = baselines?.restingHeartRate;
    final typSteps = baselines?.typicalDailySteps;
    final typSed = baselines?.typicalSedentaryDurationMinutes;
    final completeness = baselines?.completeness ?? 'UNKNOWN';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart2, size: 16, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Personalized Baselines',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  completeness,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBaselineColumn('Resting HR', rhr != null ? '${rhr.toInt()} bpm' : 'Building'),
              _buildBaselineColumn('Daily Steps', typSteps != null ? '$typSteps' : 'Building'),
              _buildBaselineColumn('Sedentary Limit', typSed != null ? '$typSed mins' : '60 mins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBaselineColumn(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildRecommendationsSection() {
    final recs = _twinState?.activeRecommendations
            .where((r) => r.status == 'PROPOSED' || r.status == 'ACCEPTED')
            .toList() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Proactive Recommendations',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${recs.length}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (recs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'No active interventions required. Activity and recovery patterns are optimal.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          )
        else
          ...recs.map((rec) => _buildRecommendationCard(rec)),
      ],
    );
  }

  Widget _buildRecommendationCard(TwinRecommendationModel rec) {
    final isAccepted = rec.status == 'ACCEPTED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted ? Colors.green.shade300 : Colors.blue.shade200,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAccepted ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rec.priority,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAccepted ? Colors.green.shade800 : Colors.blue.shade800,
                  ),
                ),
              ),
              const Spacer(),
              // 7-Stage Trace Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(LucideIcons.gitBranch, size: 14),
                label: const Text('Decision Trace', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  TwinDecisionTraceSheet.show(
                    context,
                    patientId: widget.patientId,
                    recommendationId: rec.recommendationId,
                    backendService: _backend,
                    recommendation: rec,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rec.personalizedText ?? rec.reason,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 8),
          // Evidence references
          ...rec.evidenceReferences.map((ref) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.check, size: 12, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ref,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              )),
          if (!isAccepted) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isResponding
                      ? null
                      : () => _handleRecommendationAction(rec.recommendationId, 'DISMISSED'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isResponding
                      ? null
                      : () => _handleRecommendationAction(rec.recommendationId, 'ACCEPTED'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Accept', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.checkCircle2, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Accepted • Sensor validation in progress',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBehavioralMemorySection() {
    final mem = _memory;
    final acceptRate = mem != null ? (mem.acceptanceRate * 100).toInt() : 0;
    final completeRate = mem != null ? (mem.completionRate * 100).toInt() : 0;
    final patterns = mem?.patterns ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.brain, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Behavioral Memory & Adaptive Routines',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMemoryMetricTile(
                  title: 'Acceptance Rate',
                  percentage: acceptRate,
                  subtitle: '${mem?.totalRecommendationsAccepted ?? 0} accepted',
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMemoryMetricTile(
                  title: 'Completion Rate',
                  percentage: completeRate,
                  subtitle: '${mem?.totalRecommendationsCompleted ?? 0} confirmed',
                  color: Colors.indigo.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Learned patterns list
          const Text(
            'Learned Habits & Timing Patterns:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (patterns.isEmpty)
            Text(
              'No behavioral patterns learned yet. Patterns will form as you interact with recommendations.',
              style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            )
          else
            ...patterns.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.sparkles, size: 14, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.patternType,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              p.description,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(p.confidence * 100).toInt()}% conf',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildMemoryMetricTile({
    required String title,
    required int percentage,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$percentage%',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
