import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_chat_model.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';

abstract class DoctorChatRepository {
  Future<String> getOrCreateConversation({
    required String patientId,
    required String doctorId,
    String? doctorName,
    String? doctorSpecialty,
    String? doctorAvatar,
    String? patientName,
    String? patientAvatar,
  });

  Stream<List<DoctorChatMessage>> streamMessages(String chatId);
  Stream<List<DoctorConversation>> streamPatientConversations(String patientId);
  Stream<List<DoctorConversation>> streamDoctorConversations(String doctorId);

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderRole,
    required String senderName,
    String? receiverId,
    String? senderPhoto,
    required String text,
  });
}

class FirebaseDoctorChatRepository implements DoctorChatRepository {
  final FirebaseFirestore? _db;
  final ActivityLogService? _activityLogService;

  FirebaseDoctorChatRepository({FirebaseFirestore? db, ActivityLogService? activityLogService})
      : _db = db,
        _activityLogService = activityLogService;

  static String generateChatId(String patientId, String doctorId) {
    final list = [patientId, doctorId]..sort();
    return list.join('_');
  }

  @override
  Future<String> getOrCreateConversation({
    required String patientId,
    required String doctorId,
    String? doctorName,
    String? doctorSpecialty,
    String? doctorAvatar,
    String? patientName,
    String? patientAvatar,
  }) async {
    final db = _db;
    if (db == null) return '';
    final chatId = generateChatId(patientId, doctorId);

    try {
      final docRef = db.collection('doctorChats').doc(chatId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        dev.log('[DOCTOR_CHAT] Creating new conversation: $chatId', name: 'DoctorChatRepository');
        final newConv = DoctorConversation(
          id: chatId,
          patientId: patientId,
          doctorId: doctorId,
          doctorName: doctorName,
          doctorSpecialty: doctorSpecialty,
          doctorAvatar: doctorAvatar,
          patientName: patientName,
          patientAvatar: patientAvatar,
          createdAt: DateTime.now(),
          status: 'active',
        );
        await docRef.set(newConv.toFirestore());
      } else {
        // Update profile fields if provided
        final updates = <String, dynamic>{};
        if (doctorName != null) updates['doctorName'] = doctorName;
        if (doctorSpecialty != null) updates['doctorSpecialty'] = doctorSpecialty;
        if (doctorAvatar != null) updates['doctorAvatar'] = doctorAvatar;
        if (patientName != null) updates['patientName'] = patientName;
        if (patientAvatar != null) updates['patientAvatar'] = patientAvatar;
        if (updates.isNotEmpty) {
          await docRef.update(updates);
        }
      }
      return chatId;
    } catch (e) {
      dev.log('[DOCTOR_CHAT ERROR] Failed to get or create conversation: $e', name: 'DoctorChatRepository');
      return chatId;
    }
  }

  @override
  Stream<List<DoctorChatMessage>> streamMessages(String chatId) {
    final db = _db;
    if (db == null || chatId.isEmpty) return Stream.value([]);

    return db
        .collection('doctorChats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(150)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DoctorChatMessage.fromFirestore(d)).toList());
  }

  @override
  Stream<List<DoctorConversation>> streamPatientConversations(String patientId) {
    final db = _db;
    if (db == null || patientId.isEmpty) return Stream.value([]);

    return db
        .collection('doctorChats')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DoctorConversation.fromFirestore(d)).toList());
  }

  @override
  Stream<List<DoctorConversation>> streamDoctorConversations(String doctorId) {
    final db = _db;
    if (db == null || doctorId.isEmpty) return Stream.value([]);

    return db
        .collection('doctorChats')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DoctorConversation.fromFirestore(d)).toList());
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderRole,
    required String senderName,
    String? receiverId,
    String? senderPhoto,
    required String text,
  }) async {
    final db = _db;
    if (db == null || chatId.isEmpty || text.trim().isEmpty) return;

    final trimmed = text.trim();
    final now = DateTime.now();

    final effectiveReceiverId = receiverId ?? () {
      final parts = chatId.split('_');
      if (parts.length >= 2) {
        return parts[0] == senderId ? parts[1] : parts[0];
      }
      return null;
    }();

    final msgRef = db.collection('doctorChats').doc(chatId).collection('messages').doc();
    final message = DoctorChatMessage(
      id: msgRef.id,
      conversationId: chatId,
      senderId: senderId,
      receiverId: effectiveReceiverId,
      senderRole: senderRole,
      senderName: senderName,
      senderPhoto: senderPhoto,
      text: trimmed,
      createdAt: now,
    );

    final batch = db.batch();
    batch.set(msgRef, message.toFirestore());
    batch.update(db.collection('doctorChats').doc(chatId), {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    dev.log('[DOCTOR_CHAT] Sent message ${msgRef.id} in $chatId by $senderRole ($senderName)', name: 'DoctorChatRepository');

    // Audit log
    try {
      final parts = chatId.split('_');
      final patientId = parts.isNotEmpty ? parts[0] : senderId;
      await _activityLogService?.logEvent(
        patientId: patientId,
        eventType: ActivityEventType.chatStarted,
        title: 'Doctor Chat Message',
        description: '$senderName sent a message in doctor consultation chat.',
        actorUid: senderId,
        actorRole: senderRole,
        metadata: {
          'chatId': chatId,
          'messageId': msgRef.id,
          'senderRole': senderRole,
        },
      );
    } catch (_) {}
  }
}
