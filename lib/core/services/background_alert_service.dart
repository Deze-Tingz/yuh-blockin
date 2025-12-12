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
import '../../config/supabase_config.dart';

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

    // Configure notification channel for foreground service with custom sound
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Critical parking alert notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('alert_sound'),
      enableLights: true,
      ledColor: Color(0xFF4CAF50),
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
/// Note: iOS has strict background execution limits (~30 seconds)
/// For reliable background alerts on iOS, push notifications (FCM/APNs) are required
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // On iOS, we have limited background execution time
  // The main onStart handler will be called, but may be suspended by iOS
  // For reliable delivery when app is backgrounded on iOS, implement push notifications
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
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await notificationsPlugin.initialize(initSettings);

  // Get stored user ID
  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('user_id');

  StreamSubscription? alertSubscription;
  SupabaseClient? supabase;
  Timer? reconnectTimer;

  // Track shown alert IDs to prevent duplicate notifications
  final Set<String> shownAlertIds = {};

  // Initialize Supabase
  Future<SupabaseClient?> initializeSupabase() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      final client = Supabase.instance.client;
      if (kDebugMode) {
        debugPrint('Background service: Supabase initialized');
      }
      return client;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Background service: Supabase already initialized or error: $e');
      }
      try {
        return Supabase.instance.client;
      } catch (_) {
        if (kDebugMode) {
          debugPrint('Background service: Could not get Supabase client');
        }
        return null;
      }
    }
  }

  supabase = await initializeSupabase();

  // Sign in anonymously for authenticated role
  if (supabase != null && supabase.auth.currentUser == null) {
    try {
      await supabase.auth.signInAnonymously();
      if (kDebugMode) {
        debugPrint('Background service: Signed in anonymously');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Background service: Anonymous sign-in failed: $e');
      }
    }
  }

  /// Subscribe to alerts for user with auto-reconnect
  void subscribeToAlerts(String uid) {
    alertSubscription?.cancel();
    reconnectTimer?.cancel();

    if (supabase == null) {
      if (kDebugMode) {
        debugPrint('Background service: No Supabase client, cannot subscribe');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('Background service: Subscribing to alerts for user: $uid');
    }

    alertSubscription = supabase
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', uid)
        .listen((data) async {
          for (final alert in data) {
            final alertId = alert['id'] as String?;
            if (alertId == null) continue;

            // Skip if already shown
            if (shownAlertIds.contains(alertId)) continue;

            // Check if this is a new unread alert
            if (alert['read_at'] == null && alert['response'] == null) {
              final createdAt = DateTime.tryParse(alert['created_at'] ?? '');
              final now = DateTime.now();

              // Only notify for alerts created in the last 60 seconds (new alerts)
              // Increased from 30s to handle slight delays
              if (createdAt != null && now.difference(createdAt).inSeconds < 60) {
                shownAlertIds.add(alertId);

                // Limit cache size to prevent memory issues
                if (shownAlertIds.length > 100) {
                  shownAlertIds.remove(shownAlertIds.first);
                }

                // Get urgency level from alert data
                final urgencyLevel = alert['urgency_level'] ?? 'normal';
                await _showAlertNotification(
                  notificationsPlugin,
                  alertId,
                  alert['message'] ?? 'Please move your vehicle',
                  urgencyLevel: urgencyLevel,
                );
              }
            }
          }
        }, onError: (error) {
          if (kDebugMode) {
            debugPrint('Background service: Alert stream error: $error');
          }
          // Auto-reconnect after error
          reconnectTimer?.cancel();
          reconnectTimer = Timer(const Duration(seconds: 5), () {
            if (userId != null && userId!.isNotEmpty) {
              subscribeToAlerts(userId!);
            }
          });
        });
  }

  // Initial subscription if user ID exists
  if (userId != null && userId.isNotEmpty) {
    subscribeToAlerts(userId);
  }

  // Periodic keep-alive to ensure connection stays active
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    // Refresh user ID from prefs in case it changed
    final currentUserId = prefs.getString('user_id');
    if (currentUserId != null && currentUserId != userId) {
      userId = currentUserId;
      subscribeToAlerts(userId!);
    }
  });

  // Handle user updates from main app
  service.on('updateUser').listen((event) {
    if (event != null && event['userId'] != null) {
      userId = event['userId'];
      subscribeToAlerts(userId!);
    }
  });

  // Handle stop request
  service.on('stopService').listen((event) {
    reconnectTimer?.cancel();
    alertSubscription?.cancel();
    service.stopSelf();
  });
}

/// Show alert notification with premium vibration pattern
/// urgencyLevel: 'low', 'normal', 'high' - determines which sound to play
Future<void> _showAlertNotification(
  FlutterLocalNotificationsPlugin plugin,
  String alertId,
  String message, {
  String urgencyLevel = 'normal',
}) async {
  // Get the user's selected sound for this urgency level from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  String soundFileName;

  // Keys match SoundPreferencesService
  switch (urgencyLevel.toLowerCase()) {
    case 'low':
      final soundPath = prefs.getString('alert_sound_low') ?? 'sounds/low/low_alert_1.wav';
      soundFileName = soundPath.split('/').last.replaceAll('.wav', '');
      break;
    case 'high':
      final soundPath = prefs.getString('alert_sound_high') ?? 'sounds/high/high_alert_1.wav';
      soundFileName = soundPath.split('/').last.replaceAll('.wav', '');
      break;
    default: // normal
      final soundPath = prefs.getString('alert_sound_normal') ?? 'sounds/normal/normal_alert.wav';
      soundFileName = soundPath.split('/').last.replaceAll('.wav', '');
  }

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
    sound: RawResourceAndroidNotificationSound(soundFileName),
    enableVibration: true,
    vibrationPattern: vibrationPattern,
    enableLights: true,
    ledColor: const Color(0xFF4CAF50),
    ledOnMs: 500,
    ledOffMs: 250,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    ticker: 'New alert',
    styleInformation: BigTextStyleInformation(
      message,
      contentTitle: 'New Alert',
      summaryText: "Yuh Blockin'",
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
    'New Alert',
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
    if (kDebugMode) {
      debugPrint('Background vibration error: $e');
    }
  }
}
