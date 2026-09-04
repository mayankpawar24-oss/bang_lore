import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/medication_model.dart';
import '../../../../data/models/vital_model.dart';
import '../../../../data/models/report_model.dart';
import '../../../../data/services/backend_service.dart';

class HealthInsightsSummaryCard extends StatelessWidget {
  final List<VitalModel> vitals;
  final List<MedicationModel> medications;
  final List<ReportModel> reports;
  final MultiAgentInsightsResponse? insights;

  const HealthInsightsSummaryCard({
    super.key,
    required this.vitals,
    required this.medications,
    required this.reports,
    this.insights,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate dynamic adherence & stability
    final totalMeds = medications.length;
    final takenMeds = medications.where((m) => m.isTaken).length;
    final medAdherence = totalMeds > 0 ? (takenMeds / totalMeds * 100).round() : 94;

    final hasCriticalVitals = vitals.any((v) =>
        (v.heartRate != null && (v.heartRate! > 105 || v.heartRate! < 50)) ||
        (v.systolic != null && v.systolic! > 140) ||
        (v.spo2 != null && v.spo2! < 92));
    final isStable = !hasCriticalVitals;
    final trajectory = insights?.trajectoryStatus.toUpperCase();
    final statusText = trajectory ?? (isStable ? 'STABLE' : 'ATTENTION');
    final isEscalating = statusText == 'ESCALATING' || statusText == 'CRITICAL' || statusText == 'ATTENTION';
    final statusColor = isEscalating ? AppColors.warning : AppColors.success;

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
                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.activity,
                          color: AppColors.primaryBlue,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Personalized Health',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.navy,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Central Visualization & Key Metric Highlight
          Row(
            children: [
              // Custom Circular Adherence Progress Ring
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _ProgressRingPainter(
                        progress: medAdherence / 100.0,
                        trackColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.primaryBlue.withValues(alpha: 0.10),
                        progressColor: AppColors.primaryBlue,
                        strokeWidth: 7,
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$medAdherence%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                          Text(
                            'Adherence',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post-Discharge Care Plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All daily milestones and medication routines are on track. Stable clinical index.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.border.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 14),

          // 3 Metric Indicators Row
          Row(
            children: [
              _buildMetricItem(
                context,
                title: 'Protocol Day',
                value: 'Day 12 / 30',
                icon: LucideIcons.calendar,
                isDark: isDark,
              ),
              Container(
                height: 28,
                width: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.border.withValues(alpha: 0.6),
              ),
              _buildMetricItem(
                context,
                title: 'Medications',
                value: '$takenMeds/$totalMeds Done',
                icon: LucideIcons.pill,
                isDark: isDark,
              ),
              Container(
                height: 28,
                width: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.border.withValues(alpha: 0.6),
              ),
              _buildMetricItem(
                context,
                title: 'Vitals Status',
                value: isStable ? 'Nominal' : 'Review',
                icon: LucideIcons.heartPulse,
                isDark: isDark,
              ),
            ],
          ),

          if (insights != null) ...[
            const SizedBox(height: 16),
            Container(
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.cpu, size: 14, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text(
                            'Multi-Agent Clinical Intelligence',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'ORACLE • ADHERENCE • TWIN • NAVIGATOR • ESCALATE',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (insights!.oracle != null)
                    _buildAgentRow(
                      agentName: 'ORACLE',
                      summary: insights!.oracle!.summary,
                      confidence: insights!.oracle!.confidence,
                      icon: LucideIcons.trendingUp,
                      isDark: isDark,
                    ),
                  if (insights!.adherence != null)
                    _buildAgentRow(
                      agentName: 'ADHERENCE',
                      summary: insights!.adherence!.summary,
                      confidence: insights!.adherence!.confidence,
                      icon: LucideIcons.checkCircle2,
                      isDark: isDark,
                    ),
                  if (insights!.twin != null)
                    _buildAgentRow(
                      agentName: 'TWIN',
                      summary: insights!.twin!.summary,
                      confidence: insights!.twin!.confidence,
                      icon: LucideIcons.copy,
                      isDark: isDark,
                    ),
                  if (insights!.navigator != null)
                    _buildAgentRow(
                      agentName: 'NAVIGATOR',
                      summary: insights!.navigator!.summary,
                      confidence: insights!.navigator!.confidence,
                      icon: LucideIcons.compass,
                      isDark: isDark,
                    ),
                  if (insights!.escalate != null)
                    _buildAgentRow(
                      agentName: 'ESCALATE',
                      summary: insights!.escalate!.summary,
                      confidence: insights!.escalate!.confidence,
                      icon: LucideIcons.alertTriangle,
                      isDark: isDark,
                    ),
                  if (insights!.synthesizedActions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Synthesized Actions: ${insights!.synthesizedActions.join("; ")}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // View Details Action
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/patient/timeline'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'View Care Protocol Details',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    color: AppColors.primaryBlue,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentRow({
    required String agentName,
    required String summary,
    required double confidence,
    required IconData icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : AppColors.navy,
                ),
                children: [
                  TextSpan(
                    text: '[$agentName ${(confidence * 100).toInt()}%]: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                  TextSpan(text: summary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
