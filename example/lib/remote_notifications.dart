import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Receives data-only FCM messages when Android or an Apple platform starts a
/// background Flutter isolate. Keep this top-level and entry-point annotated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // The operating system already displays notification payloads while the app
  // is backgrounded. Only data-only messages need a local notification.
  if (message.notification == null) {
    await RemoteNotifications.display(message);
  }
}

class RemoteNotifications {
  RemoteNotifications._();

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Initializes FCM without preventing the example from starting before the
  /// developer has added their Firebase configuration files.
  static Future<void> initialize({
    void Function(RemoteMessage message)? onMessageOpened,
  }) async {
    if (!_isSupported) return;

    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );

      FirebaseMessaging.onMessage.listen(display);
      if (onMessageOpened != null) {
        FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpened);
      }

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null && onMessageOpened != null) {
        // The navigator is created by runApp, so deliver a terminated-state
        // tap on the next frame.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => onMessageOpened(initialMessage),
        );
      }

      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM token: $token');
    } on FirebaseException catch (error) {
      debugPrint(
        'FCM is disabled until Firebase is configured for this platform: '
        '${error.message}',
      );
    }
  }

  static Future<void> display(RemoteMessage message) async {
    final data = message.data;
    final remoteNotification = message.notification;
    final title = remoteNotification?.title ?? data['title'] ?? 'New message';
    final body = remoteNotification?.body ?? data['body'] ?? '';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _notificationId(message),
        channelKey: 'alerts',
        title: title,
        body: body,
        payload: <String, String>{
          ...data.map((key, value) => MapEntry(key, value.toString())),
          if (message.messageId != null) 'messageId': message.messageId!,
          'source': 'firebase',
        },
        displayOnForeground: true,
        displayOnBackground: true,
      ),
    );
  }

  static int _notificationId(RemoteMessage message) {
    final value = message.messageId ?? message.sentTime?.toIso8601String();
    return (value ?? DateTime.now().microsecondsSinceEpoch).hashCode &
        0x7fffffff;
  }
}
