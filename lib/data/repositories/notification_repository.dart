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
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationModel.fromFirestore(d))
            .toList());
  }

  Future<void> markAsRead(String userId, UserType type, String notificationId) async {
    await _notifications(userId, type).doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllAsRead(String userId, UserType type) async {
    final unread = await _notifications(userId, type)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}

enum UserType { patient, doctor }
