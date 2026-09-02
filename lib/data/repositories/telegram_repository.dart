import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class TelegramRepository {
  Future<void> connectTelegram(String uid, String chatId);
  Future<void> disconnectTelegram(String uid);
  Future<bool> openTelegramBot(String uid);
  Stream<Map<String, dynamic>> telegramStatusStream(String uid);
}

class FirebaseTelegramRepository implements TelegramRepository {
  final FirebaseFirestore _db;

  FirebaseTelegramRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  @override
  Future<void> connectTelegram(String uid, String chatId) async {
    if (uid.isEmpty) {
      dev.log('[TELEGRAM] Error: User UID is empty', name: 'TelegramRepository');
      throw Exception('Authentication required to connect Telegram.');
    }
    if (chatId.trim().isEmpty) {
      dev.log('[TELEGRAM] Error: Chat ID is empty', name: 'TelegramRepository');
      throw Exception('Telegram Chat ID cannot be empty.');
    }

    try {
      dev.log('[TELEGRAM] Connecting Telegram chat  for user ', name: 'TelegramRepository');
      await _db.collection('users').doc(uid).set({
        'telegramChatId': chatId.trim(),
        'telegramConnected': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      dev.log('[TELEGRAM] Successfully connected Telegram for user ', name: 'TelegramRepository');
    } catch (e, st) {
      dev.log('[TELEGRAM] Failed to connect Telegram: ', name: 'TelegramRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> disconnectTelegram(String uid) async {
    if (uid.isEmpty) return;
    try {
      dev.log('[TELEGRAM] Disconnecting Telegram for user ', name: 'TelegramRepository');
      await _db.collection('users').doc(uid).set({
        'telegramConnected': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      dev.log('[TELEGRAM] Successfully disconnected Telegram for user ', name: 'TelegramRepository');
    } catch (e, st) {
      dev.log('[TELEGRAM] Failed to disconnect Telegram: ', name: 'TelegramRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<bool> openTelegramBot(String uid) async {
    dev.log('[TELEGRAM] Opening Telegram bot for user ', name: 'TelegramRepository');
    final botUrl = Uri.parse('https://t.me/ContinuumHealthBot?start=');
    try {
      final launched = await launchUrl(
        botUrl,
        mode: LaunchMode.externalApplication,
      );
      dev.log('[TELEGRAM] Bot launch result: ', name: 'TelegramRepository');
      return launched;
    } catch (e, st) {
      dev.log('[TELEGRAM] Error launching bot url: ', name: 'TelegramRepository', error: e, stackTrace: st);
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
        'connected': data['telegramConnected'] == true,
        'chatId': data['telegramChatId'] as String?,
      };
    });
  }
}
