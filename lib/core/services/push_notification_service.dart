import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'sound_preferences_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolate
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint('Background push message: ${message.messageId}');
  }
}

/// Push Notification Service
///
/// Handles Firebase Cloud Messaging (FCM) for reliable push notifications
/// when the app is closed or in background.
///
/// This service:
/// - Initializes Firebase and requests notification permissions
/// - Saves FCM tokens to Supabase for server-side push delivery
/// - Handles foreground, background, and terminated app states
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Callback when notification is tapped
  Function(String? alertId)? onNotificationTapped;

  /// Initialize Firebase Messaging and request permissions
  Future<void> initialize({Function(String?)? onTap}) async {
    if (_initialized) return;

    onNotificationTapped = onTap;

    try {
      // Set up the background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permissions (iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
      );

      if (kDebugMode) {
        debugPrint('Push permission status: ${settings.authorizationStatus}');
      }

      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Get and save FCM token
      await _saveToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Handle notification tap (app in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      if (kDebugMode) {
        debugPrint('PushNotificationService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize push notifications: $e');
      }
    }
  }

  /// Initialize local notifications for foreground message display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Already requested via Firebase
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTapped?.call(response.payload);
      },
    );

    // Create notification channel for Android with custom sound
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'yuh_blockin_alerts', // Same channel ID as NotificationService
        'Yuh Blockin Alerts',
        description: 'Push notifications for parking alerts',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alert_sound'),
        enableVibration: true,
        enableLights: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Save FCM token to Supabase
  Future<void> _saveToken() async {
    try {
      // On iOS, try to get APNs token first (with timeout)
      if (Platform.isIOS) {
        try {
          final apnsToken = await _messaging.getAPNSToken().timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
          if (apnsToken == null) {
            if (kDebugMode) {
              debugPrint('APNs token not available yet - will retry later');
            }
            // Don't block - FCM might still work or we'll retry later
          } else {
            if (kDebugMode) {
              debugPrint('APNs token obtained');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('APNs token error: $e');
          }
        }
      }

      // Get FCM token with timeout
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (token == null) {
        if (kDebugMode) {
          debugPrint('FCM token is null');
        }
        return;
      }

      // ===== FCM TOKEN FOR TESTING =====
      // Print full token so it can be copied for push notification testing
      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════════════╗');
      debugPrint('║                    FCM TOKEN FOR TESTING                     ║');
      debugPrint('╠══════════════════════════════════════════════════════════════╣');
      debugPrint('║ $token');
      debugPrint('╚══════════════════════════════════════════════════════════════╝');
      debugPrint('');
      // ==================================

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('No user ID found, skipping token save');
        }
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';

      // Save to Supabase device_tokens table
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, fcm_token');

      if (kDebugMode) {
        debugPrint('FCM Token saved: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to save FCM token: $e');
      }
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String token) {
    if (kDebugMode) {
      debugPrint('FCM token refreshed');
    }
    _saveToken();
  }

  /// Handle foreground message - show local notification
  void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Foreground message: ${message.notification?.title}');
    }

    // Show local notification since app is in foreground
    final notification = message.notification;
    if (notification != null) {
      // Get urgency level from message data, default to 'normal'
      final urgencyLevel = message.data['urgency_level'] ?? 'normal';
      _showLocalNotification(
        title: notification.title ?? 'New Alert',
        body: notification.body ?? 'You have a new alert',
        payload: message.data['alert_id'],
        urgencyLevel: urgencyLevel,
      );
    }
  }

  /// Handle notification tap when app was in background
  void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Notification opened app: ${message.data}');
    }
    _handleNotificationTap(message);
  }

  /// Process notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final alertId = message.data['alert_id'] as String?;
    onNotificationTapped?.call(alertId);
  }

  /// Show a local notification with custom alert sound based on urgency level
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String urgencyLevel = 'normal',
  }) async {
    // Get the user's selected sound for this urgency level
    final soundPrefs = SoundPreferencesService();
    final selectedSoundPath = await soundPrefs.getSoundForLevel(urgencyLevel);

    // Extract sound filename without extension for Android (res/raw)
    // e.g., 'sounds/low/low_alert_1.wav' -> 'low_alert_1'
    final soundFileName = selectedSoundPath.split('/').last.replaceAll('.wav', '');

    // For iOS, just the filename with extension
    final iosSoundFileName = selectedSoundPath.split('/').last;

    if (kDebugMode) {
      debugPrint('Push notification sound: $soundFileName (urgency: $urgencyLevel)');
    }

    // Android: Use a channel ID specific to this sound file
    // This is required because Android caches channel settings including sound
    final channelId = 'yuh_blockin_alert_$soundFileName';

    // Create the notification channel for this specific sound
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final channel = AndroidNotificationChannel(
          channelId,
          'Yuh Blockin Alerts',
          description: 'Parking alert notifications',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundFileName),
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(channel);
      }
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Yuh Blockin Alerts',
      channelDescription: 'Push notifications for parking alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundFileName),
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: iosSoundFileName,
      interruptionLevel: InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Remove FCM token on logout
  Future<void> removeToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('fcm_token', token);

      if (kDebugMode) {
        debugPrint('FCM token removed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to remove FCM token: $e');
      }
    }
  }

  /// Update user ID and re-save token
  Future<void> updateUserId(String userId) async {
    await _saveToken();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
           settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Request notification permissions again
  Future<bool> requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Get current FCM token (for debugging)
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
