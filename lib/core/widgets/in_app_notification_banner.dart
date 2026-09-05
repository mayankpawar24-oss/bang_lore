import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../../data/models/twin_state_model.dart';
import '../../data/services/backend_service.dart';

/// In-App Notification Banner component that surfaces live notifications
/// dispatched by the NotificationEngine across real backend domain events.
class InAppNotificationBanner extends StatefulWidget {
  final String patientId;
  final BackendService backendService;
  final VoidCallback? onViewInTwin;
  final VoidCallback? onNotificationHandled;

  const InAppNotificationBanner({
    super.key,
    required this.patientId,
    required this.backendService,
    this.onViewInTwin,
    this.onNotificationHandled,
  });

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner> {
  List<TwinInAppNotification> _notifications = [];
  Timer? _pollingTimer;
  bool _isAcknowledging = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _fetchNotifications();
    });
  }

  @override
  void didUpdateWidget(covariant InAppNotificationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.patientId != oldWidget.patientId) {
      _fetchNotifications();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final notifs = await widget.backendService.getActiveNotifications(widget.patientId);
      if (mounted) {
        setState(() {
          _notifications = notifs;
        });
      }
    } catch (_) {}
  }

  Future<void> _acknowledge(String notifId) async {
    if (_isAcknowledging) return;
    setState(() => _isAcknowledging = true);

    try {
      final ok = await widget.backendService.acknowledgeNotification(
        patientId: widget.patientId,
        notificationId: notifId,
      );
      if (ok && mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.notificationId == notifId);
          _isAcknowledging = false;
        });
        widget.onNotificationHandled?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAcknowledging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notifications.isEmpty) return const SizedBox.shrink();

    final notif = _notifications.first;

    Color bannerColor = AppColors.primary;
    IconData icon = LucideIcons.bellRing;
    if (notif.type.contains('CARE_GAP') || notif.type.contains('ALERT')) {
      bannerColor = AppColors.danger;
      icon = LucideIcons.alertTriangle;
    } else if (notif.type.contains('APPOINTMENT')) {
      bannerColor = AppColors.info;
      icon = LucideIcons.calendarClock;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bannerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: bannerColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bannerColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notif.type,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: bannerColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onViewInTwin != null) ...[
                OutlinedButton.icon(
                  onPressed: widget.onViewInTwin,
                  icon: const Icon(LucideIcons.sparkles, size: 14),
                  label: const Text('View in TWIN'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: _isAcknowledging ? null : () => _acknowledge(notif.notificationId),
                icon: _isAcknowledging
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(LucideIcons.check, size: 14),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
