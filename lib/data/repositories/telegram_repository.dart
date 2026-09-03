import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';

abstract class TelegramRepository {
  Future<String> generateLinkingCode(String uid, {String? role});
  Future<bool> verifyLinkingCode(String code, String chatId, {String? username});
  Future<void> linkTelegram(String uid, String chatId, {String? role, String? username});
  Future<void> connectTelegram(String uid, String chatId, {String? role, String? username});
  Future<void> disconnectTelegram(String uid, {String? role});
  Future<bool> openTelegramBot(String uid, {String? linkingCode});
  Stream<Map<String, dynamic>> telegramStatusStream(String uid);
  Future<bool> sendTelegramMessage({
    required String chatId,
    required String text,
    String? recipientUid,
    String? recipientRole,
    String? botToken,
  });
  Future<bool> sendTargetedTelegramNotification({
    required String targetPatientId,
    required String text,
    required String notificationType,
    String? eventId,
    String? botToken,
  });
}

class FirebaseTelegramRepository implements TelegramRepository {
  final FirebaseFirestore _db;
  final ActivityLogService _activityLogService;

  FirebaseTelegramRepository({
    FirebaseFirestore? db,
    ActivityLogService? activityLogService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _activityLogService = activityLogService ?? ActivityLogService(db: db);

  @override
  Future<String> generateLinkingCode(String uid, {String? role}) async {
    if (uid.isEmpty) throw ArgumentError('UID cannot be empty');
    final code = 'CH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    try {
      await _db.collection('telegramLinks').doc(code).set({
        'code': code,
        'uid': uid,
        'role': role ?? 'patient',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30))),
        'used': false,
      });
      return code;
    } catch (e, st) {
      dev.log('[TELEGRAM] Error generating code: $e', name: 'TelegramRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<bool> verifyLinkingCode(String code, String chatId, {String? username}) async {
    if (code.isEmpty || chatId.isEmpty) return false;
    try {
      final doc = await _db.collection('telegramLinks').doc(code).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      if (data['used'] == true) return false;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) return false;

      final uid = data['uid'] as String;
      final role = data['role'] as String?;
      await linkTelegram(uid, chatId, role: role, username: username);
      await doc.reference.update({'used': true, 'linkedAt': FieldValue.serverTimestamp()});
      return true;
    } catch (e, st) {
      dev.log('[TELEGRAM] Error verifying code: $e', name: 'TelegramRepository', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<void> linkTelegram(String uid, String chatId, {String? role, String? username}) async {
    if (uid.isEmpty || chatId.isEmpty) return;
    try {
      dev.log('[TELEGRAM] Connecting Telegram chat $chatId for $role $uid', name: 'TelegramRepository');
      final cleanChatId = chatId.trim();
      final batch = _db.batch();

      final updateData = {
        'telegramChatId': cleanChatId,
        'telegramLinked': true,
        'telegramConnected': true,
        'telegramUsername': username,
        'telegramLinkedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(_db.collection('users').doc(uid), updateData, SetOptions(merge: true));

      if (role == 'patient' || role == null) {
        batch.set(_db.collection('patients').doc(uid), updateData, SetOptions(merge: true));
      }
      if (role == 'doctor' || role == null) {
        batch.set(_db.collection('doctors').doc(uid), updateData, SetOptions(merge: true));
      }

      await batch.commit();

      try {
        await _activityLogService.logEvent(
          patientId: role == 'patient' ? uid : null,
          doctorId: role == 'doctor' ? uid : null,
          eventType: ActivityEventType.telegramLinked,
          title: 'Telegram Connected',
          description: 'Telegram alerts linked permanently to Chat ID $cleanChatId.',
          actorUid: uid,
          actorRole: role ?? 'patient',
          metadata: {'chatId': cleanChatId, 'username': username},
        );
      } catch (_) {}

      dev.log('[TELEGRAM] Successfully connected Telegram for user $uid', name: 'TelegramRepository');
    } catch (e, st) {
      dev.log('[TELEGRAM] Failed to connect Telegram: $e', name: 'TelegramRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> connectTelegram(String uid, String chatId, {String? role, String? username}) =>
      linkTelegram(uid, chatId, role: role, username: username);

  @override
  Future<void> disconnectTelegram(String uid, {String? role}) async {
    if (uid.isEmpty) return;
    try {
      dev.log('[TELEGRAM] Disconnecting Telegram for user $uid', name: 'TelegramRepository');
      final batch = _db.batch();
      final updateData = {
        'telegramLinked': false,
        'telegramConnected': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(_db.collection('users').doc(uid), updateData, SetOptions(merge: true));
      if (role == 'patient' || role == null) {
        batch.set(_db.collection('patients').doc(uid), updateData, SetOptions(merge: true));
      }
      if (role == 'doctor' || role == null) {
        batch.set(_db.collection('doctors').doc(uid), updateData, SetOptions(merge: true));
      }

      await batch.commit();

      try {
        await _activityLogService.logEvent(
          patientId: role == 'patient' ? uid : null,
          doctorId: role == 'doctor' ? uid : null,
          eventType: ActivityEventType.telegramUnlinked,
          title: 'Telegram Disconnected',
          description: 'Telegram notifications were unlinked from this account.',
          actorUid: uid,
          actorRole: role ?? 'patient',
        );
      } catch (_) {}

      dev.log('[TELEGRAM] Successfully disconnected Telegram for user $uid', name: 'TelegramRepository');
    } catch (e, st) {
      dev.log('[TELEGRAM] Failed to disconnect Telegram: $e', name: 'TelegramRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<bool> openTelegramBot(String uid, {String? linkingCode}) async {
    dev.log('[TELEGRAM] Opening Telegram bot for user $uid with code $linkingCode', name: 'TelegramRepository');
    final param = linkingCode != null && linkingCode.isNotEmpty ? linkingCode : uid;
    final botUrl = Uri.parse('https://t.me/ContinuumHealthBot?start=$param');
    try {
      final launched = await launchUrl(
        botUrl,
        mode: LaunchMode.externalApplication,
      );
      dev.log('[TELEGRAM] Bot launch result: $launched', name: 'TelegramRepository');
      return launched;
    } catch (e, st) {
      dev.log('[TELEGRAM] Error launching bot url: $e', name: 'TelegramRepository', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Stream<Map<String, dynamic>> telegramStatusStream(String uid) {
    if (uid.isEmpty) return Stream.value({'connected': false, 'chatId': null});
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return {'connected': false, 'chatId': null};
      return {
        'connected': data['telegramLinked'] == true || data['telegramConnected'] == true,
        'chatId': data['telegramChatId'] as String?,
        'username': data['telegramUsername'] as String?,
      };
    });
  }

  @override
  Future<bool> sendTelegramMessage({
    required String chatId,
    required String text,
    String? recipientUid,
    String? recipientRole,
    String? botToken,
  }) async {
    if (chatId.trim().isEmpty || text.trim().isEmpty) {
      dev.log('[TELEGRAM] Invalid chatId or empty text', name: 'TelegramRepository');
      return false;
    }

    String token = botToken ?? '';
    if (token.isEmpty) {
      try {
        final configDoc = await _db.collection('system').doc('config').get();
        token = configDoc.data()?['telegramBotToken'] as String? ?? '';
      } catch (_) {}
    }

    final cleanChatId = chatId.trim();
    bool success = false;
    String? errorMessage;
    String? messageId;

    if (token.isNotEmpty) {
      try {
        final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chat_id': cleanChatId,
            'text': text,
          }),
        );
        success = response.statusCode == 200;
        if (success) {
          final resData = jsonDecode(response.body) as Map<String, dynamic>?;
          messageId = resData?['result']?['message_id']?.toString();
        } else {
          errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        errorMessage = e.toString();
      }
    } else {
      dev.log('[TELEGRAM] Simulated message to $cleanChatId (Bot token unconfigured): $text', name: 'TelegramRepository');
      success = true;
    }

    try {
      await _activityLogService.logEvent(
        patientId: recipientRole == 'doctor' ? null : recipientUid,
        doctorId: recipientRole == 'doctor' ? recipientUid : null,
        eventType: success ? ActivityEventType.notificationSent : ActivityEventType.notificationFailed,
        title: success ? 'Telegram Notification Sent' : 'Telegram Notification Failed',
        description: success
            ? 'Delivered to Telegram chat $cleanChatId.'
            : 'Delivery failed to Telegram chat $cleanChatId: ${errorMessage ?? "Bot token unconfigured"}',
        actorUid: recipientUid ?? 'system',
        actorRole: recipientRole ?? 'system',
        deliveryStatus: success ? 'sent' : 'failed',
        metadata: {
          'chatId': cleanChatId,
          'telegramMessageId': messageId,
          'telegramStatus': success ? 'sent' : 'failed',
          'telegramError': errorMessage,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}

    return success;
  }

  @override
  Future<bool> sendTargetedTelegramNotification({
    required String targetPatientId,
    required String text,
    required String notificationType,
    String? eventId,
    String? botToken,
  }) async {
    if (targetPatientId.isEmpty) return false;

    // 1. Resolve Target Patient
    String? chatId;
    bool isLinked = false;
    String patientName = 'Patient';

    try {
      final pDoc = await _db.collection('patients').doc(targetPatientId).get();
      if (pDoc.exists && pDoc.data() != null) {
        final data = pDoc.data()!;
        chatId = data['telegramChatId'] as String?;
        isLinked = data['telegramLinked'] == true || data['telegramConnected'] == true;
        patientName = data['name'] as String? ?? patientName;
      } else {
        final uDoc = await _db.collection('users').doc(targetPatientId).get();
        if (uDoc.exists && uDoc.data() != null) {
          final data = uDoc.data()!;
          chatId = data['telegramChatId'] as String?;
          isLinked = data['telegramLinked'] == true || data['telegramConnected'] == true;
          patientName = data['name'] as String? ?? patientName;
        }
      }
    } catch (e) {
      dev.log('[TELEGRAM RESOLVE ERROR] $e', name: 'TelegramRepository');
    }

    // 2. Debug Log
    dev.log('''
[TELEGRAM DEBUG]
patientId: $targetPatientId
telegramLinked: $isLinked
telegramChatId exists: ${chatId != null && chatId.isNotEmpty}
notificationType: $notificationType
eventId: $eventId
'''.trim(), name: 'TelegramRepository');

    // 3. Guard against unlinked accounts
    if (!isLinked || chatId == null || chatId.isEmpty) {
      dev.log('[TELEGRAM] Telegram not linked for patient $targetPatientId. Skipping dispatch.', name: 'TelegramRepository');
      try {
        await _activityLogService.logEvent(
          patientId: targetPatientId,
          eventType: ActivityEventType.general,
          title: 'Telegram Not Linked',
          description: 'Telegram notification ($notificationType) skipped: Patient $patientName has not linked Telegram.',
          actorUid: targetPatientId,
          actorRole: 'system',
          metadata: {
            'targetPatientId': targetPatientId,
            'notificationType': notificationType,
            'eventId': eventId,
            'telegramStatus': 'telegram_not_linked',
          },
        );
      } catch (_) {}
      return false;
    }

    // 4. Send Message to that Exact target chat_id
    final success = await sendTelegramMessage(
      chatId: chatId,
      text: text,
      recipientUid: targetPatientId,
      recipientRole: 'patient',
      botToken: botToken,
    );

    return success;
  }
}
