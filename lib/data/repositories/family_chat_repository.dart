import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_message_model.dart';
import '../models/report_model.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';

abstract class FamilyChatRepository {
  Stream<List<FamilyMessageModel>> streamMessages(String patientId, {String? chatId});
  Stream<List<FamilyMessageModel>> streamFamilyMessages(String familyId);

  Future<void> sendMessage({
    required String patientId,
    required String senderId,
    required String senderName,
    required String content,
    String? chatId,
    String? senderAvatar,
    String? senderRole,
  });

  Future<void> sendFamilyGroupMessage({
    required String familyId,
    required String senderId,
    required String senderName,
    String? senderPhoto,
    required String text,
    String? patientId,
  });
  Future<void> shareReport({
    required String patientId,
    required String senderId,
    required String senderName,
    required ReportModel report,
    String? chatId,
    String? note,
  });
  Future<void> markRead(String patientId, String messageId, String readerId, {String? chatId});
}

class FirebaseFamilyChatRepository implements FamilyChatRepository {
  final FirebaseFirestore? _db;
  final ActivityLogService? _activityLogService;

  FirebaseFamilyChatRepository({FirebaseFirestore? db, ActivityLogService? activityLogService})
      : _db = db,
        _activityLogService = activityLogService;

  String _resolveChatId(String patientId, [String? customChatId]) {
    if (customChatId != null && customChatId.isNotEmpty) return customChatId;
    return 'chat_$patientId';
  }

  CollectionReference? _rootChatMessagesCol(String chatId) =>
      _db?.collection('familyChats').doc(chatId).collection('messages');

  CollectionReference? _patientChatCol(String patientId) =>
      _db?.collection('patients').doc(patientId).collection('familyChat');

  @override
  Stream<List<FamilyMessageModel>> streamFamilyMessages(String familyId) {
    if (familyId.isEmpty || _db == null) return Stream.value([]);

    return _db!
        .collection('families')
        .doc(familyId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) => FamilyMessageModel.fromFirestore(d)).toList();
        });
  }

  @override
  Future<void> sendFamilyGroupMessage({
    required String familyId,
    required String senderId,
    required String senderName,
    String? senderPhoto,
    required String text,
    String? patientId,
  }) async {
    final db = _db;
    if (db == null || familyId.isEmpty || text.trim().isEmpty) return;

    final trimmed = text.trim();
    final now = DateTime.now();

    final docRef = db.collection('families').doc(familyId).collection('messages').doc();
    final message = FamilyMessageModel(
      id: docRef.id,
      patientId: patientId ?? senderId,
      familyId: familyId,
      senderId: senderId,
      senderName: senderName,
      senderRole: 'family',
      senderAvatar: senderPhoto,
      content: trimmed,
      timestamp: now,
      type: 'text',
      readBy: [senderId],
    );

    final msgData = message.toFirestore();

    final batch = db.batch();
    // 1. Write to families/{familyId}/messages/{messageId}
    batch.set(docRef, msgData);

    // 2. Update families/{familyId} metadata
    batch.set(db.collection('families').doc(familyId), {
      'familyId': familyId,
      'memberIds': FieldValue.arrayUnion([senderId, if (patientId != null) patientId]),
      'members': FieldValue.arrayUnion([senderId, if (patientId != null) patientId]),
      'lastMessage': trimmed,
      'lastSenderName': senderName,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Dual-sync to familyChats for backward compatibility
    final legacyRef = db.collection('familyChats').doc(familyId).collection('messages').doc(docRef.id);
    batch.set(legacyRef, msgData);

    await batch.commit();
    dev.log('[FAMILY_CHAT] Sent group message ${docRef.id} to family $familyId from $senderName', name: 'FamilyChatRepository');

    try {
      await _activityLogService?.logEvent(
        patientId: patientId ?? senderId,
        eventType: ActivityEventType.chatStarted,
        title: 'Family Chat Message',
        description: '$senderName sent a message to the family group.',
        actorUid: senderId,
        actorRole: 'patient',
        metadata: {
          'familyId': familyId,
          'messageId': docRef.id,
        },
      );
    } catch (_) {}
  }

  @override
  Stream<List<FamilyMessageModel>> streamMessages(String patientId, {String? chatId}) {
    if (patientId.isEmpty || _db == null) return Stream.value([]);
    final effChatId = _resolveChatId(patientId, chatId);
    final rootCol = _rootChatMessagesCol(effChatId);
    if (rootCol == null) return Stream.value([]);

    return rootCol
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          if (snap.docs.isNotEmpty) {
            return snap.docs.map((d) => FamilyMessageModel.fromFirestore(d)).toList();
          }
          return [];
        });
  }

  @override
  Future<void> sendMessage({
    required String patientId,
    required String senderId,
    required String senderName,
    required String content,
    String? chatId,
    String? senderAvatar,
    String? senderRole,
  }) async {
    if (content.trim().isEmpty || patientId.isEmpty || _db == null) return;
    final effChatId = _resolveChatId(patientId, chatId);

    final rootCol = _rootChatMessagesCol(effChatId);
    if (rootCol == null) return;
    final docRef = rootCol.doc();

    final message = FamilyMessageModel(
      id: docRef.id,
      patientId: patientId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole ?? 'member',
      senderAvatar: senderAvatar,
      content: content.trim(),
      timestamp: DateTime.now(),
      type: 'text',
      readBy: [senderId],
    );

    final msgData = message.toFirestore();

    // 1. Write to root familyChats/{chatId}/messages/{messageId}
    await docRef.set(msgData);

    // 2. Update familyChats metadata
    await _db?.collection('familyChats').doc(effChatId).set({
      'chatId': effChatId,
      'memberIds': FieldValue.arrayUnion([patientId, senderId]),
      'lastMessage': content.trim(),
      'lastSenderName': senderName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Mirror write to patients/{patientId}/familyChat for backward compatibility
    try {
      await _patientChatCol(patientId)?.doc(docRef.id).set(msgData);
    } catch (_) {}

    // 4. Log to Activity Logs
    try {
      await _activityLogService?.logEvent(
        patientId: patientId,
        eventType: ActivityEventType.chatStarted,
        title: 'Family Message Sent',
        description: '$senderName posted in Family Chat: "${content.trim()}"',
        actorUid: senderId,
        actorRole: senderRole ?? 'patient',
        actorName: senderName,
        metadata: {'chatId': effChatId, 'messageId': docRef.id},
      );
    } catch (e) {
      dev.log('Failed to log family message event: $e', name: 'FamilyChatRepository');
    }
  }

  @override
  Future<void> shareReport({
    required String patientId,
    required String senderId,
    required String senderName,
    required ReportModel report,
    String? chatId,
    String? note,
  }) async {
    if (patientId.isEmpty || _db == null) return;
    final effChatId = _resolveChatId(patientId, chatId);

    final rootCol = _rootChatMessagesCol(effChatId);
    if (rootCol == null) return;
    final docRef = rootCol.doc();

    final textContent = note != null && note.trim().isNotEmpty
        ? note.trim()
        : 'Shared health report: ${report.title}';

    final message = FamilyMessageModel(
      id: docRef.id,
      patientId: patientId,
      senderId: senderId,
      senderName: senderName,
      senderRole: 'patient',
      content: textContent,
      timestamp: DateTime.now(),
      type: 'report',
      reportId: report.id,
      reportTitle: report.title,
      reportCategory: report.category.name,
      reportUrl: report.fileUrl,
      reportDate: report.date,
      readBy: [senderId],
    );

    final msgData = message.toFirestore();

    // 1. Write to root familyChats/{chatId}/messages/{messageId}
    await docRef.set(msgData);

    // 2. Update familyChats metadata
    await _db?.collection('familyChats').doc(effChatId).set({
      'chatId': effChatId,
      'memberIds': FieldValue.arrayUnion([patientId, senderId]),
      'lastMessage': 'Report: ${report.title}',
      'lastSenderName': senderName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Mirror write to patients/{patientId}/familyChat
    try {
      await _patientChatCol(patientId)?.doc(docRef.id).set(msgData);
    } catch (_) {}

    // 4. Log to Activity Logs
    try {
      await _activityLogService?.logEvent(
        patientId: patientId,
        reportId: report.id,
        eventType: ActivityEventType.documentUploaded,
        title: 'Report Shared With Family',
        description: '$senderName shared clinical document "${report.title}" with family members.',
        actorUid: senderId,
        actorRole: 'patient',
        actorName: senderName,
        metadata: {'chatId': effChatId, 'reportId': report.id, 'category': report.category.name},
      );
    } catch (e) {
      dev.log('Failed to log report share event: $e', name: 'FamilyChatRepository');
    }
  }

  @override
  Future<void> markRead(String patientId, String messageId, String readerId, {String? chatId}) async {
    if (patientId.isEmpty || messageId.isEmpty || readerId.isEmpty || _db == null) return;
    final effChatId = _resolveChatId(patientId, chatId);
    try {
      await _rootChatMessagesCol(effChatId)?.doc(messageId).update({
        'readBy': FieldValue.arrayUnion([readerId]),
      });
      await _patientChatCol(patientId)?.doc(messageId).update({
        'readBy': FieldValue.arrayUnion([readerId]),
      });
    } catch (_) {}
  }
}
