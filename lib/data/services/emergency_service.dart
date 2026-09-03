import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/activity_log_model.dart';
import '../repositories/telegram_repository.dart';
import 'activity_log_service.dart';

class EmergencyAlertResult {
  final bool success;
  final String locationText;
  final String? mapsUrl;
  final String? errorMessage;
  final bool telegramSent;

  const EmergencyAlertResult({
    required this.success,
    required this.locationText,
    this.mapsUrl,
    this.errorMessage,
    this.telegramSent = false,
  });
}

class EmergencyService {
  final FirebaseFirestore? _db;
  final TelegramRepository? _telegramRepository;
  final ActivityLogService? _activityLogService;

  static DateTime? _lastTriggerTime;

  EmergencyService({
    FirebaseFirestore? db,
    TelegramRepository? telegramRepository,
    ActivityLogService? activityLogService,
  })  : _db = db,
        _telegramRepository = telegramRepository,
        _activityLogService = activityLogService;

  Future<EmergencyAlertResult> triggerEmergencyAlert({
    required String patientUid,
    bool bypassCooldown = false,
  }) async {
    if (patientUid.isEmpty || _db == null) {
      return const EmergencyAlertResult(
        success: false,
        locationText: 'Unavailable',
        errorMessage: 'Invalid patient UID or database uninitialized.',
      );
    }

    // Debounce / rate limit check (30 seconds)
    final now = DateTime.now();
    if (!bypassCooldown && _lastTriggerTime != null) {
      final diff = now.difference(_lastTriggerTime!).inSeconds;
      if (diff < 30) {
        return EmergencyAlertResult(
          success: false,
          locationText: 'Unavailable',
          errorMessage: 'Emergency alert was sent recently. Please wait ${30 - diff}s before retrying.',
        );
      }
    }
    _lastTriggerTime = now;

    // 1. Retrieve Real GPS Location with graceful fallback (never fabricate coordinates)
    String locationText = 'Location: Unavailable (Permission denied or GPS disabled)';
    String? mapsUrl;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
          mapsUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
          locationText = mapsUrl;
        }
      }
    } catch (e) {
      dev.log('[EMERGENCY] GPS lookup failed: $e', name: 'EmergencyService');
      locationText = 'Location: Unavailable (GPS signal lost or timed out)';
    }

    // 2. Retrieve Patient Data
    String patientName = 'Continuum Patient';
    String? emergencyContact;
    String? telegramChatId;
    bool telegramConnected = false;

    try {
      final pDoc = await _db!.collection('patients').doc(patientUid).get();
      if (pDoc.exists) {
        final pData = pDoc.data()!;
        patientName = pData['name'] as String? ?? patientName;
        emergencyContact = pData['emergencyContact'] as String?;
        telegramChatId = pData['telegramChatId'] as String?;
        telegramConnected = pData['telegramConnected'] == true;
      } else {
        final uDoc = await _db!.collection('users').doc(patientUid).get();
        if (uDoc.exists) {
          final uData = uDoc.data()!;
          patientName = uData['name'] as String? ?? patientName;
          telegramChatId = uData['telegramChatId'] as String?;
          telegramConnected = uData['telegramConnected'] == true;
        }
      }
    } catch (e) {
      dev.log('[EMERGENCY] Error fetching profile: $e', name: 'EmergencyService');
    }

    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    // 3. Format Exact Alert Message
    final alertMessage = '''
🚨 EMERGENCY ALERT

$patientName may require immediate assistance.

Location:
$locationText

Time:
$timeStr

Please contact the patient/emergency services immediately.
'''.trim();

    // 4. Save Notifications to Firestore
    final alertId = 'alert_sos_${patientUid}_${now.millisecondsSinceEpoch}';
    final batch = _db!.batch();

    // Patient notification
    batch.set(_db!.collection('patientNotifications').doc(alertId), {
      'notificationId': alertId,
      'recipientUid': patientUid,
      'recipientRole': 'patient',
      'title': '🚨 EMERGENCY SOS ACTIVATED',
      'message': alertMessage,
      'status': 'active',
      'isEmergency': true,
      'location': locationText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Root notifications
    batch.set(_db!.collection('notifications').doc(alertId), {
      'notificationId': alertId,
      'recipientUid': patientUid,
      'recipientRole': 'patient',
      'title': '🚨 EMERGENCY SOS ACTIVATED',
      'message': alertMessage,
      'status': 'active',
      'isEmergency': true,
      'location': locationText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 5. Send Telegram Alert if linked
    bool telegramSent = false;
    if (telegramConnected && telegramChatId != null && telegramChatId.isNotEmpty && _telegramRepository != null) {
      try {
        telegramSent = await _telegramRepository!.sendTelegramMessage(
          chatId: telegramChatId,
          text: alertMessage,
          recipientUid: patientUid,
          recipientRole: 'patient',
        );
      } catch (e) {
        dev.log('[EMERGENCY] Telegram dispatch failed: $e', name: 'EmergencyService');
      }
    }

    // 6. Log to Activity Logs
    try {
      await _activityLogService?.logEvent(
        patientId: patientUid,
        eventType: ActivityEventType.general,
        title: '🚨 EMERGENCY SOS ALERT',
        description: '$patientName activated Emergency SOS. $locationText',
        actorUid: patientUid,
        actorRole: 'patient',
        actorName: patientName,
        metadata: {
          'location': locationText,
          'emergencyContact': emergencyContact,
          'mapsUrl': mapsUrl,
          'telegramSent': telegramSent,
        },
      );
    } catch (_) {}

    return EmergencyAlertResult(
      success: true,
      locationText: locationText,
      mapsUrl: mapsUrl,
      telegramSent: telegramSent,
    );
  }
}
