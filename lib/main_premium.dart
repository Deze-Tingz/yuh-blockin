import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';

import 'core/theme/premium_theme.dart';
import 'core/services/plate_storage_service.dart';
import 'core/services/user_stats_service.dart';
import 'core/services/simple_alert_service.dart';
import 'core/services/unacknowledged_alert_service.dart';
import 'core/services/user_alias_service.dart';
import 'config/premium_config.dart';
import 'features/premium_alert/alert_workflow_screen.dart';
import 'features/premium_alert/alert_history_screen.dart';
import 'features/plate_registration/plate_registration_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/theme_settings/theme_settings_screen.dart';

/// Premium flagship-quality Yuh Blockin' app
/// Inspired by Uber, Airbnb, Apple Human Interface guidelines
/// Minimal, elegant, professional with subtle 2025 motion signature
void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const PremiumYuhBlockinApp());
}

/// Global theme notifier for app-wide theme changes
class ThemeNotifier extends ChangeNotifier {
  String _currentMode = PremiumTheme.lightMode;

  String get currentMode => _currentMode;

  void setTheme(String mode) {
    _currentMode = mode;
    PremiumTheme.setThemeMode(mode);
    notifyListeners();
  }

  ThemeData get currentTheme => PremiumTheme.currentTheme;
}

class PremiumYuhBlockinApp extends StatelessWidget {
  const PremiumYuhBlockinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, child) {
          return MaterialApp(
            title: PremiumConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: themeNotifier.currentTheme,
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

/// Determines the initial route based on user's onboarding status
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    print('🔍 AppInitializer: Checking onboarding status...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding =
          prefs.getBool('onboarding_completed') ?? false;
      final userId = prefs.getString('user_id');
      final hasUserId = userId != null;

      print(
          '🔍 AppInitializer: hasCompletedOnboarding = $hasCompletedOnboarding');
      print('🔍 AppInitializer: hasUserId = $hasUserId (userId = $userId)');

      if (!mounted) return;

      // Remove splash screen before navigation
      FlutterNativeSplash.remove();

      if (hasCompletedOnboarding && hasUserId) {
        print(
            '✅ AppInitializer: User has completed onboarding - going to home screen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PremiumHomeScreen(),
          ),
        );
      } else {
        print(
            '🔄 AppInitializer: First time user or incomplete setup - going to onboarding');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const OnboardingFlow(),
          ),
        );
      }
    } catch (e) {
      print('❌ AppInitializer: Error checking status: $e');
      // On error, default to onboarding
      if (mounted) {
        FlutterNativeSplash.remove();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const OnboardingFlow(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple loading screen while checking status
    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.accentColor),
        ),
      ),
    );
  }
}

class PremiumHomeScreen extends StatefulWidget {
  const PremiumHomeScreen({super.key});

  @override
  State<PremiumHomeScreen> createState() => _PremiumHomeScreenState();
}

class _PremiumHomeScreenState extends State<PremiumHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  // Entrance animations for premium feel
  late AnimationController _entranceController;
  late Animation<double> _buttonRiseAnimation;
  late Animation<double> _buttonFadeAnimation;
  late Animation<double> _iconsSlideAnimation;
  late Animation<double> _iconsFadeAnimation;
  bool _showTagline = false;

  final PlateStorageService _plateStorageService = PlateStorageService();
  final UserStatsService _statsService = UserStatsService();
  final SimpleAlertService _alertService = SimpleAlertService();
  final UnacknowledgedAlertService _unacknowledgedAlertService =
      UnacknowledgedAlertService();
  final UserAliasService _aliasService = UserAliasService();
  String? _primaryPlate;
  UserStats _userStats = UserStats(
    carsFreed: 0,
    situationsResolved: 0,
    alertsSent: 0,
    alertsReceived: 0,
  );

  // Alert notification system
  String? _currentUserId;
  StreamSubscription<Alert>? _alertStreamSubscription;
  StreamSubscription<List<Alert>>?
      _sentAlertsStreamSubscription; // For monitoring acknowledgments
  Alert? _currentIncomingAlert;
  String? _currentSenderAlias;
  String? _currentAlertEmoji; // Store emoji from alert message
  bool _showingAlertBanner = false;

  // Unacknowledged alerts tracking
  int _unacknowledgedAlertsCount = 0;

  // Track which alert IDs have been shown to prevent re-showing
  final Set<String> _shownAlertIds = {};

  // Track which alert IDs have been marked as acknowledged to prevent duplicate processing
  final Set<String> _acknowledgedAlertIds = {};

  // Audio player for alert sound
  final AudioPlayer _alertAudioPlayer = AudioPlayer();

  // Animation controller for shake effect
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer for app state changes
    WidgetsBinding.instance.addObserver(this);

    // Subtle breathing animation for hero button
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _breathingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    // Disabled continuous animation for better performance
    // _breathingController.repeat(reverse: true);

    // Initialize shake animation for alert banner
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    // Initialize entrance animations for premium page load effect
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Button rises up from below with bounce
    _buttonRiseAnimation = Tween<double>(
      begin: 20,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    ));

    // Button fades in
    _buttonFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    ));

    // Icons slide up with slight delay
    _iconsSlideAnimation = Tween<double>(
      begin: 15,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
    ));

    // Icons fade in with delay
    _iconsFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    // Start entrance animation
    _entranceController.forward();

    // Delayed tagline reveal
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showTagline = true);
    });

    // CRITICAL: Ensure user exists FIRST before any other operations
    _initializeApp();
  }

  /// Initialize app by ensuring user exists first, then loading other data
  Future<void> _initializeApp() async {
    print('🔍 _initializeApp() called');

    // Step 1: Ensure user exists in database (BLOCKING - wait for this to complete)
    print('🔍 About to call _ensureUserExists()...');
    await _ensureUserExists();
    print('🔍 _ensureUserExists() completed');

    // Step 2: Load other data after user is confirmed to exist
    _loadPrimaryPlate();
    _loadUserStats();
    _loadUnacknowledgedAlertsCount();

    // Step 3: Initialize alert system (user ID is now guaranteed to exist)
    _initializeAlertSystem();
  }

  // Load user's primary license plate
  Future<void> _loadPrimaryPlate() async {
    try {
      print('🔍 MainPremium: Loading primary plate...');
      final previousPlate = _primaryPlate;
      final primaryPlate = await _plateStorageService.getPrimaryPlate();

      print('🔍 MainPremium: Previous plate: $previousPlate');
      print('🔍 MainPremium: New plate: $primaryPlate');

      if (mounted) {
        setState(() {
          _primaryPlate = primaryPlate;
        });

        if (previousPlate != primaryPlate) {
          print(
              '✅ MainPremium: Primary plate changed from "$previousPlate" to "$primaryPlate" - UI updated');
        } else {
          print('ℹ️ MainPremium: Primary plate unchanged: "$primaryPlate"');
        }
      }
    } catch (e) {
      print('❌ MainPremium: Error loading primary plate: $e');
      // Handle error silently - primary plate is optional for this feature
    }
  }

  // Load user statistics
  Future<void> _loadUserStats() async {
    try {
      final stats = await _statsService.getStats();
      if (mounted) {
        setState(() {
          _userStats = stats;
        });
      }
    } catch (e) {
      // Handle error silently - stats are optional for display
    }
  }

  // Load unacknowledged alerts count
  Future<void> _loadUnacknowledgedAlertsCount() async {
    try {
      final count = await _unacknowledgedAlertService.getUnacknowledgedCount();
      if (mounted) {
        setState(() {
          _unacknowledgedAlertsCount = count;
        });
      }
    } catch (e) {
      // Handle error silently - count is optional for display
    }
  }

  /// Refresh all home screen data - call when returning from other screens
  Future<void> _refreshAllData() async {
    try {
      print('🔄 MainPremium: Starting complete data refresh...');

      // Refresh primary plate, stats, and unacknowledged alerts concurrently
      await Future.wait([
        _loadPrimaryPlate(),
        _loadUserStats(),
        _loadUnacknowledgedAlertsCount(),
      ]);

      print('✅ MainPremium: All data refreshed successfully');
    } catch (e) {
      print('❌ MainPremium: Error during data refresh: $e');
    }
  }

  /// App lifecycle method - refresh data when app becomes active
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      print('🔄 MainPremium: App resumed - refreshing all data...');
      _refreshAllData();
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Dispose animation controllers
    _breathingController.dispose();
    _shakeController.dispose();
    _entranceController.dispose();

    // Dispose audio player
    _alertAudioPlayer.dispose();

    // Cancel alert stream subscriptions
    _alertStreamSubscription?.cancel();
    _sentAlertsStreamSubscription?.cancel();

    super.dispose();
  }

  /// Ensure user exists in database before accessing any features
  Future<void> _ensureUserExists() async {
    print('🔍 _ensureUserExists() called');

    try {
      print('🔍 Initializing alert service...');
      await _alertService.initialize();
      print('🔍 Alert service initialized');

      // Get or create user ID
      print('🔍 Getting SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      print('🔍 Existing userId from prefs: $userId');

      if (userId == null) {
        print('🔍 No existing user, creating new user...');
        userId = await _alertService.getOrCreateUser();
        print('🔍 User creation returned: $userId');
        await prefs.setString('user_id', userId);
        print('🆕 Created new user on app startup: $userId');
      } else {
        print('👤 User already exists: $userId');
      }

      setState(() {
        _currentUserId = userId;
      });
      print('🔍 Set _currentUserId to: $_currentUserId');
    } catch (e) {
      print('❌ Failed to ensure user exists: $e');
      print('❌ Error type: ${e.runtimeType}');
    }
  }

  /// Initialize alert service and real-time alert listening
  Future<void> _initializeAlertSystem() async {
    try {
      // User creation is now handled by _ensureUserExists(), so we can use _currentUserId directly
      if (_currentUserId == null) {
        print('❌ Alert system initialization failed: No user ID available');
        return;
      }

      // Start listening for incoming alerts
      _startListeningForAlerts();

      // Start monitoring sent alerts for acknowledgments
      _startMonitoringSentAlerts();

      print('📱 Alert system initialized for user: $_currentUserId');
    } catch (e) {
      print('❌ Failed to initialize alert system: $e');
    }
  }

  /// Start listening for real-time incoming alerts
  void _startListeningForAlerts() {
    if (_currentUserId == null) return;

    try {
      _alertStreamSubscription =
          _alertService.getAlertsStream(_currentUserId!).listen(
        (alert) {
          print('🔔 Received incoming alert: ${alert.id}');

          // Only show alerts that:
          // 1. Haven't been shown before
          // 2. Haven't been read yet
          // 3. Haven't been responded to
          if (!_shownAlertIds.contains(alert.id) &&
              alert.readAt == null &&
              alert.response == null) {
            _handleIncomingAlert(alert);
            _shownAlertIds.add(alert.id); // Mark as shown
          } else {
            print('ℹ️ Alert ${alert.id} already shown, read, or responded to - skipping');
          }
        },
        onError: (error) {
          print('❌ Alert stream error: $error');
        },
      );
    } catch (e) {
      print('❌ Failed to start alert listening: $e');
    }
  }

  /// Start monitoring sent alerts for acknowledgments
  void _startMonitoringSentAlerts() {
    if (_currentUserId == null) return;

    try {
      _sentAlertsStreamSubscription =
          _alertService.getSentAlertsStream(_currentUserId!).listen(
        (alerts) {
          _processSentAlertsForAcknowledgments(alerts);
        },
        onError: (error) {
          print('❌ Sent alerts stream error: $error');
        },
      );
    } catch (e) {
      print('❌ Failed to start sent alerts monitoring: $e');
    }
  }

  /// Process sent alerts to mark acknowledged ones
  void _processSentAlertsForAcknowledgments(List<Alert> alerts) {
    bool needsRefresh = false;

    for (final alert in alerts) {
      // If alert has a response and hasn't been processed yet, mark it as acknowledged
      if (alert.response != null &&
          alert.responseAt != null &&
          !_acknowledgedAlertIds.contains(alert.id)) {

        // Mark this alert as processed to prevent duplicate marking
        _acknowledgedAlertIds.add(alert.id);
        needsRefresh = true;

        _unacknowledgedAlertService.markAlertAcknowledged(alert.id).then((_) {
          print('✅ Marked sent alert ${alert.id} as acknowledged');
        }).catchError((error) {
          print('⚠️ Failed to mark alert ${alert.id} as acknowledged: $error');
          // Remove from set if marking failed, so we can retry
          _acknowledgedAlertIds.remove(alert.id);
        });
      }
    }

    // Only refresh count if we marked any new alerts
    if (needsRefresh) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadUnacknowledgedAlertsCount();
        }
      });
    }
  }

  /// Sync unacknowledged alerts with database (call when viewing alert history)
  Future<void> _syncUnacknowledgedAlerts() async {
    if (_currentUserId == null) return;

    try {
      print('🔄 Syncing unacknowledged alerts with database...');

      // Get all sent alerts from database
      final sentAlerts = await _alertService.getSentAlerts(_currentUserId!);

      // Process them to mark any with responses as acknowledged
      for (final alert in sentAlerts) {
        if (alert.response != null &&
            alert.responseAt != null &&
            !_acknowledgedAlertIds.contains(alert.id)) {

          _acknowledgedAlertIds.add(alert.id);

          await _unacknowledgedAlertService.markAlertAcknowledged(alert.id);
          print('✅ Synced and marked alert ${alert.id} as acknowledged');
        }
      }

      print('✅ Sync complete');
    } catch (e) {
      print('❌ Error syncing unacknowledged alerts: $e');
    }
  }

  /// Handle incoming alert with premium notification
  void _handleIncomingAlert(Alert alert) async {
    if (!mounted) return;

    // Get sender's alias
    String senderAlias;
    try {
      senderAlias = await _aliasService.getAliasForUser(alert.senderId);
    } catch (e) {
      print('❌ Failed to get sender alias: $e');
      senderAlias = 'Anonymous';
    }

    // Extract emoji from alert message (if present)
    String? emoji;
    if (alert.message != null && alert.message!.isNotEmpty) {
      // Extract first emoji character from message
      final emojiRegex = RegExp(
          r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
          unicode: true);
      final match = emojiRegex.firstMatch(alert.message!);
      if (match != null) {
        emoji = match.group(0);
      }
    }

    setState(() {
      _currentIncomingAlert = alert;
      _currentSenderAlias = senderAlias;
      _currentAlertEmoji = emoji;
      _showingAlertBanner = true;
    });

    // Track alert received
    _statsService.incrementAlertsReceived().then((_) {
      _loadUserStats(); // Refresh stats display
    });

    // Sound effects disabled - no sound files in project
    // Using haptic feedback only for user feedback

    // Premium haptic feedback - phone vibration
    HapticFeedback.heavyImpact();
    // Additional vibration patterns for emphasis
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();

    // Start shake animation for the banner
    _shakeController.repeat(reverse: true);

    // Stop shaking after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _shakeController.isAnimating) {
        _shakeController.stop();
        _shakeController.reset();
      }
    });

    // Alert will stay active until user makes a decision
  }

  /// Dismiss current alert without responding
  Future<void> _dismissCurrentAlert() async {
    if (_currentIncomingAlert == null) return;

    print('🔕 Dismissing alert: ${_currentIncomingAlert!.id}');

    try {
      // Mark alert as read in the database
      await _alertService.markAlertRead(_currentIncomingAlert!.id);

      setState(() {
        _showingAlertBanner = false;
        _currentIncomingAlert = null;
        _currentSenderAlias = null;
        _currentAlertEmoji = null;
      });

      // Stop shake animation
      if (_shakeController.isAnimating) {
        _shakeController.stop();
        _shakeController.reset();
      }

      HapticFeedback.lightImpact();
      print('✅ Alert dismissed and marked as read');
    } catch (e) {
      print('❌ Failed to dismiss alert: $e');
    }
  }

  /// Respond to alert with acknowledgment
  Future<void> _respondToAlert(String response) async {
    if (_currentIncomingAlert == null) return;

    print(
        '🔄 Attempting to respond to alert: ${_currentIncomingAlert!.id} with response: $response');

    try {
      // Send response via alert service (this will also mark as read)
      final success = await _alertService.sendResponse(
        alertId: _currentIncomingAlert!.id,
        response: response,
      );

      if (success) {
        // Update user stats - increment cars freed (user moved their car)
        await _statsService.incrementCarsFreed();

        // Get updated stats for display
        final updatedStats = await _statsService.getStats();

        setState(() {
          _userStats = updatedStats;
          _showingAlertBanner = false;
          _currentIncomingAlert = null;
          _currentSenderAlias = null;
          _currentAlertEmoji = null;
        });

        // Stop shake animation
        if (_shakeController.isAnimating) {
          _shakeController.stop();
          _shakeController.reset();
        }

        print('✅ Responded to alert: $response');
        print(
            '📡 Response should now appear on sender\'s device via real-time stream');

        // Show premium confirmation snackbar with enhanced animations
        if (mounted) {
          final responseText = _getResponseDisplayText(response);
          _showPremiumSnackBar(
            message: 'Response sent: $responseText',
            isSuccess: true,
            duration: const Duration(seconds: 1),
            icon: Icons.check_circle_outline,
          );
        }
      } else {
        throw Exception('Failed to send response');
      }
    } catch (e) {
      print('❌ Failed to respond to alert: $e');

      // Show premium error snackbar with enhanced animations
      if (mounted) {
        _showPremiumSnackBar(
          message: 'Failed to send response. Please try again.',
          isSuccess: false,
          duration: const Duration(seconds: 1),
          icon: Icons.error_outline,
        );
      }
    }
  }

  /// Get display text for response
  String _getResponseDisplayText(String response) {
    switch (response) {
      case 'moving_now':
        return 'Moving now';
      case '5_minutes':
        return 'Give me 5 minutes';
      case 'cant_move':
        return 'Can\'t move right now';
      case 'wrong_car':
        return 'Wrong car';
      default:
        return response;
    }
  }

  /// Show premium animated SnackBar with enhanced visuals and animations
  void _showPremiumSnackBar({
    required String message,
    bool isSuccess = true,
    Duration? duration,
    IconData? icon,
  }) {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSuccess
                  ? [
                      PremiumTheme.accentColor,
                      PremiumTheme.accentColor.withOpacity(0.9),
                    ]
                  : [
                      Colors.red.shade600,
                      Colors.red.shade700,
                    ],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
            boxShadow: [
              BoxShadow(
                color: isSuccess
                    ? PremiumTheme.accentColor.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 16 : 14,
            horizontal: isTablet ? 20 : 16,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: isTablet ? 18 : 16,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 10),
              ],
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: isTablet ? 15 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: EdgeInsets.only(
          bottom: isTablet ? 32 : 24,
          left: isTablet ? 32 : 20,
          right: isTablet ? 32 : 20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
        ),
        duration: duration ?? const Duration(seconds: 1),
        dismissDirection: DismissDirection.none,
        action: SnackBarAction(
          label: '✕',
          textColor: Colors.white.withOpacity(0.8),
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show premium animated dialog with enhanced slide and fade transitions
  Future<T?> _showPremiumDialog<T>({
    required Widget child,
    bool barrierDismissible = true,
    Color? barrierColor,
    Duration? transitionDuration,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor ?? Colors.black.withOpacity(0.5),
      transitionDuration:
          transitionDuration ?? const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutCubic;

        // Slide up from bottom with fade
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        // Scale animation for subtle zoom effect
        final scaleAnimation = Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        // Fade animation
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldExit = await _showPremiumDialog<bool>(
            child: AlertDialog(
              backgroundColor: PremiumTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Exit Yuh Blockin?',
                style: TextStyle(
                  color: PremiumTheme.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Are you sure you want to exit the app?',
                style: TextStyle(
                    color: PremiumTheme.primaryTextColor.withOpacity(0.8)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel',
                      style: TextStyle(color: PremiumTheme.primaryTextColor)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Exit'),
                ),
              ],
            ),
          );

          if (shouldExit ?? false) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: PremiumTheme.backgroundColor,
        body: Stack(
          children: [
            // Premium background gradient layer
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF8FBFF), // Very light blue tint at top
                    PremiumTheme.backgroundColor,
                    PremiumTheme.backgroundColor,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),

            // Ghosted car icon for brand reinforcement
            Positioned(
              right: -40,
              bottom: 100,
              child: Opacity(
                opacity: 0.02, // Very subtle - 2% opacity
                child: Icon(
                  Icons.directions_car,
                  size: 200,
                  color: PremiumTheme.accentColor,
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Check if we need to use scroll view on smaller screens
                  // Higher threshold to prevent overflow on more devices
                  final useScrollView = constraints.maxHeight < 800;

                  final content = Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 80.0 : 32.0,
                      vertical: isTablet ? 60.0 : (useScrollView ? 16.0 : 40.0),
                    ),
                    child: useScrollView
                        ? _buildScrollableContent(theme, isTablet)
                        : _buildStaticContent(theme, isTablet),
                  );

                  return useScrollView
                      ? SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: content,
                        )
                      : content;
                },
              ),
            ),

            // Premium incoming alert notification banner
            if (_showingAlertBanner && _currentIncomingAlert != null)
              _buildIncomingAlertBanner(isTablet),
          ],
        ), // closes Stack
      ), // closes Scaffold
    ); // closes PopScope
  }

  Widget _buildAppHeader(ThemeData theme, bool isTablet) {
    // Get the ThemeNotifier to pass to navigated screens
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(top: isTablet ? 16 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo on the left
          Image.asset(
            'assets/images/logo_transparent.png',
            height: isTablet ? 64 : 52,
            fit: BoxFit.contain,
          ),
          // Menu button on the right
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PremiumTheme.surfaceColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: PremiumTheme.accentColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.menu_rounded,
                color: PremiumTheme.accentColor,
                size: isTablet ? 24 : 22,
              ),
            ),
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: PremiumTheme.surfaceColor,
            elevation: 8,
            onSelected: (value) async {
              HapticFeedback.lightImpact();
              if (value == 'themes') {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        ChangeNotifierProvider.value(
                      value: themeNotifier,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(-1.0, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: PremiumTheme.standardCurve,
                        )),
                        child: const ThemeSettingsScreen(),
                      ),
                    ),
                    transitionDuration: PremiumTheme.mediumDuration,
                  ),
                );
              } else if (value == 'vehicles') {
                await Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: PremiumTheme.standardCurve,
                      )),
                      child: const PlateRegistrationScreen(),
                    ),
                    transitionDuration: PremiumTheme.mediumDuration,
                  ),
                );
                await _refreshAllData();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'themes',
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      color: PremiumTheme.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Themes',
                      style: TextStyle(
                        color: PremiumTheme.primaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'vehicles',
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      color: PremiumTheme.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'My Vehicles',
                      style: TextStyle(
                        color: PremiumTheme.primaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroButton(ThemeData theme, bool isTablet) {
    final buttonSize = isTablet ? 280.0 : 240.0;

    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonRiseAnimation.value),
          child: Opacity(
            opacity: _buttonFadeAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          HapticFeedback.mediumImpact();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _handleAlertTap();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Premium radial gradient for depth - darken when pressed
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3), // Offset for 3D depth
                radius: 1.2,
                colors: _isPressed
                    ? [
                        const Color(0xFF1565C0), // Darker when pressed
                        const Color(0xFF1565C0),
                        const Color(0xFF0D47A1),
                      ]
                    : [
                        const Color(0xFF1A73E8), // Bright blue highlight
                        PremiumTheme.accentColor, // Standard accent
                        const Color(0xFF1662CE), // Deeper blue
                      ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                // Single optimized shadow for performance
                BoxShadow(
                  color: PremiumTheme.accentColor.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Button content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Megaphone icon - bold, action-oriented
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        transform: Matrix4.identity()
                          ..translate(0.0, _isPressed ? 4.0 : 0.0),
                        child: Icon(
                          Icons.campaign_rounded,
                          size: isTablet ? 52 : 44,
                          color: _isPressed ? Colors.white.withOpacity(0.9) : Colors.white,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Button text
                      Text(
                        'Send Alert',
                        style: TextStyle(
                          fontSize: isTablet ? 20 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return const SizedBox.shrink();
  }

  Widget _buildBranding() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated tagline
        AnimatedOpacity(
          opacity: _showTagline ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Move with respect.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: PremiumTheme.tertiaryTextColor.withOpacity(0.7),
                letterSpacing: 0.8,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        // Copyright - more subtle
        Text(
          'DezeTingz © 2026',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w300,
            color: PremiumTheme.tertiaryTextColor.withOpacity(0.5),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  /// Helper widget for labeled icons
  Widget _buildLabeledIcon({
    required Widget icon,
    required String label,
    required bool isTablet,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: PremiumTheme.secondaryTextColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  /// Floating glass bottom bar with premium styling
  Widget _buildFloatingBottomBar(bool isTablet) {
    // Get the ThemeNotifier to pass to navigated screens
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 16),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 12,
            vertical: isTablet ? 16 : 12,
          ),
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: PremiumTheme.accentColor.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: PremiumTheme.accentColor.withOpacity(0.05),
                blurRadius: 40,
                offset: const Offset(0, 4),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _buildBottomBarButton(
                  icon: Icons.palette_outlined,
                  label: 'Themes',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ChangeNotifierProvider.value(
                          value: themeNotifier,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(-1.0, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: PremiumTheme.standardCurve,
                            )),
                            child: const ThemeSettingsScreen(),
                          ),
                        ),
                        transitionDuration: PremiumTheme.mediumDuration,
                      ),
                    );
                  },
                  isTablet: isTablet,
                ),
              ),
              Container(
                height: 24,
                width: 1,
                color: PremiumTheme.dividerColor,
              ),
              Flexible(
                child: _buildBottomBarButton(
                  icon: Icons.directions_car_outlined,
                  label: 'Vehicles',
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: PremiumTheme.standardCurve,
                          )),
                          child: const PlateRegistrationScreen(),
                        ),
                        transitionDuration: PremiumTheme.mediumDuration,
                      ),
                    );
                    await _refreshAllData();
                  },
                  isTablet: isTablet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom bar button helper
  Widget _buildBottomBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 10,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: PremiumTheme.accentColor,
              size: isTablet ? 22 : 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 15 : 13,
                fontWeight: FontWeight.w500,
                color: PremiumTheme.accentColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVehicleDisplay(bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isTablet ? 16.0 : 8.0,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 320 : 280,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumTheme.surfaceColor,
              PremiumTheme.surfaceColor.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PremiumTheme.accentColor.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: PremiumTheme.accentColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PremiumTheme.accentColor.withOpacity(0.1),
                    PremiumTheme.accentColor.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car_rounded,
                color: PremiumTheme.accentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Vehicle',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PremiumTheme.secondaryTextColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _primaryPlate!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.primaryTextColor,
                    letterSpacing: 1.0,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAlertTap() {
    // Check if user has a primary plate registered
    if (_primaryPlate == null || _primaryPlate!.isEmpty) {
      HapticFeedback.mediumImpact();
      _showPlateRequiredDialog();
      return;
    }

    // Launch premium alert workflow
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: PremiumTheme.standardCurve,
          )),
          child: const AlertWorkflowScreen(),
        ),
        transitionDuration: PremiumTheme.mediumDuration,
      ),
    );
  }

  Widget _buildSettingsRow() {
    // Get the ThemeNotifier to pass to navigated screens
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Theme Settings Button
        _buildActionButton(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ChangeNotifierProvider.value(
                  value: themeNotifier,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: PremiumTheme.standardCurve,
                    )),
                    child: const ThemeSettingsScreen(),
                  ),
                ),
                transitionDuration: PremiumTheme.mediumDuration,
              ),
            );
          },
          icon: Icons.palette_outlined,
          label: 'Themes',
        ),

        const SizedBox(width: 16),

        // Plate Management Button
        _buildActionButton(
          onTap: () async {
            HapticFeedback.lightImpact();
            print('🔄 MainPremium: Navigating to vehicle management...');

            await Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: PremiumTheme.standardCurve,
                  )),
                  child: const PlateRegistrationScreen(),
                ),
                transitionDuration: PremiumTheme.mediumDuration,
              ),
            );

            // CRITICAL: Refresh home screen when returning from vehicle management
            print(
                '🔄 MainPremium: Returned from vehicle management - refreshing all data...');
            await _refreshAllData();
            print('✅ MainPremium: Complete data refresh completed');
          },
          icon: Icons.directions_car_outlined,
          label: 'My Vehicles',
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: PremiumTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: PremiumTheme.accentColor.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: PremiumTheme.accentColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PremiumTheme.accentColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCounters(bool isTablet) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: isTablet ? 280 : 240,
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16.0 : 12.0,
        vertical: isTablet ? 12.0 : 10.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PremiumTheme.surfaceColor.withOpacity(0.6),
            PremiumTheme.surfaceColor.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PremiumTheme.accentColor.withOpacity(0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.accentColor.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Times I moved my car when alerted
          _buildCompactStatCounterWithEmoji(
            count: _userStats.carsFreed,
            label: 'I Moved',
            emoji: '🚗',
            color: PremiumTheme.accentColor,
            isTablet: isTablet,
          ),

          // Subtle divider
          Container(
            width: 0.5,
            height: isTablet ? 24 : 20,
            color: PremiumTheme.accentColor.withOpacity(0.1),
          ),

          // Times others moved for me when I sent alerts
          _buildCompactStatCounter(
            count: _userStats.situationsResolved,
            label: 'Others Moved',
            icon: Icons.thumb_up_outlined,
            color: Colors.green.shade600,
            isTablet: isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTracking(bool isTablet) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: isTablet ? 320 : 280,
      ),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20.0 : 16.0,
        vertical: isTablet ? 16.0 : 14.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade50.withOpacity(0.3),
            Colors.purple.shade50.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.purple.withOpacity(0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.withOpacity(0.15),
                      Colors.purple.withOpacity(0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: Colors.purple.shade600,
                  size: isTablet ? 14 : 12,
                ),
              ),
              SizedBox(width: isTablet ? 8 : 6),
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: isTablet ? 13 : 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),

          SizedBox(height: isTablet ? 14 : 12),

          // Notification stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Alerts sent
              _buildNotificationStat(
                count: _userStats.alertsSent,
                label: 'Sent',
                icon: Icons.send_outlined,
                color: Colors.blue.shade600,
                isTablet: isTablet,
              ),

              // Subtle divider
              Container(
                width: 0.5,
                height: isTablet ? 20 : 16,
                color: Colors.purple.withOpacity(0.15),
              ),

              // Alerts received
              _buildNotificationStat(
                count: _userStats.alertsReceived,
                label: 'Received',
                icon: Icons.inbox_outlined,
                color: Colors.orange.shade600,
                isTablet: isTablet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCounter({
    required int count,
    required String label,
    required IconData icon,
    required Color color,
    required bool isTablet,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small icon
        Icon(
          icon,
          color: color.withOpacity(0.7),
          size: isTablet ? 16 : 14,
        ),

        SizedBox(width: isTablet ? 6 : 4),

        // Count and label
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w700,
                color: PremiumTheme.primaryTextColor,
                letterSpacing: 0.3,
                height: 1.0,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 10 : 9,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.8),
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactStatCounterWithEmoji({
    required int count,
    required String label,
    required String emoji,
    required Color color,
    required bool isTablet,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Premium emoji
        Text(
          emoji,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
          ),
        ),

        SizedBox(width: isTablet ? 6 : 4),

        // Count and label
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w700,
                color: PremiumTheme.primaryTextColor,
                letterSpacing: 0.3,
                height: 1.0,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 10 : 9,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.8),
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationStat({
    required int count,
    required String label,
    required IconData icon,
    required Color color,
    required bool isTablet,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Notification icon
        Container(
          padding: EdgeInsets.all(isTablet ? 4 : 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: isTablet ? 12 : 10,
          ),
        ),

        SizedBox(width: isTablet ? 6 : 5),

        // Count and label
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: PremiumTheme.primaryTextColor,
                letterSpacing: 0.3,
                height: 1.0,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 9 : 8,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.8),
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Compact stats icon for header - premium style
  Widget _buildCompactStatsIcon(bool isTablet) {
    final totalImpact = _userStats.carsFreed + _userStats.situationsResolved;
    final hasStats = totalImpact > 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showStatsDialog();
      },
      child: Stack(
        clipBehavior: Clip.none, // Allow badge to overflow
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: hasStats
                    ? [
                        Colors.green.shade500.withOpacity(0.15),
                        Colors.green.shade600.withOpacity(0.08),
                      ]
                    : [
                        PremiumTheme.surfaceColor.withOpacity(0.6),
                        PremiumTheme.surfaceColor.withOpacity(0.4),
                      ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: hasStats
                    ? Colors.green.withOpacity(0.2)
                    : PremiumTheme.accentColor.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasStats
                      ? Colors.green.withOpacity(0.1)
                      : PremiumTheme.accentColor.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              Icons.trending_up,
              size: isTablet ? 20 : 18,
              color: hasStats
                  ? Colors.green.shade700
                  : PremiumTheme.tertiaryTextColor,
            ),
          ),

          // Badge positioned cleanly outside the icon at top-right corner
          if (hasStats)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: isTablet ? 22 : 20,
                  minHeight: isTablet ? 22 : 20,
                ),
                padding: EdgeInsets.all(isTablet ? 5 : 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PremiumTheme.accentColor,
                      PremiumTheme.accentColor.withOpacity(0.9),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PremiumTheme.backgroundColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PremiumTheme.accentColor.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    totalImpact > 99 ? '99+' : '$totalImpact',
                    style: TextStyle(
                      fontSize: isTablet ? 11 : 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Show stats in a premium dialog
  void _showStatsDialog() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;
    final isSmallScreen = screenSize.height < 600;

    _showPremiumDialog(
      barrierColor: Colors.black.withOpacity(0.4),
      child: Dialog(
        backgroundColor: PremiumTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 420 : 340,
            maxHeight: screenSize.height * 0.8,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.withOpacity(0.15),
                            Colors.green.withOpacity(0.08),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: Colors.green.shade600,
                        size: isSmallScreen ? 20 : 24,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Flexible(
                      child: Text(
                        'Your Impact',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: PremiumTheme.primaryTextColor,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isSmallScreen ? 16 : 20),

                // Stats in a premium container
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade50.withOpacity(0.3),
                        Colors.green.shade50.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // I Moved stats
                        Expanded(
                          child: _buildDialogStatCounter(
                            count: _userStats.carsFreed,
                            label: 'I Moved',
                            emoji: '🚗',
                            color: PremiumTheme.accentColor,
                            isCompact: isSmallScreen,
                          ),
                        ),

                        // Divider
                        Container(
                          width: 1,
                          height: isSmallScreen ? 45 : 50,
                          color: Colors.green.withOpacity(0.15),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),

                        // Others Moved stats
                        Expanded(
                          child: _buildDialogStatCounter(
                            count: _userStats.situationsResolved,
                            label: 'Others Moved',
                            icon: Icons.thumb_up_outlined,
                            color: Colors.green.shade600,
                            isCompact: isSmallScreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 12 : 16),

                // Impact description
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    color: PremiumTheme.accentColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: PremiumTheme.accentColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _userStats.impactDescription,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w500,
                      color: PremiumTheme.primaryTextColor,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                SizedBox(height: isSmallScreen ? 12 : 16),

                // Detailed insights section
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade50.withOpacity(0.3),
                        Colors.blue.shade50.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: isSmallScreen ? 14 : 16,
                            color: Colors.blue.shade600,
                          ),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text(
                            'Your Impact Details',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 10),
                      _buildInsightRow(
                        icon: Icons.check_circle_outline,
                        text: '${_userStats.carsFreed} times you helped others by moving',
                        color: PremiumTheme.accentColor,
                        isSmallScreen: isSmallScreen,
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      _buildInsightRow(
                        icon: Icons.people_outline,
                        text: '${_userStats.situationsResolved} times others moved for you',
                        color: Colors.green.shade600,
                        isSmallScreen: isSmallScreen,
                      ),
                      if (_userStats.alertsSent > 0) ...[
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        _buildInsightRow(
                          icon: Icons.send_outlined,
                          text: '${_userStats.alertsSent} respectful alerts sent',
                          color: Colors.orange.shade600,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                      if (_userStats.alertsReceived > 0) ...[
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        _buildInsightRow(
                          icon: Icons.notifications_outlined,
                          text: '${_userStats.alertsReceived} alerts received',
                          color: Colors.purple.shade600,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: isSmallScreen ? 16 : 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 20,
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show dialog requiring user to register a plate first
  void _showPlateRequiredDialog() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;
    final isSmallScreen = screenSize.height < 600;

    _showPremiumDialog(
      barrierColor: Colors.black.withOpacity(0.4),
      child: Dialog(
        backgroundColor: PremiumTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 380 : 320,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.withOpacity(0.15),
                      Colors.orange.withOpacity(0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_outlined,
                  color: Colors.orange.shade600,
                  size: isSmallScreen ? 32 : 40,
                ),
              ),

              SizedBox(height: isSmallScreen ? 16 : 20),

              // Title
              Text(
                'Register Your Vehicle',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isSmallScreen ? 12 : 16),

              // Message
              Text(
                'Please add at least one license plate to your profile before sending alerts. This helps others know who\'s alerting them.',
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.secondaryTextColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isSmallScreen ? 20 : 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 20,
                          vertical: isSmallScreen ? 10 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: PremiumTheme.dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 15,
                          fontWeight: FontWeight.w500,
                          color: PremiumTheme.secondaryTextColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Navigate to plate registration
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: PremiumTheme.standardCurve,
                              )),
                              child: const PlateRegistrationScreen(),
                            ),
                            transitionDuration: PremiumTheme.mediumDuration,
                          ),
                        ).then((_) async {
                          // Refresh data after returning
                          await _refreshAllData();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PremiumTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 20,
                          vertical: isSmallScreen ? 10 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Add Vehicle',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Stats counter for dialog display (supports both emoji and icon)
  Widget _buildDialogStatCounter({
    required int count,
    required String label,
    String? emoji,
    IconData? icon,
    required Color color,
    bool isCompact = false,
  }) {
    return Column(
      children: [
        if (emoji != null) ...[
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              emoji,
              style: TextStyle(fontSize: isCompact ? 20 : 24),
            ),
          ),
        ] else if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: isCompact ? 20 : 24,
            ),
          ),
        ],
        SizedBox(height: isCompact ? 8 : 12),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: isCompact ? 22 : 28,
            fontWeight: FontWeight.w700,
            color: PremiumTheme.primaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 11 : 13,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.8),
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Helper to build insight row with icon and text
  Widget _buildInsightRow({
    required IconData icon,
    required String text,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 14 : 16,
          color: color.withOpacity(0.8),
        ),
        SizedBox(width: isSmallScreen ? 6 : 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w500,
              color: PremiumTheme.secondaryTextColor,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  /// Compact notification icon for header - premium style
  Widget _buildCompactNotificationIcon(bool isTablet) {
    // Only show badge for actionable items: unacknowledged sent alerts
    final hasUnacknowledgedAlerts = _unacknowledgedAlertsCount > 0;

    // Badge should only show when there are unacknowledged alerts
    final showingUrgent = hasUnacknowledgedAlerts;
    final badgeCount = _unacknowledgedAlertsCount;
    final shouldShowBadge = hasUnacknowledgedAlerts;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AlertHistoryScreen(
              userId: _currentUserId!,
            ),
          ),
        );
        // Sync and refresh unacknowledged alerts after viewing alert history
        if (mounted) {
          // Force sync by fetching all sent alerts and marking acknowledged ones
          await _syncUnacknowledgedAlerts();
          await _loadUnacknowledgedAlertsCount();
        }
      },
      child: Stack(
        clipBehavior: Clip.none, // Allow badge to overflow
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: showingUrgent
                    ? [
                        Colors.orange.shade500.withOpacity(0.2),
                        Colors.red.shade500.withOpacity(0.1),
                      ]
                    : [
                        PremiumTheme.surfaceColor.withOpacity(0.6),
                        PremiumTheme.surfaceColor.withOpacity(0.4),
                      ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: showingUrgent
                    ? Colors.orange.withOpacity(0.3)
                    : PremiumTheme.accentColor.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: showingUrgent
                      ? Colors.orange.withOpacity(0.15)
                      : PremiumTheme.accentColor.withOpacity(0.05),
                  blurRadius: showingUrgent ? 10 : 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: isTablet ? 20 : 18,
              color: showingUrgent
                  ? Colors.orange.shade700
                  : PremiumTheme.tertiaryTextColor,
            ),
          ),

          // Badge positioned cleanly outside the icon at top-right corner
          if (shouldShowBadge)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: isTablet ? 22 : 20,
                  minHeight: isTablet ? 22 : 20,
                ),
                padding: EdgeInsets.all(isTablet ? 5 : 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PremiumTheme.accentColor,
                      PremiumTheme.accentColor.withOpacity(0.9),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PremiumTheme.backgroundColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PremiumTheme.accentColor.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: TextStyle(
                      fontSize: isTablet ? 11 : 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Show notification statistics in a premium dialog
  void _showNotificationStats() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;
    final isSmallScreen = screenSize.height < 600;

    _showPremiumDialog(
      barrierColor: Colors.black.withOpacity(0.4),
      child: Dialog(
        backgroundColor: PremiumTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 400 : 320,
            maxHeight: screenSize.height * 0.7,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.purple.withOpacity(0.15),
                            Colors.purple.withOpacity(0.08),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: Colors.purple.shade600,
                        size: isSmallScreen ? 20 : 24,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Flexible(
                      child: Text(
                        'Notification Activity',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: PremiumTheme.primaryTextColor,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isSmallScreen ? 16 : 20),

                // Stats in a premium container
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.purple.shade50.withOpacity(0.3),
                        Colors.purple.shade50.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.purple.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Alerts sent
                        Expanded(
                          child: _buildDialogNotificationStat(
                            count: _userStats.alertsSent,
                            label: 'Sent',
                            icon: Icons.send_outlined,
                            color: Colors.blue.shade600,
                            isCompact: isSmallScreen,
                          ),
                        ),

                        // Divider
                        Container(
                          width: 1,
                          height: isSmallScreen ? 35 : 40,
                          color: Colors.purple.withOpacity(0.15),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),

                        // Alerts received
                        Expanded(
                          child: _buildDialogNotificationStat(
                            count: _userStats.alertsReceived,
                            label: 'Received',
                            icon: Icons.inbox_outlined,
                            color: Colors.orange.shade600,
                            isCompact: isSmallScreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 16 : 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 20,
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Notification stat for dialog display
  Widget _buildDialogNotificationStat({
    required int count,
    required String label,
    required IconData icon,
    required Color color,
    bool isCompact = false,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 6 : 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: isCompact ? 16 : 20,
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: isCompact ? 20 : 24,
            fontWeight: FontWeight.w700,
            color: PremiumTheme.primaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 10 : 12,
            fontWeight: FontWeight.w500,
            color: color.withOpacity(0.8),
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showMinimalDialog() {
    _showPremiumDialog(
      barrierColor: Colors.black.withOpacity(0.3),
      child: AlertDialog(
        backgroundColor: PremiumTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Alert Workflow',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: PremiumTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This will launch the premium alert experience with Manim comedic animations.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: PremiumTheme.secondaryTextColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: PremiumTheme.accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Got it',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build content for larger screens (with Expanded widgets)
  Widget _buildStaticContent(ThemeData theme, bool isTablet) {
    return Column(
      children: [
        // Subtle app identity
        _buildAppHeader(theme, isTablet),

        // Flexible space above - more space to push content down
        const Expanded(flex: 3, child: SizedBox()),

        // Hero button - the centerpiece
        _buildHeroButton(theme, isTablet),

        // Stats and notification icons with labels - animated entrance
        SizedBox(height: isTablet ? 28 : 24),
        AnimatedBuilder(
          animation: _entranceController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _iconsSlideAnimation.value),
              child: Opacity(
                opacity: _iconsFadeAnimation.value,
                child: child,
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLabeledIcon(
                icon: _buildCompactStatsIcon(isTablet),
                label: 'History',
                isTablet: isTablet,
              ),
              const SizedBox(width: 32),
              _buildLabeledIcon(
                icon: _buildCompactNotificationIcon(isTablet),
                label: 'Alerts',
                isTablet: isTablet,
              ),
            ],
          ),
        ),

        // Active vehicle display OR setup hint
        SizedBox(height: isTablet ? 24 : 20),
        if (_primaryPlate != null)
          _buildActiveVehicleDisplay(isTablet)
        else
          _buildSetupHint(isTablet),

        // Flexible space below - less space to keep content lower
        const Expanded(flex: 2, child: SizedBox()),

        // DezeTingz branding at the very bottom
        _buildBranding(),

        SizedBox(height: isTablet ? 8 : 6),
      ],
    );
  }

  /// Build content for smaller screens (scrollable, no Expanded widgets)
  Widget _buildScrollableContent(ThemeData theme, bool isTablet) {
    return Column(
      children: [
        // Subtle app identity
        _buildAppHeader(theme, isTablet),

        // Space above button - push content down
        SizedBox(height: isTablet ? 120 : 100),

        // Hero button - the centerpiece
        _buildHeroButton(theme, isTablet),

        // Stats and notification icons with labels - animated entrance
        SizedBox(height: isTablet ? 28 : 24),
        AnimatedBuilder(
          animation: _entranceController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _iconsSlideAnimation.value),
              child: Opacity(
                opacity: _iconsFadeAnimation.value,
                child: child,
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLabeledIcon(
                icon: _buildCompactStatsIcon(isTablet),
                label: 'History',
                isTablet: isTablet,
              ),
              const SizedBox(width: 32),
              _buildLabeledIcon(
                icon: _buildCompactNotificationIcon(isTablet),
                label: 'Alerts',
                isTablet: isTablet,
              ),
            ],
          ),
        ),

        // Active vehicle display OR setup hint
        SizedBox(height: isTablet ? 20 : 16),
        if (_primaryPlate != null)
          _buildActiveVehicleDisplay(isTablet)
        else
          _buildSetupHint(isTablet),

        SizedBox(height: isTablet ? 24 : 20),

        // DezeTingz branding at the very bottom
        _buildBranding(),

        // Extra bottom padding for scroll
        SizedBox(height: isTablet ? 12 : 8),
      ],
    );
  }

  /// Subtle setup hint for new users who haven't added a vehicle yet
  Widget _buildSetupHint(bool isTablet) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        // Navigate to My Vehicles
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: PremiumTheme.standardCurve,
              )),
              child: const PlateRegistrationScreen(),
            ),
            transitionDuration: PremiumTheme.mediumDuration,
          ),
        );
        await _refreshAllData();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 14 : 12,
        ),
        decoration: BoxDecoration(
          color: PremiumTheme.accentColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PremiumTheme.accentColor.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PremiumTheme.accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: PremiumTheme.accentColor,
                size: isTablet ? 20 : 18,
              ),
            ),
            SizedBox(width: isTablet ? 14 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add your vehicle',
                  style: TextStyle(
                    fontSize: isTablet ? 15 : 14,
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.primaryTextColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'to start receiving alerts',
                  style: TextStyle(
                    fontSize: isTablet ? 13 : 12,
                    fontWeight: FontWeight.w400,
                    color: PremiumTheme.secondaryTextColor,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
            SizedBox(width: isTablet ? 12 : 10),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: PremiumTheme.accentColor.withOpacity(0.6),
              size: isTablet ? 16 : 14,
            ),
          ],
        ),
      ),
    );
  }

  /// Premium incoming alert notification banner
  Widget _buildIncomingAlertBanner(bool isTablet) {
    // Calculate top offset to avoid blocking header icons
    final iconSpaceHeight = isTablet ? 56 : 48;
    final additionalMargin = isTablet ? 8 : 6;
    final topOffset = (iconSpaceHeight + additionalMargin).toDouble();

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: SafeArea(
        top:
            false, // Don't add extra safe area since we're manually positioning
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                  _shakeAnimation.value *
                      math.sin(_shakeController.value * 2 * math.pi * 4),
                  0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                transform: Matrix4.translationValues(
                  0,
                  _showingAlertBanner
                      ? 0
                      : -250, // Increased slide distance for smoother animation
                  0,
                ),
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 40.0 : 16.0,
                    vertical: isTablet
                        ? 12.0
                        : 8.0, // Reduced vertical margin since we have top spacing
                  ),
                  padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
                  decoration: BoxDecoration(
                    color: PremiumTheme.accentColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with notification icon and close button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_active,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                // Display emoji if available
                                if (_currentAlertEmoji != null) ...[
                                  Text(
                                    _currentAlertEmoji!,
                                    style: TextStyle(
                                      fontSize: isTablet ? 24 : 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    'Yuh Blockin\' Alert!',
                                    style: TextStyle(
                                      fontSize: isTablet ? 18 : 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Close button to dismiss alert
                          GestureDetector(
                            onTap: _dismissCurrentAlert,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Alert message
                      Text(
                        _currentSenderAlias != null
                            ? '${_aliasService.formatAliasForDisplay(_currentSenderAlias!)} needs you to move your car'
                            : 'Someone needs you to move your car',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Response options
                      Row(
                        children: [
                          // Primary response - Moving now
                          Expanded(
                            child: _buildResponseButton(
                              label: 'Moving now',
                              icon: Icons.directions_run,
                              isPrimary: true,
                              onTap: () => _respondToAlert('moving_now'),
                              isTablet: isTablet,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Secondary response - Give me 5 min
                          Expanded(
                            child: _buildResponseButton(
                              label: '5 minutes',
                              icon: Icons.schedule,
                              isPrimary: false,
                              onTap: () => _respondToAlert('5_minutes'),
                              isTablet: isTablet,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Tertiary options row
                      Row(
                        children: [
                          Expanded(
                            child: _buildResponseButton(
                              label: 'Can\'t right now',
                              icon: Icons.cancel_outlined,
                              isPrimary: false,
                              onTap: () => _respondToAlert('cant_move'),
                              isTablet: isTablet,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildResponseButton(
                              label: 'Wrong car',
                              icon: Icons.error_outline,
                              isPrimary: false,
                              onTap: () => _respondToAlert('wrong_car'),
                              isTablet: isTablet,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ), // Closes Container
              ), // Closes AnimatedContainer
            ); // Closes Transform.translate and return statement
          }, // Closes builder function
        ), // Closes AnimatedBuilder
      ), // Closes SafeArea
    ); // Closes Positioned
  }

  /// Response button for the alert banner with visual feedback
  Widget _buildResponseButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: isPrimary
            ? PremiumTheme.accentColor.withOpacity(0.2)
            : Colors.white.withOpacity(0.2),
        highlightColor: isPrimary
            ? PremiumTheme.accentColor.withOpacity(0.1)
            : Colors.white.withOpacity(0.1),
        child: Ink(
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 12.0 : 10.0,
            horizontal: isTablet ? 16.0 : 12.0,
          ),
          decoration: BoxDecoration(
            color: isPrimary ? Colors.white : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: !isPrimary
                ? Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? PremiumTheme.accentColor : Colors.white,
                size: isTablet ? 16 : 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isTablet ? 13 : 12,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? PremiumTheme.accentColor : Colors.white,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
