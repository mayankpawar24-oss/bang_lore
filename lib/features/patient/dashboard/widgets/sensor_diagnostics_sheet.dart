import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/sensors/models/sensor_diagnostics_model.dart';
import '../../../../data/sensors/twin_sensor_coordinator.dart';

/// Development diagnostics bottom sheet displaying real-time accelerometer,
/// gyroscope, processing layer, and TWIN output telemetry.
class SensorDiagnosticsSheet extends StatelessWidget {
  final TwinSensorCoordinator coordinator;
  final bool isDark;

  const SensorDiagnosticsSheet({
    super.key,
    required this.coordinator,
    required this.isDark,
  });

  static void show(BuildContext context, TwinSensorCoordinator coordinator) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF10172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SensorDiagnosticsSheet(
        coordinator: coordinator,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.navy;
    final subColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.gauge,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sensor Diagnostics Mode',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Live hardware telemetry & fusion state (Dev Only)',
                          style: TextStyle(
                            fontSize: 11,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                  color: subColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Diagnostics Content
            Expanded(
              child: ValueListenableBuilder<SensorDiagnosticsData>(
                valueListenable: coordinator.diagnosticsNotifier,
                builder: (ctx, diag, _) {
                  return ListView(
                    controller: scrollController,
                    children: [
                      // 1. Output Summary Card
                      _buildSectionHeader('PIPELINE OUTPUT & RECOGNITION', LucideIcons.activity),
                      _buildCard(
                        cardBg,
                        borderColor,
                        [
                          _buildMetricRow('Detected Steps', '${diag.detectedSteps}', isHighlight: true),
                          _buildMetricRow('Active Step Source', diag.activeStepSource),
                          _buildMetricRow(
                            'Current Activity',
                            diag.currentActivity.label.toUpperCase(),
                            valueColor: const Color(0xFF10B981),
                            isBold: true,
                          ),
                          _buildMetricRow(
                            'Confidence',
                            diag.confidence > 0 ? '${(diag.confidence * 100).toInt()}%' : 'N/A',
                          ),
                          _buildMetricRow(
                            'Last Activity Transition',
                            diag.lastTransitionTime != null
                                ? _formatTime(diag.lastTransitionTime!)
                                : 'None',
                          ),
                          _buildMetricRow(
                            'Last TWIN Ingestion Signal',
                            diag.lastTwinSignalEmittedAt != null
                                ? _formatTime(diag.lastTwinSignalEmittedAt!)
                                : 'Pending',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. Accelerometer Section
                      _buildSectionHeader('INTERNAL HARDWARE ACCELEROMETER', LucideIcons.move),
                      _buildCard(
                        cardBg,
                        borderColor,
                        [
                          _buildStatusRow(
                            'Receiving Data',
                            diag.accelReceiving,
                            activeText: 'ACTIVE (Hardware Attached)',
                            inactiveText: 'STOPPED / UNAVAILABLE',
                          ),
                          _buildMetricRow('Sample Count', '${diag.accelSampleCount}'),
                          _buildMetricRow(
                            'Estimated Sampling Rate',
                            diag.accelEstimatedHz > 0 ? '~${diag.accelEstimatedHz} Hz' : 'Measuring...',
                            isHighlight: true,
                          ),
                          _buildMetricRow(
                            'Last Timestamp',
                            diag.accelLastTimestamp != null
                                ? _formatTime(diag.accelLastTimestamp!)
                                : 'Never',
                          ),
                          _buildVectorRow('Raw Vector (ax, ay, az)', diag.accelX, diag.accelY, diag.accelZ, 'm/s²'),
                          _buildMetricRow('Total Magnitude', '${diag.accelMagnitude} m/s²'),
                          _buildMetricRow('Linear User Accel', '${diag.userAccelMagnitude} m/s² (gravity removed)'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Gyroscope Section
                      _buildSectionHeader('INTERNAL HARDWARE GYROSCOPE', LucideIcons.compass),
                      _buildCard(
                        cardBg,
                        borderColor,
                        [
                          _buildStatusRow(
                            'Receiving Data',
                            diag.gyroReceiving,
                            activeText: 'ACTIVE (Hardware Attached)',
                            inactiveText: 'STOPPED / UNAVAILABLE',
                          ),
                          _buildMetricRow('Sample Count', '${diag.gyroSampleCount}'),
                          _buildMetricRow(
                            'Estimated Sampling Rate',
                            diag.gyroEstimatedHz > 0 ? '~${diag.gyroEstimatedHz} Hz' : 'Measuring...',
                            isHighlight: true,
                          ),
                          _buildMetricRow(
                            'Last Timestamp',
                            diag.gyroLastTimestamp != null
                                ? _formatTime(diag.gyroLastTimestamp!)
                                : 'Never',
                          ),
                          _buildVectorRow('Angular Rate (gx, gy, gz)', diag.gyroX, diag.gyroY, diag.gyroZ, 'rad/s'),
                          _buildMetricRow('Rotation Magnitude', '${diag.gyroMagnitude} rad/s'),
                          _buildMetricRow(
                            'False Positive Suppression',
                            diag.gyroMagnitude > 2.5
                                ? 'TRIGGERED (High Rotation Detected)'
                                : 'NORMAL (Translational Motion)',
                            valueColor: diag.gyroMagnitude > 2.5 ? const Color(0xFFF59E0B) : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. Processing & Filter Status
                      _buildSectionHeader('INTERNAL PROCESSING MODULES', LucideIcons.cpu),
                      _buildCard(
                        cardBg,
                        borderColor,
                        [
                          _buildStatusRow('Sensor Ingestion Stream', diag.sensorStreamActive),
                          _buildStatusRow('Low-Pass Gravity Separation Filter', diag.filteringActive),
                          _buildStatusRow('Adaptive Peak/Valley Step Detector', diag.stepDetectorActive),
                          _buildStatusRow('Windowed Activity Classifier', diag.activityClassifierActive),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Color bg, Color border, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value, {
    Color? valueColor,
    bool isHighlight = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: isHighlight || isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? (isDark ? Colors.white : AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    bool isActive, {
    String activeText = 'ACTIVE',
    String inactiveText = 'INACTIVE',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isActive ? activeText : inactiveText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVectorRow(String label, double x, double y, double z, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAxisChip('X', x, unit, Colors.red),
              _buildAxisChip('Y', y, unit, Colors.green),
              _buildAxisChip('Z', z, unit, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAxisChip(String axis, double val, String unit, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$axis: $val $unit',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade600,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
