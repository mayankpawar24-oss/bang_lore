import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole; // 'patient' or 'doctor'
  final String senderName;
  final String? senderPhoto;
  final String? receiverId;
  final String text;
  final DateTime createdAt;
  final String type; // 'text', 'attachment', 'call_prep'
  final bool isRead;

  String get messageId => id;

  const DoctorChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    this.senderPhoto,
    this.receiverId,
    required this.text,
    required this.createdAt,
    this.type = 'text',
    this.isRead = false,
  });

  factory DoctorChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final createdTs = data['createdAt'] as Timestamp?;
    return DoctorChatMessage(
      id: doc.id,
      conversationId: data['conversationId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? 'patient',
      senderName: data['senderName'] as String? ?? '',
      senderPhoto: data['senderPhoto'] as String?,
      receiverId: data['receiverId'] as String?,
      text: data['text'] as String? ?? data['content'] as String? ?? '',
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      type: data['type'] as String? ?? 'text',
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'messageId': id,
      'conversationId': conversationId,
      'senderId': senderId,
      if (receiverId != null) 'receiverId': receiverId,
      'senderRole': senderRole,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type,
      'isRead': isRead,
    };
  }
}

class DoctorConversation {
  final String id;
  final String patientId;
  final String doctorId;
  final String? patientName;
  final String? patientAvatar;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String status; // 'active', 'archived'
  final DateTime createdAt;
  final int unreadCount;

  String get chatId => id;
  String get conversationId => id;

  const DoctorConversation({
    required this.id,
    required this.patientId,
    required this.doctorId,
    this.patientName,
    this.patientAvatar,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorAvatar,
    this.lastMessage,
    this.lastMessageAt,
    this.status = 'active',
    required this.createdAt,
    this.unreadCount = 0,
  });

  factory DoctorConversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final lastMsgTs = data['lastMessageAt'] as Timestamp?;
    final createdTs = data['createdAt'] as Timestamp?;

    return DoctorConversation(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      doctorId: data['doctorId'] as String? ?? '',
      patientName: data['patientName'] as String?,
      patientAvatar: data['patientAvatar'] as String?,
      doctorName: data['doctorName'] as String?,
      doctorSpecialty: data['doctorSpecialty'] as String?,
      doctorAvatar: data['doctorAvatar'] as String?,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: lastMsgTs?.toDate(),
      status: data['status'] as String? ?? 'active',
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      unreadCount: data['unreadCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'patientName': patientName,
      'patientAvatar': patientAvatar,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'doctorAvatar': doctorAvatar,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : FieldValue.serverTimestamp(),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'unreadCount': unreadCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
