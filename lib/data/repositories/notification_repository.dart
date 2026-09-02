import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class FirebaseNotificationRepository {
  final FirebaseFirestore _db;
  FirebaseNotificationRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _notifications(String userId, UserType type) {
    final collection = type == UserType.patient ? 'patients' : 'doctors';
    return _db.collection(collection).doc(userId).collection('notifications');
  }

  Stream<List<NotificationModel>> notificationsStream(String userId, UserType type) {
    return _notifications(userId, type)
        .limit(50)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => NotificationModel.fromFirestore(d))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  Future<void> markAsRead(String userId, UserType type, String notificationId) async {
    await _notifications(userId, type).doc(notificationId).update({
      'isRead': true,
      'status': 'read',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNotificationStatus(
    String userId,
    UserType type,
    String notificationId,
    String status,
  ) async {
    final isRead = status == 'read' || status == 'actioned' || status == 'rejected';
    await _notifications(userId, type).doc(notificationId).update({
      'status': status,
      'isRead': isRead,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendNotification({
    required String recipientUid,
    required UserType recipientType,
    required Map<String, dynamic> data,
  }) async {
    final docRef = _notifications(recipientUid, recipientType).doc();
    final payload = <String, dynamic>{
      ...data,
      'id': docRef.id,
      'notificationId': docRef.id,
      'recipientUid': recipientUid,
      'status': data['status'] ?? 'unread',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    await docRef.set(payload);
  }

  Future<void> markAllAsRead(String userId, UserType type) async {
    final unread = await _notifications(userId, type)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'status': 'read',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

enum UserType { patient, doctor }

