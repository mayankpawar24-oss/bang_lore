import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import 'app_layout_insets.dart';
import '../../data/providers/providers.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/appointment_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../features/patient/dashboard/screens/doctor_chat_screen.dart';

class NotificationSheet extends ConsumerWidget {
  const NotificationSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamNotifs = ref.watch(notificationsStreamProvider).valueOrNull;
    final List<NotificationModel> notifications = streamNotifs ?? [];
    final currentUid = ref.watch(currentUidProvider) ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    final user = ref.watch(currentUserProvider).valueOrNull ?? ref.watch(authProvider).user;
    final isDoctor = user?.role == UserRole.doctor;
    final userType = isDoctor ? UserType.doctor : UserType.patient;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
        children: [
          // Drag indicator handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (notifications.any((n) => !n.isRead))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${notifications.where((n) => !n.isRead).length} new',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    if (notifications.any((n) => !n.isRead))
                      TextButton(
                        onPressed: () {
                          if (currentUid.isNotEmpty) {
                            ref.read(notificationRepositoryProvider).markAllAsRead(currentUid, userType);
                          }
                        },
                        child: const Text('Mark all read', style: TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
                      ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: AppColors.slate),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          // Notifications List
          Expanded(
            child: notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(LucideIcons.bellOff, size: 48, color: AppColors.muted),
                        SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      AppLayoutInsets.bottomSafeInset(context) + 20,
                    ),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return _buildNotificationCard(context, ref, item, currentUid, isDoctor, userType, user?.name);
                    },
                  ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationModel item,
    String currentUid,
    bool isDoctor,
    UserType userType,
    String? currentUserName,
  ) {
    IconData icon;
    Color iconColor;

    switch (item.type) {
      case NotificationType.appointment:
        icon = LucideIcons.calendar;
        iconColor = AppColors.primaryBlue;
        break;
      case NotificationType.medication:
        icon = LucideIcons.pill;
        iconColor = AppColors.accentCyan;
        break;
      case NotificationType.sos:
        icon = LucideIcons.shieldAlert;
        iconColor = AppColors.danger;
        break;
      case NotificationType.familyMessage:
        icon = LucideIcons.messageCircle;
        iconColor = AppColors.primaryBlue;
        break;
      case NotificationType.familyReminder:
        icon = LucideIcons.bellRing;
        iconColor = const Color(0xFF8B5CF6);
        break;
      case NotificationType.permission:
        icon = LucideIcons.lock;
        iconColor = AppColors.warning;
        break;
      default:
        icon = LucideIcons.sparkles;
        iconColor = AppColors.primaryBlue;
    }

    final rawType = (item.rawType ?? item.type.name).toLowerCase();
    final isAppointmentRequest = isDoctor && (rawType.contains('appointment_request') || (item.type == NotificationType.appointment && item.isPending));
    final isProfileAccessRequest = !isDoctor && (rawType.contains('profile_access_request') || rawType.contains('access_request') || item.type == NotificationType.permission);
    final isSos = item.type == NotificationType.sos || rawType.contains('sos') || item.isCritical;
    final isFamily = item.type == NotificationType.familyMessage || item.type == NotificationType.familyReminder || rawType.contains('family');
    final isDoctorChat = rawType.contains('doctor_message') || rawType.contains('doctor_chat') || (rawType.contains('doctor') && rawType.contains('message'));
    final coords = _extractCoordinates(item);
    final hasValidMapsUrl = item.mapsUrl != null &&
        item.mapsUrl!.trim().isNotEmpty &&
        (item.mapsUrl!.startsWith('http://') || item.mapsUrl!.startsWith('https://') || item.mapsUrl!.startsWith('geo:'));
    final shouldShowMapButton = isSos && (coords != null || hasValidMapsUrl);

    return GestureDetector(
      onTap: () {
        if (currentUid.isNotEmpty) {
          ref.read(notificationRepositoryProvider).markAsRead(currentUid, userType, item.id);
        }
        if (isDoctorChat) {
          Navigator.pop(context);
          if (isDoctor) {
            final patId = item.patientId ?? item.senderUid ?? '';
            if (patId.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DoctorChatScreen(
                    doctorId: currentUid,
                    patientId: patId,
                    patientName: item.patientName ?? 'Patient',
                  ),
                ),
              );
            }
          } else {
            final docId = item.doctorId ?? item.senderUid ?? '';
            if (docId.isNotEmpty) {
              context.push('/patient/dashboard/doctor-chat/$docId', extra: {
                'doctorName': item.doctorName ?? 'Doctor',
              });
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSos
              ? AppColors.danger.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSos
                ? AppColors.danger.withValues(alpha: 0.5)
                : (item.isRead
                    ? AppColors.border.withValues(alpha: 0.5)
                    : AppColors.primaryBlue.withValues(alpha: 0.3)),
            width: isSos ? 1.5 : (item.isRead ? 1 : 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: isSos
                  ? AppColors.danger.withValues(alpha: 0.08)
                  : AppColors.navy.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                  fontSize: 15,
                                  color: isSos ? AppColors.danger : AppColors.navy,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSos) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'CRITICAL',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(item.timestamp),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(
                      color: isSos ? const Color(0xFF991B1B) : AppColors.slate,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: isSos ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),

                  // SOS Location & Map Link Button
                  if (shouldShowMapButton) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(LucideIcons.mapPin, size: 14),
                      label: const Text('View Location on Google Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _openGoogleMaps(context, item),
                    ),
                  ],

                  // Family Shortcut Button
                  if (isFamily) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/patient/family');
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(LucideIcons.users, size: 13, color: AppColors.primaryBlue),
                          SizedBox(width: 4),
                          Text('Open Family Circle', style: TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],

                  // Doctor Chat Shortcut Button
                  if (isDoctorChat) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (isDoctor) {
                          final patId = item.patientId ?? item.senderUid ?? '';
                          if (patId.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DoctorChatScreen(
                                  doctorId: currentUid,
                                  patientId: patId,
                                  patientName: item.patientName ?? 'Patient',
                                ),
                              ),
                            );
                          }
                        } else {
                          final docId = item.doctorId ?? item.senderUid ?? '';
                          if (docId.isNotEmpty) {
                            context.push('/patient/dashboard/doctor-chat/$docId', extra: {
                              'doctorName': item.doctorName ?? 'Doctor',
                            });
                          }
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(LucideIcons.messageSquare, size: 13, color: AppColors.primaryBlue),
                          SizedBox(width: 4),
                          Text('Reply in Doctor Chat', style: TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],

                  // DOCTOR ACTION: Appointment Request (Accept / Decline)
                  if (isAppointmentRequest) ...[
                    const SizedBox(height: 10),
                    if (item.isPending)
                      Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              final apptId = item.effectiveAppointmentId ?? '';
                              final patId = item.patientId ?? '';
                              if (apptId.isNotEmpty) {
                                await ref.read(appointmentRepositoryProvider).updateStatus(
                                  patId,
                                  currentUid,
                                  apptId,
                                  AppointmentStatus.approved,
                                  updatedByDoctor: true,
                                  doctorName: currentUserName,
                                );
                                await ref.read(notificationRepositoryProvider).updateNotificationStatus(
                                  currentUid,
                                  UserType.doctor,
                                  item.id,
                                  'actioned',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Appointment accepted and confirmed!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              final apptId = item.effectiveAppointmentId ?? '';
                              final patId = item.patientId ?? '';
                              if (apptId.isNotEmpty) {
                                await ref.read(appointmentRepositoryProvider).updateStatus(
                                  patId,
                                  currentUid,
                                  apptId,
                                  AppointmentStatus.rejected,
                                  updatedByDoctor: true,
                                  doctorName: currentUserName,
                                );
                                await ref.read(notificationRepositoryProvider).updateNotificationStatus(
                                  currentUid,
                                  UserType.doctor,
                                  item.id,
                                  'rejected',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Appointment request declined.'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    else if (item.isActioned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ACCEPTED', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    else if (item.isRejected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('DECLINED', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],

                  // PATIENT ACTION: Profile Access Request (Allow / Decline)
                  if (isProfileAccessRequest) ...[
                    const SizedBox(height: 10),
                    if (item.isPending && item.effectiveRequestId != null)
                      Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              final reqId = item.effectiveRequestId!;
                              await ref.read(patientRepositoryProvider).approveAccess(
                                reqId,
                                permissions: const [
                                  'profile',
                                  'vitals',
                                  'medications',
                                  'appointments',
                                  'medicalHistory',
                                  'familyHistory',
                                  'reports',
                                  'aiChat',
                                ],
                                notificationId: item.id,
                              );
                              await ref.read(notificationRepositoryProvider).updateNotificationStatus(
                                currentUid,
                                UserType.patient,
                                item.id,
                                'actioned',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Access granted to ${item.doctorName?.isNotEmpty == true ? "Dr. ${item.doctorName}" : "Doctor"}!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                            child: const Text('Allow', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              final reqId = item.effectiveRequestId!;
                              await ref.read(patientRepositoryProvider).denyAccess(
                                reqId,
                                notificationId: item.id,
                              );
                              await ref.read(notificationRepositoryProvider).updateNotificationStatus(
                                currentUid,
                                UserType.patient,
                                item.id,
                                'rejected',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Access request declined.'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            },
                            child: const Text('Decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    else if (item.isActioned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ALLOWED', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    else if (item.isRejected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('DECLINED', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }

  ({double lat, double lng})? _extractCoordinates(NotificationModel item) {
    final candidates = [
      item.mapsUrl,
      item.location,
      item.message,
    ];

    for (final candidate in candidates) {
      if (candidate == null || candidate.trim().isEmpty) continue;
      final text = candidate.trim();

      // 1. Check if text contains a URL with query parameters (e.g. ?q=lat,lng)
      try {
        final uriRegex = RegExp(r'https?://[^\s]+');
        final uriMatches = uriRegex.allMatches(text);
        for (final m in uriMatches) {
          final uriStr = m.group(0);
          if (uriStr != null) {
            final parsedUri = Uri.tryParse(uriStr);
            if (parsedUri != null) {
              final q = parsedUri.queryParameters['q'] ?? parsedUri.queryParameters['query'];
              if (q != null) {
                final parts = q.split(',');
                if (parts.length == 2) {
                  final lat = double.tryParse(parts[0].trim());
                  final lng = double.tryParse(parts[1].trim());
                  if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
                    return (lat: lat, lng: lng);
                  }
                }
              }
            }
          }
        }
      } catch (_) {}

      // 2. Direct regex match for "lat, lng" coordinates (e.g. 12.933514, 77.6924253 or 12.933514,77.6924253)
      final coordRegex = RegExp(r'([-+]?\d{1,2}\.\d+)[,\s]+([-+]?\d{1,3}\.\d+)');
      final match = coordRegex.firstMatch(text);
      if (match != null) {
        final latStr = match.group(1);
        final lngStr = match.group(2);
        if (latStr != null && lngStr != null) {
          final lat = double.tryParse(latStr);
          final lng = double.tryParse(lngStr);
          if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            return (lat: lat, lng: lng);
          }
        }
      }
    }
    return null;
  }

  Future<void> _openGoogleMaps(BuildContext context, NotificationModel item) async {
    final coords = _extractCoordinates(item);
    Uri? mapsWebUri;
    Uri? geoUri;

    if (coords != null) {
      final queryParam = '${coords.lat},${coords.lng}';
      mapsWebUri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': queryParam,
      });
      geoUri = Uri.parse('geo:${coords.lat},${coords.lng}?q=${coords.lat},${coords.lng}');
    } else if (item.mapsUrl != null && item.mapsUrl!.trim().isNotEmpty) {
      mapsWebUri = Uri.tryParse(item.mapsUrl!.trim());
    }

    if (mapsWebUri == null && geoUri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open Google Maps. Please check your internet connection.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    bool launched = false;

    // 1. Try geo: intent first (opens Google Maps natively on Android if installed)
    if (geoUri != null) {
      try {
        launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }

    // 2. Fallback to external application with canonical https Google Maps URL
    if (!launched && mapsWebUri != null) {
      try {
        launched = await launchUrl(mapsWebUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }

    // 3. Fallback to platform default launch
    if (!launched && mapsWebUri != null) {
      try {
        launched = await launchUrl(mapsWebUri, mode: LaunchMode.platformDefault);
      } catch (_) {
        launched = false;
      }
    }

    // 4. If all launch attempts failed, show error SnackBar
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Google Maps. Please check your internet connection.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

