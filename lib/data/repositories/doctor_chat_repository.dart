import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_chat_model.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';
import '../repositories/notification_repository.dart';

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
  final FirebaseNotificationRepository? _notificationRepository;

  FirebaseDoctorChatRepository({
    FirebaseFirestore? db,
    ActivityLogService? activityLogService,
    FirebaseNotificationRepository? notificationRepository,
  })  : _db = db,
        _activityLogService = activityLogService,
        _notificationRepository = notificationRepository;

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
    final db = _db ?? FirebaseFirestore.instance;
    final chatId = generateChatId(patientId, doctorId);

    try {
      final participants = [patientId, doctorId]..sort();
      final convData = <String, dynamic>{
        'id': chatId,
        'chatId': chatId,
        'patientId': patientId,
        'doctorId': doctorId,
        'participants': participants,
        if (doctorName != null) 'doctorName': doctorName,
        if (doctorSpecialty != null) 'doctorSpecialty': doctorSpecialty,
        if (doctorAvatar != null) 'doctorAvatar': doctorAvatar,
        if (patientName != null) 'patientName': patientName,
        if (patientAvatar != null) 'patientAvatar': patientAvatar,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = db.batch();
      // Primary: doctor_chats
      batch.set(db.collection('doctor_chats').doc(chatId), convData, SetOptions(merge: true));
      // Legacy compatibility: doctorChats
      batch.set(db.collection('doctorChats').doc(chatId), convData, SetOptions(merge: true));
      await batch.commit();

      dev.log('[DOCTOR_CHAT] Ready conversation: $chatId (participants: $participants)', name: 'DoctorChatRepository');
      return chatId;
    } catch (e) {
      dev.log('[DOCTOR_CHAT ERROR] Failed to get or create conversation: $e', name: 'DoctorChatRepository');
      return chatId;
    }
  }

  @override
  Stream<List<DoctorChatMessage>> streamMessages(String chatId) {
    final db = _db ?? FirebaseFirestore.instance;
    if (chatId.isEmpty) return Stream.value([]);

    return db
        .collection('doctorChats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) {
            return <DoctorChatMessage>[];
          }
          return snap.docs.map((d) => DoctorChatMessage.fromFirestore(d)).toList();
        });
  }

  @override
  Stream<List<DoctorConversation>> streamPatientConversations(String patientId) {
    final db = _db ?? FirebaseFirestore.instance;
    if (patientId.isEmpty) return Stream.value([]);

    return db
        .collection('doctorChats')
        .where('participants', arrayContains: patientId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DoctorConversation.fromFirestore(d)).toList());
  }

  @override
  Stream<List<DoctorConversation>> streamDoctorConversations(String doctorId) {
    final db = _db ?? FirebaseFirestore.instance;
    if (doctorId.isEmpty) return Stream.value([]);

    return db
        .collection('doctorChats')
        .where('participants', arrayContains: doctorId)
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
    final db = _db ?? FirebaseFirestore.instance;
    if (chatId.isEmpty || text.trim().isEmpty) return;

    final trimmed = text.trim();

    final effectiveReceiverId = receiverId ?? () {
      final parts = chatId.split('_');
      if (parts.length >= 2) {
        return parts[0] == senderId ? parts[1] : parts[0];
      }
      return null;
    }();

    final docRefPrimary = db.collection('doctor_chats').doc(chatId).collection('messages').doc();
    final msgData = {
      'id': docRefPrimary.id,
      'messageId': docRefPrimary.id,
      'conversationId': chatId,
      'chatId': chatId,
      'senderId': senderId,
      if (effectiveReceiverId != null) 'receiverId': effectiveReceiverId,
      'senderRole': senderRole,
      'senderName': senderName,
      if (senderPhoto != null) 'senderPhoto': senderPhoto,
      'text': trimmed,
      'content': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
    };

    final convUpdate = {
      'lastMessage': trimmed,
      'lastSenderId': senderId,
      'lastSenderName': senderName,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = db.batch();
    // 1. Primary write: doctor_chats
    batch.set(docRefPrimary, msgData);
    batch.set(db.collection('doctor_chats').doc(chatId), convUpdate, SetOptions(merge: true));

    // 2. Dual write for compatibility: doctorChats
    final docRefLegacy = db.collection('doctorChats').doc(chatId).collection('messages').doc(docRefPrimary.id);
    batch.set(docRefLegacy, msgData);
    batch.set(db.collection('doctorChats').doc(chatId), convUpdate, SetOptions(merge: true));

    await batch.commit();
    dev.log('[DOCTOR_CHAT] Sent message ${docRefPrimary.id} in $chatId by $senderRole ($senderName)', name: 'DoctorChatRepository');

    // 3. Dispatch in-app notification to receiver (never to sender itself)
    if (effectiveReceiverId != null && effectiveReceiverId.isNotEmpty && effectiveReceiverId != senderId) {
      try {
        final recipientType = senderRole == 'doctor' ? UserType.patient : UserType.doctor;
        final title = senderRole == 'doctor' ? 'Message from Dr. $senderName' : 'Message from $senderName';
        await _notificationRepository?.sendNotification(
          recipientUid: effectiveReceiverId,
          recipientType: recipientType,
          data: {
            'senderUid': senderId,
            'type': 'doctor_message',
            'title': title,
            'body': trimmed,
            'message': trimmed,
            'priority': 'high',
            'doctorId': senderRole == 'doctor' ? senderId : effectiveReceiverId,
            'doctorName': senderRole == 'doctor' ? senderName : null,
            'patientId': senderRole == 'patient' ? senderId : effectiveReceiverId,
            'patientName': senderRole == 'patient' ? senderName : null,
            'conversationId': chatId,
            'chatId': chatId,
          },
        );
      } catch (e) {
        dev.log('[DOCTOR_CHAT ERROR] Failed to send notification to recipient: $e', name: 'DoctorChatRepository');
      }
    }

    // 4. Audit activity logging
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
          'messageId': docRefPrimary.id,
          'senderRole': senderRole,
        },
      );
    } catch (_) {}
  }
}
