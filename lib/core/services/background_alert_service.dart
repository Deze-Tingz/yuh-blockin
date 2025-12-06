import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';

/// Background Alert Service
///
/// ARCHITECTURE NOTES:
/// - This service runs as a SEPARATE ISOLATE (Android foreground service)
/// - It works independently from the main app's NotificationService
/// - Purpose: Ensure alerts are received even when app is KILLED or in deep background
///
/// RELATIONSHIP TO NotificationService:
/// - NotificationService: Handles notifications when app is running (foreground/light background)
/// - BackgroundAlertService: Handles notifications when app is fully killed or suspended
/// - Both use the same notification channel ID to prevent duplicates
/// - The same alert ID is used (alertId.hashCode) to deduplicate system notifications
///
/// This dual-service approach ensures reliable alert delivery across all app states.
class BackgroundAlertService {
  static final BackgroundAlertService _instance = BackgroundAlertService._internal();
  factory BackgroundAlertService() => _instance;
  BackgroundAlertService._internal();

  static const String _userIdKey = 'user_id';
  static const String _notificationChannelId = 'yuh_blockin_alerts';
  static const String _notificationChannelName = 'Yuh Blockin Alerts';

  /// Initialize and start the background service
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Configure notification channel for foreground service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Critical parking alert notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'Yuh Blockin',
        initialNotificationContent: 'Ready for alerts',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the background service
  Future<void> startService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  /// Stop the background service
  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Check if service is running
  Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /// Update user ID for alert monitoring
  Future<void> setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);

    // Notify running service of user change
    final service = FlutterBackgroundService();
    service.invoke('updateUser', {'userId': userId});
  }
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Main background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure Flutter bindings are initialized
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize notifications
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);

  // Get stored user ID
  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('user_id');

  StreamSubscription? alertSubscription;
  SupabaseClient? supabase;

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: 'https://oazxwglbvzgpehsckmfb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9henh3Z2xidnpncGVoc2NrbWZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxNzkzMjEsImV4cCI6MjA3ODc1NTMyMX0.Ia6ccZ1zp4r1mi5mgvQk9wfK5MGp0S3TDhyWngz8Z54',
    );
    supabase = Supabase.instance.client;
    debugPrint('Background service: Supabase initialized');
  } catch (e) {
    debugPrint('Background service: Supabase already initialized or error: $e');
    try {
      supabase = Supabase.instance.client;
    } catch (_) {
      debugPrint('Background service: Could not get Supabase client');
    }
  }

  /// Subscribe to alerts for user
  void subscribeToAlerts(String uid) {
    alertSubscription?.cancel();

    if (supabase == null) {
      debugPrint('Background service: No Supabase client, cannot subscribe');
      return;
    }

    debugPrint('Background service: Subscribing to alerts for user: $uid');

    alertSubscription = supabase
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', uid)
        .listen((data) async {
          for (final alert in data) {
            // Check if this is a new unread alert
            if (alert['read_at'] == null && alert['response'] == null) {
              final createdAt = DateTime.tryParse(alert['created_at'] ?? '');
              final now = DateTime.now();

              // Only notify for alerts created in the last 30 seconds (new alerts)
              if (createdAt != null && now.difference(createdAt).inSeconds < 30) {
                await _showAlertNotification(
                  notificationsPlugin,
                  alert['id'],
                  alert['message'] ?? 'Someone needs you to move your car!',
                );
              }
            }
          }
        }, onError: (error) {
          debugPrint('Background service: Alert stream error: $error');
        });
  }

  // Initial subscription if user ID exists
  if (userId != null && userId.isNotEmpty) {
    subscribeToAlerts(userId);
  }

  // Handle user updates from main app
  service.on('updateUser').listen((event) {
    if (event != null && event['userId'] != null) {
      userId = event['userId'];
      subscribeToAlerts(userId!);
    }
  });

  // Handle stop request
  service.on('stopService').listen((event) {
    alertSubscription?.cancel();
    service.stopSelf();
  });
}

/// Show alert notification with premium vibration pattern
Future<void> _showAlertNotification(
  FlutterLocalNotificationsPlugin plugin,
  String alertId,
  String message,
) async {
  // Premium rhythm vibration pattern: da-da-da-DAAAA (attention-grabbing)
  final vibrationPattern = Int64List.fromList([
    0,    // Start immediately
    200,  // Short buzz
    100,  // Pause
    200,  // Short buzz
    100,  // Pause
    200,  // Short buzz
    200,  // Longer pause
    600,  // Long buzz (attention!)
    300,  // Pause
    200,  // Short buzz
    100,  // Pause
    200,  // Short buzz
    100,  // Pause
    600,  // Long final buzz
  ]);

  final androidDetails = AndroidNotificationDetails(
    'yuh_blockin_alerts',
    'Yuh Blockin Alerts',
    channelDescription: 'Critical parking alert notifications',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: vibrationPattern,
    enableLights: true,
    ledColor: const Color(0xFF4CAF50),
    ledOnMs: 500,
    ledOffMs: 250,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    ticker: 'Someone needs you to move your car!',
    styleInformation: BigTextStyleInformation(
      message,
      contentTitle: 'Parking Alert!',
      summaryText: 'Yuh Blockin',
    ),
    actions: [
      const AndroidNotificationAction(
        'respond',
        'Respond',
        showsUserInterface: true,
        cancelNotification: false,
      ),
    ],
  );

  final details = NotificationDetails(android: androidDetails);

  await plugin.show(
    alertId.hashCode,
    'Parking Alert!',
    message,
    details,
    payload: alertId,
  );

  // Additional manual vibration for extra attention
  await _vibrateRhythm();
}

/// Premium rhythm vibration pattern
/// Pattern: quick-quick-quick-LONG, quick-quick-LONG
Future<void> _vibrateRhythm() async {
  try {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    final hasAmplitude = await Vibration.hasAmplitudeControl();

    if (hasAmplitude == true) {
      // With amplitude control - more impactful vibration
      await Vibration.vibrate(
        pattern: [
          0,    // Start
          150,  // Quick
          80,   // Pause
          150,  // Quick
          80,   // Pause
          150,  // Quick
          150,  // Pause
          500,  // LONG
          200,  // Pause
          150,  // Quick
          80,   // Pause
          150,  // Quick
          150,  // Pause
          500,  // LONG
        ],
        intensities: [
          0, 200, 0, 200, 0, 200, 0, 255, 0, 200, 0, 200, 0, 255,
        ],
      );
    } else {
      // Without amplitude control
      await Vibration.vibrate(
        pattern: [
          0, 150, 80, 150, 80, 150, 150, 500, 200, 150, 80, 150, 150, 500,
        ],
      );
    }

    // Second wave after a pause for extra urgency
    await Future.delayed(const Duration(milliseconds: 800));

    await Vibration.vibrate(
      pattern: [0, 300, 150, 300, 150, 600],
    );
  } catch (e) {
    debugPrint('Background vibration error: $e');
  }
}
