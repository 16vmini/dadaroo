import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    // The actual display logic would use a snackbar or overlay in the UI.
    // This is a hook for the provider to listen to.
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
  /// The actual sending happens via a Cloud Function that watches this collection.
  /// This method writes a notification request to Firestore.
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

  /// Notify family that Dad started a delivery.
  Future<void> notifyDeliveryStarted({
    required String familyGroupId,
    required String dadName,
    required String takeawayName,
  }) async {
    await sendFamilyNotification(
      familyGroupId: familyGroupId,
      title: '$dadName has the food!',
      body: '$dadName is bringing $takeawayName home!',
      type: 'delivery_started',
    );
  }

  /// Notify family that Dad is close.
  Future<void> notifyDadIsClose({
    required String familyGroupId,
    required String dadName,
  }) async {
    await sendFamilyNotification(
      familyGroupId: familyGroupId,
      title: '$dadName is almost home!',
      body: 'Get the plates ready - less than 2 minutes away!',
      type: 'dad_close',
    );
  }

  /// Notify Dad that a rating came in.
  Future<void> notifyRatingReceived({
    required String dadUid,
    required double averageRating,
  }) async {
    final doc = await _firestore.collection('users').doc(dadUid).get();
    final token = doc.data()?['fcmToken'];
    if (token == null) return;

    // Write notification request targeting specific user
    await _firestore.collection('notificationRequests').add({
      'targetUid': dadUid,
      'title': 'New Rating!',
      'body': 'You got ${averageRating.toStringAsFixed(1)} stars!',
      'type': 'rating_received',
      'createdAt': FieldValue.serverTimestamp(),
      'processed': false,
    });
  }

  void dispose() {
    // Cleanup if needed
  }
}
