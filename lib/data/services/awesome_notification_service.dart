import 'dart:developer' as dev;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AwesomeNotificationService {
  static const String channelAppointments = 'continuum_appointments';
  static const String channelAccess = 'continuum_access';
  static const String channelReminders = 'continuum_reminders';
  static const String channelAI = 'continuum_ai';

  static final AwesomeNotifications _notifications = AwesomeNotifications();

  /// Initialize notification channels and listener
  static Future<void> initialize() async {
    try {
      dev.log('[NOTIFICATION] Initializing AwesomeNotifications channels', name: 'AwesomeNotificationService');
      await _notifications.initialize(
        null, // default app icon
        [
          NotificationChannel(
            channelKey: channelAppointments,
            channelName: 'Appointments',
            channelDescription: 'Notifications for appointment requests and updates',
            defaultColor: const Color(0xFF2563EB),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
          ),
          NotificationChannel(
            channelKey: channelAccess,
            channelName: 'Access Permissions',
            channelDescription: 'Doctor and Patient access consent notifications',
            defaultColor: const Color(0xFF0EA5E9),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
          ),
          NotificationChannel(
            channelKey: channelReminders,
            channelName: 'Care Reminders',
            channelDescription: 'Medication and care tasks notifications',
            defaultColor: const Color(0xFF10B981),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
          ),
          NotificationChannel(
            channelKey: channelAI,
            channelName: 'AI Care Insights',
            channelDescription: 'AI health follow-ups and telemetry monitoring alerts',
            defaultColor: const Color(0xFF8B5CF6),
            importance: NotificationImportance.Default,
            channelShowBadge: true,
            playSound: true,
          ),
        ],
        channelGroups: [
          NotificationChannelGroup(
            channelGroupKey: 'continuum_group',
            channelGroupName: 'Continuum Health Notifications',
          ),
        ],
        debug: false,
      );

      // Request user permission if not already granted
      await requestPermission();

      // Register action listener
      await _notifications.setListeners(
        onActionReceivedMethod: onActionReceivedMethod,
        onNotificationCreatedMethod: onNotificationCreatedMethod,
        onNotificationDisplayedMethod: onNotificationDisplayedMethod,
        onDismissActionReceivedMethod: onDismissActionReceivedMethod,
      );
      dev.log('[NOTIFICATION] AwesomeNotifications initialized successfully', name: 'AwesomeNotificationService');
    } catch (e) {
      dev.log('[NOTIFICATION] Exception initializing AwesomeNotifications: $e', error: e, name: 'AwesomeNotificationService');
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final isAllowed = await _notifications.isNotificationAllowed();
      if (!isAllowed) {
        return await _notifications.requestPermissionToSendNotifications();
      }
      return true;
    } catch (e) {
      dev.log('[NOTIFICATION] Error requesting notification permission: $e', error: e, name: 'AwesomeNotificationService');
      return false;
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    dev.log('[NOTIFICATION] Action received: ${receivedAction.buttonKeyPressed} on payload ${receivedAction.payload}', name: 'AwesomeNotificationService');

    final payload = receivedAction.payload ?? {};
    final action = receivedAction.buttonKeyPressed;
    final requestId = payload['requestId'] ?? payload['permissionId'] ?? '';
    final appointmentId = payload['appointmentId'] ?? '';
    final patientId = payload['patientId'] ?? '';
    final doctorId = payload['doctorId'] ?? '';

    final db = FirebaseFirestore.instance;

    // Real Firestore action handling directly from notification buttons
    if (action == 'ALLOW_ACCESS' && requestId.isNotEmpty) {
      dev.log('[ACCESS] [FIRESTORE] Allowing access directly from notification: $requestId (Doctor: $doctorId)', name: 'AwesomeNotificationService');
      await db.collection('accessPermissions').doc(requestId).set({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else if (action == 'DECLINE_ACCESS' && requestId.isNotEmpty) {
      dev.log('[ACCESS] [FIRESTORE] Declining access directly from notification: $requestId', name: 'AwesomeNotificationService');
      await db.collection('accessPermissions').doc(requestId).set({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else if (action == 'ACCEPT_APPT' && appointmentId.isNotEmpty) {
      dev.log('[APPOINTMENT] [FIRESTORE] Approving appointment from notification: $appointmentId', name: 'AwesomeNotificationService');
      await db.collection('appointments').doc(appointmentId).set({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (patientId.isNotEmpty) {
        await db.collection('patients').doc(patientId).collection('appointments').doc(appointmentId).set({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } else if (action == 'DECLINE_APPT' && appointmentId.isNotEmpty) {
      dev.log('[APPOINTMENT] [FIRESTORE] Rejecting appointment from notification: $appointmentId', name: 'AwesomeNotificationService');
      await db.collection('appointments').doc(appointmentId).set({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (patientId.isNotEmpty) {
        await db.collection('patients').doc(patientId).collection('appointments').doc(appointmentId).set({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification notification) async {}

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification notification) async {}

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction action) async {}

  /// Dispatch device notification for New Appointment Request (Doctor device)
  static Future<void> showAppointmentRequestNotification({
    required String appointmentId,
    required String patientName,
    required String dateTimeStr,
    required String doctorId,
    required String patientId,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notifications.createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelAppointments,
        title: 'New Appointment Request',
        body: '$patientName requested a consultation for $dateTimeStr',
        notificationLayout: NotificationLayout.Default,
        payload: {
          'appointmentId': appointmentId,
          'patientId': patientId,
          'doctorId': doctorId,
          'type': 'appointment_request',
        },
      ),
      actionButtons: [
        NotificationActionButton(key: 'ACCEPT_APPT', label: 'Accept', color: const Color(0xFF2563EB)),
        NotificationActionButton(key: 'DECLINE_APPT', label: 'Decline', isDangerousOption: true),
      ],
    );
  }

  /// Dispatch device notification for Appointment Status Update (Patient device)
  static Future<void> showAppointmentStatusNotification({
    required String appointmentId,
    required String doctorName,
    required bool isApproved,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notifications.createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelAppointments,
        title: isApproved ? 'Appointment Approved' : 'Appointment Rejected',
        body: isApproved
            ? 'Dr. $doctorName has confirmed your scheduled consultation slot.'
            : 'Dr. $doctorName was unable to accept this consultation request.',
        notificationLayout: NotificationLayout.Default,
        payload: {'appointmentId': appointmentId, 'status': isApproved ? 'approved' : 'rejected'},
      ),
    );
  }

  /// Dispatch device notification for Profile Access Request (Patient device)
  static Future<void> showProfileAccessRequestNotification({
    required String requestId,
    required String doctorName,
    required String doctorId,
    required String patientId,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notifications.createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelAccess,
        title: 'Doctor Profile Access Request',
        body: 'Dr. $doctorName has requested access to view your continuous health records.',
        notificationLayout: NotificationLayout.Default,
        payload: {
          'requestId': requestId,
          'doctorId': doctorId,
          'patientId': patientId,
          'type': 'profile_access_request',
        },
      ),
      actionButtons: [
        NotificationActionButton(key: 'ALLOW_ACCESS', label: 'Allow', color: const Color(0xFF2563EB)),
        NotificationActionButton(key: 'DECLINE_ACCESS', label: 'Decline', isDangerousOption: true),
      ],
    );
  }

  /// Dispatch device notification for Profile Access Status (Doctor device)
  static Future<void> showAccessStatusNotification({
    required String patientName,
    required bool isApproved,
    required String patientId,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notifications.createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelAccess,
        title: isApproved ? 'Access Granted' : 'Access Declined',
        body: isApproved
            ? '$patientName granted access to their medical records.'
            : '$patientName declined your access request.',
        notificationLayout: NotificationLayout.Default,
        payload: {'patientId': patientId, 'status': isApproved ? 'approved' : 'rejected'},
      ),
    );
  }

  /// Dispatch device notification for Care Reminders
  static Future<void> showReminderNotification({
    required String title,
    required String body,
    required String reminderId,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notifications.createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelReminders,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        payload: {'reminderId': reminderId},
      ),
    );
  }

  /// Schedule / Trigger local device notification for Medication Reminders
  static Future<void> scheduleMedicationReminder({
    required int id,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
    required String medicationId,
  }) async {
    try {
      await requestPermission();
      final notifId = id.abs().remainder(100000);
      final isFuture = scheduledTime.isAfter(DateTime.now());
      if (isFuture) {
        await _notifications.createNotification(
          content: NotificationContent(
            id: notifId,
            channelKey: channelReminders,
            title: 'Medication Reminder: $medicineName',
            body: 'Scheduled dose: $dosage at ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}',
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Reminder,
            payload: {'medicationId': medicationId, 'type': 'medication_reminder'},
          ),
          schedule: NotificationCalendar(
            hour: scheduledTime.hour,
            minute: scheduledTime.minute,
            second: 0,
            millisecond: 0,
            allowWhileIdle: true,
            preciseAlarm: true,
            repeats: true,
          ),
        );
      } else {
        await _notifications.createNotification(
          content: NotificationContent(
            id: notifId,
            channelKey: channelReminders,
            title: 'Medication Reminder: $medicineName',
            body: 'Scheduled dose: $dosage (Active reminder)',
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Reminder,
            payload: {'medicationId': medicationId, 'type': 'medication_reminder'},
          ),
        );
      }
      dev.log('[NOTIFICATION] Scheduled medication reminder $notifId for $medicineName ($dosage)', name: 'AwesomeNotificationService');
    } catch (e) {
      dev.log('[NOTIFICATION] Error creating medication reminder: $e', error: e, name: 'AwesomeNotificationService');
      rethrow;
    }
  }

  /// Cancel a scheduled medication notification
  static Future<void> cancelMedicationReminder(int id) async {
    try {
      final notifId = id.abs().remainder(100000);
      await _notifications.cancel(notifId);
      dev.log('[NOTIFICATION] Cancelled medication notification $notifId', name: 'AwesomeNotificationService');
    } catch (e) {
      dev.log('[NOTIFICATION] Error cancelling medication reminder: $e', error: e, name: 'AwesomeNotificationService');
    }
  }

  /// Dispatch device notification for AI Follow-Up
  static Future<void> showAIFollowUpNotification({
    required String title,
    required String body,
    String? sourceDocument,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notifications.createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelAI,
        title: title,
        body: sourceDocument != null ? '$body (Source: $sourceDocument)' : body,
        notificationLayout: NotificationLayout.BigText,
      ),
    );
  }

  /// Generic device notification
  static Future<void> showLocalNotification({
    int? id,
    required String title,
    required String body,
    String channelKey = channelAppointments,
  }) async {
    final notifId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notifications.createNotification(
      content: NotificationContent(
        id: notifId,
        channelKey: channelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  /// Helper for Doctor Profile Access Request with Action Buttons
  static Future<void> showAccessRequestNotification({
    int? id,
    required String doctorName,
    required String requestId,
    String doctorId = '',
    String patientId = '',
  }) async {
    await showProfileAccessRequestNotification(
      requestId: requestId,
      doctorName: doctorName,
      doctorId: doctorId,
      patientId: patientId,
    );
  }
}
