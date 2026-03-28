import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadaroo/models/delivery.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Request notification permissions and get FCM token.
  Future<String?> initialize(String uid) async {
    // Request permission (required on iOS, no-op on Android 12 and below)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    // Get FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(uid, token);
    }

    // Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(uid, newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    return token;
  }

  Future<void> _saveToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Foreground messages can be shown as in-app notifications.
  }

  /// Subscribe to a family group topic for group notifications.
  Future<void> subscribeToFamily(String familyGroupId) async {
    await _messaging.subscribeToTopic('family_$familyGroupId');
  }

  /// Unsubscribe from a family group topic.
  Future<void> unsubscribeFromFamily(String familyGroupId) async {
    await _messaging.unsubscribeFromTopic('family_$familyGroupId');
  }

  /// Send a notification to all family members via Firestore trigger.
  Future<void> sendFamilyNotification({
    required String familyGroupId,
    required String title,
    required String body,
    required String type,
    Map<String, String>? data,
  }) async {
    await _firestore.collection('notificationRequests').add({
      'familyGroupId': familyGroupId,
      'title': title,
      'body': body,
      'type': type,
      'data': data ?? {},
      'createdAt': FieldValue.serverTimestamp(),
      'processed': false,
    });
  }

  /// Notify family that parent started a delivery.
  Future<void> notifyDeliveryStarted({
    required String familyGroupId,
    required String parentName,
    required String takeawayName,
  }) async {
    await sendFamilyNotification(
      familyGroupId: familyGroupId,
      title: '$parentName has the food!',
      body: '$parentName is bringing $takeawayName home!',
      type: 'delivery_started',
    );
  }

  /// Notify family that parent is close.
  Future<void> notifyParentIsClose({
    required String familyGroupId,
    required String parentName,
  }) async {
    await sendFamilyNotification(
      familyGroupId: familyGroupId,
      title: '$parentName is almost home!',
      body: 'Get the plates ready - less than 2 minutes away!',
      type: 'parent_close',
    );
  }

  /// Notify parent that a rating came in.
  Future<void> notifyRatingReceived({
    required String parentUid,
    required double averageRating,
  }) async {
    final doc = await _firestore.collection('users').doc(parentUid).get();
    final token = doc.data()?['fcmToken'];
    if (token == null) return;

    await _firestore.collection('notificationRequests').add({
      'targetUid': parentUid,
      'title': 'New Rating!',
      'body': 'You got ${averageRating.toStringAsFixed(1)} stars!',
      'type': 'rating_received',
      'createdAt': FieldValue.serverTimestamp(),
      'processed': false,
    });
  }

  /// Notify family of a delivery status change.
  Future<void> notifyStatusUpdate({
    required String familyGroupId,
    required String parentName,
    required DeliveryStatus status,
  }) async {
    await sendFamilyNotification(
      familyGroupId: familyGroupId,
      title: '${status.emoji} ${status.displayName}',
      body: '$parentName ${status.familyMessage}',
      type: 'status_update',
      data: {'status': status.name},
    );
  }

  void dispose() {
    // Cleanup if needed
  }
}
