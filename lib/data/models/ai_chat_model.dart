import 'package:cloud_firestore/cloud_firestore.dart';

class AIChat {
  final String id;
  final String patientId;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool sharedWithDoctor;

  const AIChat({
    required this.id,
    required this.patientId,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    this.sharedWithDoctor = false,
  });

  AIChat copyWith({
    String? id,
    String? patientId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? sharedWithDoctor,
  }) {
    return AIChat(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sharedWithDoctor: sharedWithDoctor ?? this.sharedWithDoctor,
    );
  }

  factory AIChat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIChat(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      title: data['title'] as String? ?? 'Conversation',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      sharedWithDoctor: data['sharedWithDoctor'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'title': title,
      'sharedWithDoctor': sharedWithDoctor,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

enum AIChatSender { user, assistant }

class AIChatMessage {
  final String id;
  final String chatId;
  final AIChatSender sender;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // confidence, recommendedAction, etc.

  const AIChatMessage({
    required this.id,
    required this.chatId,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  bool get isUser => sender == AIChatSender.user;

  factory AIChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIChatMessage(
      id: doc.id,
      chatId: data['chatId'] as String? ?? '',
      sender: AIChatSender.values.firstWhere(
        (e) => e.name == (data['sender'] as String? ?? 'user'),
        orElse: () => AIChatSender.user,
      ),
      content: data['content'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'sender': sender.name,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
