import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handles Firebase Cloud Messaging token registration and message handling.
/// This service must be initialized after Firebase.initializeApp().
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM: request permission and register token.
  /// Call this once after user logs in.
  Future<void> initialize({
    required String userId,
    required String userCollection, // 'patients' or 'doctors'
  }) async {
    // Request permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // User denied — gracefully skip
      return;
    }

    // Get the FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(userId, userCollection, token);
    }

    // Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(userId, userCollection, newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Set up background message handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _saveToken(
      String userId, String collection, String token) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(userId)
        .update({'fcmToken': token}).catchError((_) {
      // Ignore if doc doesn't exist yet
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // In-app notification — the notification bell stream handles this
    // via Firestore realtime listener so no additional action needed here.
  }

  /// Unregister FCM token on logout
  Future<void> unregister({
    required String userId,
    required String userCollection,
  }) async {
    await _messaging.deleteToken();
    await FirebaseFirestore.instance
        .collection(userCollection)
        .doc(userId)
        .update({'fcmToken': null}).catchError((_) {});
  }
}

/// Top-level background message handler (required by Firebase Messaging)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the OS notification system.
  // Firestore realtime streams will update the UI when app resumes.
}
