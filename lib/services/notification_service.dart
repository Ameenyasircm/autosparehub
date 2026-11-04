import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler for Firebase Messaging.
/// Must be annotated with @pragma('vm:entry-point') so Flutter AOT doesn't tree-shake it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  debugPrint('FCM Background message received: ${message.messageId} - ${message.notification?.title}');
}

/// Service managing Push Notifications via FCM and local foreground alerts.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Safe accessor for FirebaseMessaging that guards against uninitialized Firebase (e.g. during widget tests)
  FirebaseMessaging? get _fcm {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseMessaging.instance;
      }
    } catch (_) {}
    return null;
  }

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String channelId = 'auto_spare_hub_channel';
  static const String channelName = 'Auto Spare Hub Notifications';
  static const String channelDescription = 'Instant notifications for account approvals, orders, and system updates';

  bool _isInitialized = false;

  /// Initialize Firebase Messaging and local notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final fcm = _fcm;
      if (fcm == null) {
        debugPrint('NotificationService: Firebase not initialized, skipping push messaging init.');
        return;
      }

      // 1. Register top-level background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Request user permissions (Critical for Android 13+ & iOS)
      final settings = await fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('FCM Permission authorization status: ${settings.authorizationStatus}');

      // 3. Initialize local notification channel for Android foreground alerts
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Local notification tapped: ${response.payload}');
        },
      );

      // Create Android Notification Channel
      const androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
      }

      // 4. Set foreground presentation options (iOS/macOS)
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Listen to incoming foreground messages and present local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.notification?.title}');
        final notification = message.notification;
        if (notification != null) {
          showNotification(
            title: notification.title ?? 'Auto Spare Hub',
            body: notification.body ?? '',
            payload: message.data.toString(),
          );
        }
      });

      _isInitialized = true;
      debugPrint('NotificationService successfully initialized.');
    } catch (e) {
      debugPrint('NotificationService.initialize error: $e');
    }
  }

  /// Check if notification permission has been granted; if not, prompt the user for permission.
  /// Works across iOS and Android (including Android 13+ runtime POST_NOTIFICATIONS).
  Future<bool> requestPermissionIfNotGranted() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return false;

      final currentSettings = await fcm.getNotificationSettings();
      if (currentSettings.authorizationStatus == AuthorizationStatus.authorized) {
        return true;
      }

      // Request via Firebase Messaging (iOS and Android fallback)
      final newSettings = await fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // On Android 13+ (API 33+), trigger the native runtime permission dialog
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      debugPrint('Notification permission status after prompt: ${newSettings.authorizationStatus}');
      return newSettings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('NotificationService.requestPermissionIfNotGranted error: $e');
      return false;
    }
  }

  /// Get current FCM registration token for this device
  Future<String?> getDeviceToken() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return null;
      // ignore: deprecated_member_use
      final token = await fcm.getToken();
      debugPrint('FCM Device Token: $token');
      return token;
    } catch (e) {
      debugPrint('NotificationService.getDeviceToken error: $e');
      return null;
    }
  }

  /// Listen to token refresh events so Firestore can be kept up to date
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _fcm?.onTokenRefresh ?? const Stream<String>.empty();

  /// Show a high-importance local notification banner
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _localNotifications.show(
        id == 0 ? DateTime.now().millisecondsSinceEpoch ~/ 1000 : id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService.showNotification error: $e');
    }
  }
}
