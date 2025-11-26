import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';

/// Comprehensive Notification Service
/// Handles system notifications for alerts when:
/// - Phone is locked
/// - App is in background
/// - User is on another screen
/// - Phone is on silent (vibration fallback)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  Function(String?)? _onNotificationTapped;

  /// Initialize the notification service
  Future<void> initialize({Function(String?)? onNotificationTapped}) async {
    if (_isInitialized) return;

    _onNotificationTapped = onNotificationTapped;

    // Android settings - high importance for alert notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // For important alerts
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // Request permissions
    await _requestPermissions();

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ requires explicit notification permission
      final status = await Permission.notification.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
      return result ?? false;
    }
    return true;
  }

  /// Handle notification tap
  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    _onNotificationTapped?.call(response.payload);
  }

  /// Handle background notification tap
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint('Background notification tapped: ${response.payload}');
  }

  /// Show an incoming alert notification
  /// This will appear even when phone is locked or app is in background
  Future<void> showAlertNotification({
    required String title,
    required String body,
    String? payload,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Android notification details - HIGH priority for lock screen visibility
    final androidDetails = AndroidNotificationDetails(
      'yuh_blockin_alerts',
      'Yuh Blockin Alerts',
      channelDescription: 'Important parking alert notifications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: playSound,
      enableVibration: vibrate,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]), // Premium vibration pattern
      enableLights: true,
      ledColor: Color(0xFF4CAF50), // Green LED
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true, // Shows on lock screen
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public, // Show on lock screen
      ticker: 'Someone needs you to move your car!',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Yuh Blockin',
      ),
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      threadIdentifier: 'yuh_blockin_alerts',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
      title,
      body,
      details,
      payload: payload,
    );

    // Additional vibration for silent mode
    if (vibrate) {
      await _vibrateForSilentMode();
    }
  }

  /// Vibrate even when phone is on silent
  /// Uses a premium pattern: short-short-long
  Future<void> _vibrateForSilentMode() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        // Check if custom vibration is available
        final hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;

        if (hasAmplitudeControl) {
          // Premium vibration with amplitude control
          await Vibration.vibrate(
            pattern: [0, 200, 100, 200, 100, 400],
            intensities: [0, 255, 0, 255, 0, 255],
          );
        } else {
          // Fallback pattern
          await Vibration.vibrate(
            pattern: [0, 200, 100, 200, 100, 400],
          );
        }
      }
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }

  /// Show a simple vibration-only notification (for when sound is disabled)
  Future<void> vibrateOnly() async {
    await _vibrateForSilentMode();
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  /// Show a warning notification (for errors, no internet, etc.)
  Future<void> showWarningNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'yuh_blockin_warnings',
      'Yuh Blockin Warnings',
      channelDescription: 'App warnings and status notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: true,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000) + 50000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
