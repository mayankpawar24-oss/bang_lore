import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ai_chat_model.dart';

class FirebaseAIChatRepository {
  final FirebaseFirestore _db;
  FirebaseAIChatRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _chats(String patientId) =>
      _db.collection('patients').doc(patientId).collection('aiChats');

  CollectionReference _messages(String patientId, String chatId) =>
      _chats(patientId).doc(chatId).collection('messages');

  Stream<List<AIChat>> chatsStream(String patientId) {
    return _chats(patientId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AIChat.fromFirestore(d)).toList());
  }

  Stream<List<AIChatMessage>> messagesStream(String patientId, String chatId) {
    return _messages(patientId, chatId)
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs.map((d) => AIChatMessage.fromFirestore(d)).toList());
  }

  Future<AIChat> createChat(String patientId, {String title = 'New Conversation'}) async {
    final ref = _chats(patientId).doc();
    final chat = AIChat(
      id: ref.id,
      patientId: patientId,
      title: title,
      createdAt: DateTime.now(),
    );
    await ref.set(chat.toFirestoreCreate());
    return chat;
  }

  Future<void> addMessage(String patientId, String chatId, AIChatMessage message) async {
    final ref = _messages(patientId, chatId).doc();
    await ref.set(message.toFirestoreCreate());
    // Update chat updatedAt
    await _chats(patientId).doc(chatId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleDoctorSharing(String patientId, String chatId, bool share) async {
    await _chats(patientId).doc(chatId).update({
      'sharedWithDoctor': share,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteChat(String patientId, String chatId) async {
    // Delete all messages first
    final messages = await _messages(patientId, chatId).get();
    final batch = _db.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_chats(patientId).doc(chatId));
    await batch.commit();
  }

  Future<List<AIChat>> getSharedChats(String patientId) async {
    final snap = await _chats(patientId)
        .where('sharedWithDoctor', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .get();
    return snap.docs.map((d) => AIChat.fromFirestore(d)).toList();
  }
}
