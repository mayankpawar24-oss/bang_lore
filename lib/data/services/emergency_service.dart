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

    // 3b. Resolve all connected Family Members for the patient
    final familyUids = <String>{};
    try {
      final rels1 = await _db!.collection('familyRelationships').where('ownerUid', isEqualTo: patientUid).get();
      for (final d in rels1.docs) {
        final mId = d.data()['memberUid'] as String?;
        if (mId != null && mId.isNotEmpty && mId != patientUid) familyUids.add(mId);
      }
      final rels2 = await _db!.collection('familyRelationships').where('memberUid', isEqualTo: patientUid).get();
      for (final d in rels2.docs) {
        final oId = d.data()['ownerUid'] as String?;
        if (oId != null && oId.isNotEmpty && oId != patientUid) familyUids.add(oId);
      }
      final subMembers = await _db!.collection('patients').doc(patientUid).collection('familyMembers').get();
      for (final d in subMembers.docs) {
        final mId = d.data()['memberUid'] as String?;
        if (mId != null && mId.isNotEmpty && mId != patientUid) familyUids.add(mId);
      }
    } catch (e) {
      dev.log('[EMERGENCY] Family lookup error: $e', name: 'EmergencyService');
    }

    // 4. Save Notifications to Firestore for Family Members & Sender
    final alertId = 'alert_sos_${patientUid}_${now.millisecondsSinceEpoch}';
    final batch = _db!.batch();

    // Target recipients: all connected family members (if none found, fallback to self)
    final recipientUids = familyUids.isNotEmpty ? familyUids.toList() : [patientUid];

    for (final recipientUid in recipientUids) {
      final notifPayload = {
        'id': alertId,
        'notificationId': alertId,
        'recipientUid': recipientUid,
        'recipientUserId': recipientUid,
        'senderUid': patientUid,
        'senderUserId': patientUid,
        'senderName': patientName,
        'title': '🚨 EMERGENCY SOS ALERT',
        'message': alertMessage,
        'body': alertMessage,
        'type': 'emergency_sos',
        'priority': 'critical',
        'status': 'active',
        'isEmergency': true,
        'isRead': false,
        'location': locationText,
        'mapsUrl': mapsUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Patient-specific notifications subcollection (listened by NotificationSheet)
      final pNotifRef = _db!.collection('patients').doc(recipientUid).collection('notifications').doc(alertId);
      batch.set(pNotifRef, notifPayload, SetOptions(merge: true));

      // Root collections
      batch.set(_db!.collection('patientNotifications').doc('${alertId}_$recipientUid'), notifPayload, SetOptions(merge: true));
      batch.set(_db!.collection('notifications').doc('${alertId}_$recipientUid'), notifPayload, SetOptions(merge: true));
    }

    await batch.commit();

    // 5. Send Telegram Alert to Family Members & Sender if linked
    bool telegramSent = false;
    if (_telegramRepository != null) {
      // 5a. Send to family members' Telegram if linked
      for (final memberUid in familyUids) {
        try {
          final mDoc = await _db!.collection('users').doc(memberUid).get();
          final mData = mDoc.data();
          final mChatId = mData?['telegramChatId'] as String?;
          final mConnected = mData?['telegramConnected'] == true;
          if (mConnected && mChatId != null && mChatId.isNotEmpty) {
            final sent = await _telegramRepository!.sendTelegramMessage(
              chatId: mChatId,
              text: alertMessage,
              recipientUid: memberUid,
              recipientRole: 'patient',
            );
            if (sent) telegramSent = true;
          }
        } catch (e) {
          dev.log('[EMERGENCY] Family Telegram dispatch error for $memberUid: $e', name: 'EmergencyService');
        }
      }

      // 5b. Also send to sender's own Telegram if linked
      if (telegramConnected && telegramChatId != null && telegramChatId.isNotEmpty) {
        try {
          final sent = await _telegramRepository!.sendTelegramMessage(
            chatId: telegramChatId,
            text: alertMessage,
            recipientUid: patientUid,
            recipientRole: 'patient',
          );
          if (sent) telegramSent = true;
        } catch (e) {
          dev.log('[EMERGENCY] Sender Telegram dispatch failed: $e', name: 'EmergencyService');
        }
      }
    }

    // 6. Log to Activity Logs for Sender and all Family Members
    try {
      await _activityLogService?.logEvent(
        patientId: patientUid,
        eventType: ActivityEventType.general,
        title: '🚨 EMERGENCY SOS ALERT',
        description: '$patientName activated Emergency SOS. Dispatched to ${familyUids.length} family member(s). $locationText',
        actorUid: patientUid,
        actorRole: 'patient',
        actorName: patientName,
        metadata: {
          'location': locationText,
          'emergencyContact': emergencyContact,
          'mapsUrl': mapsUrl,
          'telegramSent': telegramSent,
          'dispatchedTo': familyUids.toList(),
        },
      );

      for (final memberUid in familyUids) {
        await _activityLogService?.logEvent(
          patientId: memberUid,
          eventType: ActivityEventType.general,
          title: '🚨 EMERGENCY SOS RECEIVED',
          description: '$patientName activated Emergency SOS! $locationText',
          actorUid: patientUid,
          actorRole: 'patient',
          actorName: patientName,
          metadata: {
            'location': locationText,
            'mapsUrl': mapsUrl,
            'senderUid': patientUid,
            'senderName': patientName,
          },
        );
      }
    } catch (_) {}

    return EmergencyAlertResult(
      success: true,
      locationText: locationText,
      mapsUrl: mapsUrl,
      telegramSent: telegramSent,
    );
  }
}
