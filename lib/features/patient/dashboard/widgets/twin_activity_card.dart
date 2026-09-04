import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/twin_state_model.dart';
import '../../../../data/sensors/ble/ble_device_manager.dart';
import '../../../../data/sensors/health/health_platform_service.dart';
import '../../../../data/sensors/models/twin_sensor_signals.dart';
import '../../../../data/sensors/twin_sensor_coordinator.dart';
import '../../../../data/services/backend_service.dart';
import '../screens/twin_center_screen.dart';
import 'twin_decision_trace_sheet.dart';
import 'sensor_diagnostics_sheet.dart';

class TwinActivityCard extends StatefulWidget {
  final TwinStateModel? twinState;
  final String patientId;
  final BackendService backendService;
  final VoidCallback? onRefresh;
  final TwinSensorCoordinator? sensorCoordinator;

  const TwinActivityCard({
    super.key,
    required this.twinState,
    required this.patientId,
    required this.backendService,
    this.onRefresh,
    this.sensorCoordinator,
  });

  @override
  State<TwinActivityCard> createState() => _TwinActivityCardState();
}

class _TwinActivityCardState extends State<TwinActivityCard> {
  late TwinSensorCoordinator _coordinator;
  bool _ownsCoordinator = false;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    if (widget.sensorCoordinator != null) {
      _coordinator = widget.sensorCoordinator!;
      _ownsCoordinator = false;
    } else {
      _coordinator = TwinSensorCoordinator(
        patientId: widget.patientId,
        backendService: widget.backendService,
      );
      _ownsCoordinator = true;
      _coordinator.initialize();
    }
    if (widget.twinState?.activitySummary.stepsToday != null) {
      _coordinator.seedInitialSteps(widget.twinState!.activitySummary.stepsToday ?? 0);
    }
    _coordinator.twinStateNotifier.addListener(_onTwinStateUpdated);
  }

  void _onTwinStateUpdated() {
    if (mounted && _coordinator.twinStateNotifier.value != null) {
      setState(() {});
      widget.onRefresh?.call();
    }
  }

  @override
  void didUpdateWidget(covariant TwinActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.twinState?.activitySummary.stepsToday != null) {
      _coordinator.seedInitialSteps(widget.twinState!.activitySummary.stepsToday ?? 0);
    }
    if (widget.patientId != oldWidget.patientId ||
        widget.sensorCoordinator != oldWidget.sensorCoordinator) {
      _coordinator.twinStateNotifier.removeListener(_onTwinStateUpdated);
      if (_ownsCoordinator) {
        _coordinator.dispose();
      }
      if (widget.sensorCoordinator != null) {
        _coordinator = widget.sensorCoordinator!;
        _ownsCoordinator = false;
      } else {
        _coordinator = TwinSensorCoordinator(
          patientId: widget.patientId,
          backendService: widget.backendService,
        );
        _ownsCoordinator = true;
        _coordinator.initialize();
      }
      _coordinator.twinStateNotifier.addListener(_onTwinStateUpdated);
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

  Future<void> _handleRecommendationAction(
    String recommendationId,
    String action,
  ) async {
    setState(() => _isResponding = true);
    try {
      await widget.backendService.respondToTwinRecommendation(
        widget.patientId,
        recommendationId,
        action,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'ACCEPTED'
                  ? 'Recommendation accepted. Follow-up scheduled!'
                  : 'Recommendation dismissed.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      widget.onRefresh?.call();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  void _showSetGoalDialog() {
    final controller = TextEditingController(
      text: widget.twinState?.activitySummary.stepGoal?.toString() ?? '6000',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Daily Step Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target Steps',
            hintText: 'e.g. 6000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                await widget.backendService.setTwinStepGoal(widget.patientId, val);
                widget.onRefresh?.call();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeviceManagerSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DeviceManagerSheet(
        coordinator: _coordinator,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.twinState;
    final summary = state?.activitySummary;

    // Filter proposed recommendations
    final proposedRecs = state?.activeRecommendations
            .where((r) => r.status == 'PROPOSED')
            .toList() ??
        [];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.border.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.activity,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity & Behavior Twin',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.navy,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Continuous real-world behavioral telemetry',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _showDeviceManagerSheet(context, isDark),
                    icon: const Icon(LucideIcons.bluetooth, size: 18),
                    tooltip: 'Manage Devices',
                    visualDensity: VisualDensity.compact,
                    color: const Color(0xFF3B82F6),
                  ),
                  IconButton(
                    onPressed: () => SensorDiagnosticsSheet.show(context, _coordinator),
                    icon: const Icon(LucideIcons.gauge, size: 18),
                    tooltip: 'Sensor Diagnostics (Dev)',
                    visualDensity: VisualDensity.compact,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => TwinCenterScreen(
                            patientId: widget.patientId,
                            backendService: widget.backendService,
                            sensorCoordinator: _coordinator,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TWIN Center →',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
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

          const SizedBox(height: 16),

          // Hardware Connection Status Chips
          _buildHardwareStatusRow(isDark),

          const SizedBox(height: 16),

          // Activity & Heart Rate Row (Reactive from Coordinator or State)
          Row(
            children: [
              // Activity State Card
              Expanded(
                child: ValueListenableBuilder<TwinActivityType>(
                  valueListenable: _coordinator.currentActivityNotifier,
                  builder: (ctx, liveActivity, _) {
                    final activityStr = liveActivity != TwinActivityType.unknown
                        ? liveActivity.label
                        : (summary != null && summary.currentActivity.isNotEmpty
                            ? summary.currentActivity
                            : (_coordinator.diagnosticsNotifier.value.accelReceiving ? 'Stationary' : 'Unknown'));

                    final durMins = summary?.currentDurationMinutes ?? 0;
                    final hours = durMins ~/ 60;
                    final mins = durMins % 60;
                    final durString = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    summary?.isSedentary == true
                                        ? LucideIcons.armchair
                                        : LucideIcons.footprints,
                                    size: 16,
                                    color: summary?.isSedentary == true
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Activity',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'MOTION',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            activityStr,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            durMins > 0 ? durString : 'Active session',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Heart Rate & Context Card
              Expanded(
                child: ValueListenableBuilder<NormalizedHeartRate?>(
                  valueListenable: _coordinator.currentHeartRateNotifier,
                  builder: (ctx, liveHr, _) {
                    final hrSignal = state?.latestHealthSignals['heart_rate'];
                    final restingBaseline = state?.baselines.restingHeartRate;

                    final String displayBpm;
                    final String sourceTag;

                    if (liveHr != null) {
                      displayBpm = '${liveHr.bpm.toInt()} BPM';
                      final loc = liveHr.sensorLocation;
                      final locSuffix = loc != null ? ' • $loc' : '';
                      sourceTag = (liveHr.source == TwinSignalSource.ble
                          ? 'OBSERVED BLE$locSuffix'
                          : 'PLATFORM WATCH$locSuffix').toUpperCase();
                    } else if (hrSignal != null) {
                      displayBpm = '${hrSignal.value.toInt()} BPM';
                      sourceTag = 'TWIN ${hrSignal.source.toUpperCase()}';
                    } else {
                      displayBpm = 'Resting';
                      sourceTag = 'NO SENSOR';
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.heartPulse,
                                    size: 16,
                                    color: Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Heart Rate',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sourceTag,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayBpm,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            restingBaseline != null
                                ? 'Baseline ~${restingBaseline.toInt()} BPM'
                                : 'Collecting baseline',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Steps Progress Section
          ValueListenableBuilder<int>(
            valueListenable: _coordinator.currentStepsNotifier,
            builder: (ctx, liveSteps, _) {
              final steps = liveSteps > 0
                  ? liveSteps
                  : (summary?.stepsToday ?? 0);
              final goal = summary?.stepGoal ?? 6000;
              final remaining = (goal > steps) ? (goal - steps) : 0;
              final double stepProgress = (goal > 0)
                  ? (steps / goal).clamp(0.0, 1.0)
                  : 0.0;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Step Progress',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _showSetGoalDialog,
                          child: Text(
                            'Goal: $goal',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: stepProgress,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$steps / $goal steps',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.navy,
                          ),
                        ),
                        Text(
                          remaining > 0 ? '$remaining remaining' : 'Goal reached! 🎉',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // ESP32 Environmental IoT Section
          AnimatedBuilder(
            animation: Listenable.merge([
              _coordinator.currentTemperatureNotifier,
              _coordinator.currentHumidityNotifier,
              _coordinator.esp32StatusNotifier,
            ]),
            builder: (ctx, _) {
              final temp = _coordinator.currentTemperatureNotifier.value ??
                  state?.latestHealthSignals['temperature']?.value;
              final hum = _coordinator.currentHumidityNotifier.value ??
                  state?.latestHealthSignals['humidity']?.value;
              final espStatus = _coordinator.esp32StatusNotifier.value;
              final isConnected = espStatus == BleDeviceStatus.connected;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.thermometer,
                          color: Color(0xFF06B6D4),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Environment Telemetry',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.navy,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isConnected ? 'ESP32 LIVE' : 'ESP32 IOT',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0891B2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (temp != null && hum != null)
                                ? '${temp.toStringAsFixed(1)} °C  •  ${hum.toStringAsFixed(0)}% Humidity'
                                : (temp != null
                                    ? '${temp.toStringAsFixed(1)} °C'
                                    : (isConnected
                                        ? 'Reading sensor...'
                                        : 'ESP32 sensor disconnected')),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Proactive Recommendations Section (if any)
          if (proposedRecs.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...proposedRecs.map((rec) => _buildRecommendationCard(rec, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildHardwareStatusRow(bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _coordinator.diagnosticsNotifier,
        _coordinator.bleHrStatusNotifier,
        _coordinator.esp32StatusNotifier,
        _coordinator.healthStatusNotifier,
      ]),
      builder: (ctx, _) {
        final diag = _coordinator.diagnosticsNotifier.value;
        final bleStatus = _coordinator.bleHrStatusNotifier.value;
        final espStatus = _coordinator.esp32StatusNotifier.value;
        final healthStatus = _coordinator.healthStatusNotifier.value;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatusPill(
                icon: LucideIcons.compass,
                label: 'Phone IMU',
                status: diag.accelReceiving
                    ? (diag.accelEstimatedHz > 0 ? '${diag.accelEstimatedHz.toInt()} Hz' : 'Active')
                    : 'Standby',
                isActive: diag.accelReceiving,
                onTap: () => SensorDiagnosticsSheet.show(context, _coordinator),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
                icon: LucideIcons.heart,
                label: 'BLE HR',
                status: bleStatus == BleDeviceStatus.connected
                    ? 'Connected'
                    : (bleStatus == BleDeviceStatus.scanning
                        ? 'Scanning'
                        : 'Pair Monitor'),
                isActive: bleStatus == BleDeviceStatus.connected,
                onTap: () => _showDeviceManagerSheet(context, isDark),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
                icon: LucideIcons.cpu,
                label: 'ESP32',
                status: espStatus == BleDeviceStatus.connected
                    ? 'Connected'
                    : (espStatus == BleDeviceStatus.scanning
                        ? 'Scanning'
                        : 'Pair IoT'),
                isActive: espStatus == BleDeviceStatus.connected,
                onTap: () => _showDeviceManagerSheet(context, isDark),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
                icon: LucideIcons.watch,
                label: 'Health Platform',
                status: healthStatus == HealthPlatformStatus.permissionsGranted
                    ? 'Synced'
                    : (healthStatus == HealthPlatformStatus.permissionsRequired
                        ? 'Grant Access'
                        : 'Unavailable'),
                isActive: healthStatus == HealthPlatformStatus.permissionsGranted,
                onTap: () async {
                  if (healthStatus == HealthPlatformStatus.permissionsRequired) {
                    await _coordinator.requestHealthPermissions();
                  } else {
                    await _coordinator.syncHealthPlatform();
                    widget.onRefresh?.call();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required String status,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? const Color(0xFF10B981) : const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              '$label: $status',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(TwinRecommendationModel rec, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 16,
                color: Color(0xFF3B82F6),
              ),
              const SizedBox(width: 6),
              Text(
                'Proactive TWIN Suggestion',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rec.personalizedText != null
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rec.personalizedText != null ? 'AI-WORDING' : 'TWIN-RULE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: rec.personalizedText != null
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rec.priority,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rec.personalizedText ?? rec.reason,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : AppColors.navy,
              height: 1.35,
            ),
          ),
          if (rec.evidenceReferences.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: rec.evidenceReferences.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  TwinDecisionTraceSheet.show(
                    context,
                    patientId: widget.patientId,
                    recommendationId: rec.recommendationId,
                    backendService: widget.backendService,
                    recommendation: rec,
                  );
                },
                icon: const Icon(LucideIcons.gitBranch, size: 13),
                label: const Text('Trace', style: TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              TextButton(
                onPressed: _isResponding
                    ? null
                    : () => _handleRecommendationAction(rec.recommendationId, 'DISMISSED'),
                child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isResponding
                    ? null
                    : () => _handleRecommendationAction(rec.recommendationId, 'ACCEPTED'),
                icon: const Icon(LucideIcons.check, size: 14),
                label: const Text('Accept', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceManagerSheet extends StatefulWidget {
  final TwinSensorCoordinator coordinator;
  final bool isDark;

  const _DeviceManagerSheet({
    required this.coordinator,
    required this.isDark,
  });

  @override
  State<_DeviceManagerSheet> createState() => _DeviceManagerSheetState();
}

class _DeviceManagerSheetState extends State<_DeviceManagerSheet> {
  List<DiscoveredBleDevice> _hrDevices = [];
  List<DiscoveredBleDevice> _espDevices = [];
  bool _scanningHr = false;
  bool _scanningEsp = false;
  StreamSubscription<DiscoveredBleDevice>? _hrScanSub;
  StreamSubscription<DiscoveredBleDevice>? _espScanSub;

  @override
  void dispose() {
    _hrScanSub?.cancel();
    _espScanSub?.cancel();
    super.dispose();
  }

  void _startHrScan() {
    setState(() {
      _scanningHr = true;
      _hrDevices = [];
    });
    _hrScanSub?.cancel();
    _hrScanSub = widget.coordinator.scanHeartRateMonitors().listen(
      (device) {
        if (mounted) {
          setState(() {
            if (!_hrDevices.any((d) => d.id == device.id)) {
              _hrDevices.add(device);
            }
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _scanningHr = false);
      },
      onDone: () {
        if (mounted) setState(() => _scanningHr = false);
      },
    );
  }

  void _startEspScan() {
    setState(() {
      _scanningEsp = true;
      _espDevices = [];
    });
    _espScanSub?.cancel();
    _espScanSub = widget.coordinator.scanEsp32Sensors().listen(
      (device) {
        if (mounted) {
          setState(() {
            if (!_espDevices.any((d) => d.id == device.id)) {
              _espDevices.add(device);
            }
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _scanningEsp = false);
      },
      onDone: () {
        if (mounted) setState(() => _scanningEsp = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sensor & Device Hub',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                // BLE Heart Rate Section
                _buildSectionHeader('BLE Heart Rate Monitors (0x180D)', _scanningHr, _startHrScan),
                if (_hrDevices.isEmpty && !_scanningHr)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No devices found yet. Tap scan to discover nearby HR monitors.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ..._hrDevices.map(
                  (d) => ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.heart, color: Colors.red),
                    title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('ID: ${d.id} • RSSI: ${d.rssi} dBm'),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final scaffold = ScaffoldMessenger.of(context);
                        try {
                          await widget.coordinator.connectHeartRateMonitor(d.id);
                          if (mounted) nav.pop();
                        } catch (e) {
                          scaffold.showSnackBar(
                            SnackBar(
                              content: Text('Failed to connect to ${d.name}: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: const Text('Connect'),
                    ),
                  ),
                ),

                const Divider(height: 32),

                // ESP32 IoT Section
                _buildSectionHeader('ESP32 IoT Sensors (Temp & Humidity)', _scanningEsp, _startEspScan),
                if (_espDevices.isEmpty && !_scanningEsp)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No ESP32 sensors found. Tap scan to discover nearby environmental nodes.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ..._espDevices.map(
                  (d) => ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.thermometer, color: Colors.cyan),
                    title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('ID: ${d.id} • RSSI: ${d.rssi} dBm'),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final scaffold = ScaffoldMessenger.of(context);
                        try {
                          await widget.coordinator.connectEsp32(d.id);
                          if (mounted) nav.pop();
                        } catch (e) {
                          scaffold.showSnackBar(
                            SnackBar(
                              content: Text('Failed to connect to ESP32: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: const Text('Connect'),
                    ),
                  ),
                ),

                const Divider(height: 32),

                // Platform Health (HealthKit / Health Connect)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.watch, color: Colors.indigo),
                  title: const Text('Watch & Health Platform', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Apple HealthKit / Android Health Connect integration'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await widget.coordinator.requestHealthPermissions();
                      if (mounted) nav.pop();
                    },
                    child: const Text('Sync Now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isScanning, VoidCallback onScan) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton.icon(
          onPressed: isScanning ? null : onScan,
          icon: isScanning
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.refreshCw, size: 14),
          label: Text(isScanning ? 'Scanning...' : 'Scan', style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}