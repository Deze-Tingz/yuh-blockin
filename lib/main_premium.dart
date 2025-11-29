import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Native splash removed - using custom AppInitializer splash instead
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
import 'core/services/notification_service.dart';
import 'core/services/connectivity_service.dart';
import 'config/premium_config.dart';
import 'features/premium_alert/alert_history_screen.dart';
import 'features/plate_registration/plate_registration_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/theme_settings/theme_settings_screen.dart';
import 'features/subscription/paywall_dialog.dart';
import 'features/subscription/upgrade_screen.dart';
import 'core/services/subscription_service.dart';
import 'core/services/plate_verification_service.dart';

/// Premium flagship-quality Yuh Blockin' app
/// Inspired by Uber, Airbnb, Apple Human Interface guidelines
/// Minimal, elegant, professional with subtle 2025 motion signature
void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
/// With beautiful colored logo matching onboarding
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoSlide;
  late Animation<double> _footerFade;
  bool _goToHome = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600), // Faster, lighter intro
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Subtle slide up for quick intro effect
    _logoSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _checkOnboardingStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkOnboardingStatus() async {
    debugPrint('🔍 AppInitializer: Checking onboarding status...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding =
          prefs.getBool('onboarding_completed') ?? false;
      final userId = prefs.getString('user_id');
      final hasUserId = userId != null;

      debugPrint(
          '🔍 AppInitializer: hasCompletedOnboarding = $hasCompletedOnboarding');
      debugPrint('🔍 AppInitializer: hasUserId = $hasUserId (userId = $userId)');

      if (!mounted) return;

      _goToHome = hasCompletedOnboarding && hasUserId;

      // Show splash for 2 seconds to display footer properly
      await Future.delayed(const Duration(milliseconds: 2000));

      if (!mounted) return;

      _navigateToNextScreen();

    } catch (e) {
      debugPrint('❌ AppInitializer: Error checking status: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const OnboardingFlow(),
          ),
        );
      }
    }
  }

  void _navigateToNextScreen() {
    debugPrint(_goToHome
        ? '✅ AppInitializer: Going to home screen'
        : '🔄 AppInitializer: Going to onboarding');

    // Smooth transition with easing curve
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _goToHome
            ? const PremiumHomeScreen()
            : const OnboardingFlow(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Column(
            children: [
              // Main logo area with slide-up intro animation
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, _logoSlide.value),
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Premium company footer - always visible
              FadeTransition(
                opacity: _footerFade,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 0.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF1B6B7A).withValues(alpha: 0.4),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'from',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w300,
                                color: const Color(0xFF1B6B7A).withValues(alpha: 0.6),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 0.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF1B6B7A).withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF1B6B7A), // Teal from logo
                            Color(0xFFF08080), // Coral from logo
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'DezeTingz',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  // Recent activity feed - shows recent alerts on home screen
  List<Alert> _recentReceivedAlerts = [];
  List<Alert> _recentSentAlerts = [];
  final Set<String> _seenReceivedAlertIds = {};

  // Audio player for alert sound
  final AudioPlayer _alertAudioPlayer = AudioPlayer();

  // System notification and connectivity services
  final NotificationService _notificationService = NotificationService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isOffline = false;
  bool _showOfflineBanner = false;

  // Track app lifecycle state - only show system notifications when app is in background
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // Animation controller for shake effect
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // ===== INLINE ALERT MODE (Steve Jobs style - one screen) =====
  bool _isAlertModeActive = false;
  String _alertModeType = 'i_am_blocked'; // 'i_am_blocked' or 'i_am_blocking'
  final TextEditingController _alertPlateController = TextEditingController();
  final FocusNode _alertPlateFocusNode = FocusNode();
  String _alertUrgencyLevel = 'Normal';
  String? _alertSelectedEmoji;
  bool _isAlertPlateValid = false;
  bool _isSendingAlert = false;
  late AnimationController _alertModeController;
  late Animation<double> _alertModeAnimation;

  // Static regex for emoji extraction (compiled once for performance)
  static final RegExp _emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
      unicode: true);

  // Cancellable timers/futures for cleanup
  Timer? _taglineDelayTimer;
  Timer? _shakeStopTimer;
  Timer? _acknowledgeRefreshTimer;
  Timer? _alertAutoDismissTimer;

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer for app state changes
    WidgetsBinding.instance.addObserver(this);

    // Subtle breathing animation for hero button
    _breathingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Disabled continuous animation for better performance
    // _breathingController.repeat(reverse: true);

    // Initialize shake animation for alert banner
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
      duration: const Duration(milliseconds: 300),
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

    // Delayed tagline reveal (cancellable)
    _taglineDelayTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showTagline = true);
    });

    // Initialize alert mode animation controller
    _alertModeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _alertModeAnimation = CurvedAnimation(
      parent: _alertModeController,
      curve: Curves.easeOutCubic,
    );

    // Add listener for plate validation
    _alertPlateController.addListener(_validateAlertPlate);

    // Set default emoji
    _alertSelectedEmoji = '🚗';

    // CRITICAL: Defer initialization until after the transition completes
    // This prevents lag during the page transition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  void _validateAlertPlate() {
    String value = _alertPlateController.text.toUpperCase();

    // Normalize: remove extra spaces, keep only valid characters
    String normalizedPlate = value.replaceAll(RegExp(r'[^A-Z0-9\s\-]'), '');
    normalizedPlate = normalizedPlate.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Auto-format with dash between letters and numbers
    normalizedPlate = _formatAlertPlateWithDash(normalizedPlate);

    // Validate
    final cleanText = normalizedPlate.replaceAll('-', '').replaceAll(' ', '');
    final lengthValid = cleanText.length >= 2 && cleanText.length <= 8;
    final formatValid = RegExp(r'^[A-Z0-9\s\-]+$').hasMatch(normalizedPlate);
    final hasAlphaNumeric = RegExp(r'[A-Z0-9]').hasMatch(normalizedPlate);

    final isValid = lengthValid && formatValid && hasAlphaNumeric && normalizedPlate.isNotEmpty;

    // Update text field if formatting changed it
    if (normalizedPlate != value && normalizedPlate.isNotEmpty) {
      final cursorPos = _alertPlateController.selection.baseOffset;
      final lengthDiff = normalizedPlate.length - value.length;
      _alertPlateController.value = TextEditingValue(
        text: normalizedPlate,
        selection: TextSelection.collapsed(
          offset: (cursorPos + lengthDiff).clamp(0, normalizedPlate.length),
        ),
      );
    }

    if (_isAlertPlateValid != isValid) {
      setState(() => _isAlertPlateValid = isValid);
    }
  }

  /// Auto-format plate with dash between letters and numbers
  String _formatAlertPlateWithDash(String input) {
    // Remove any existing dashes and spaces for clean processing
    String clean = input.replaceAll(RegExp(r'[\s\-]'), '');

    if (clean.isEmpty) return clean;

    // Find transition from letters to numbers or numbers to letters
    String formatted = '';
    for (int i = 0; i < clean.length; i++) {
      if (i > 0) {
        final currentIsDigit = RegExp(r'\d').hasMatch(clean[i]);
        final previousIsDigit = RegExp(r'\d').hasMatch(clean[i - 1]);

        // Add dash when transitioning between letters and numbers
        if (currentIsDigit != previousIsDigit) {
          formatted += '-';
        }
      }
      formatted += clean[i];
    }

    return formatted;
  }

  /// Initialize app by ensuring user exists first, then loading other data
  /// Optimized to batch setState calls and reduce UI jank
  Future<void> _initializeApp() async {
    // Step 0: Initialize notification and connectivity services (parallel, non-blocking)
    unawaited(_initializeNotificationServices());

    // Step 1: Ensure user exists in database (BLOCKING)
    await _ensureUserExists();

    // Step 1.5: Sync local plates with database (remove stale local data)
    if (_currentUserId != null) {
      final syncResult = await _plateStorageService.syncWithDatabase(_currentUserId!);
      if (syncResult.hadChanges) {
        debugPrint('🔄 Sync: removed ${syncResult.removedCount}, restored ${syncResult.restoredCount}');
      }

      // Clean up orphaned ownership keys after sync
      final validPlates = await _plateStorageService.getRegisteredPlates();
      final verificationService = PlateVerificationService();
      await verificationService.cleanupOrphanedKeys(validPlates);
    }

    // Step 2: Load all data IN PARALLEL and batch the setState
    final results = await Future.wait([
      _loadPrimaryPlateData(),
      _loadUserStatsData(),
      _loadUnacknowledgedAlertsCountData(),
    ]);

    // Step 3: Single batched setState for all data
    if (mounted) {
      setState(() {
        _primaryPlate = results[0] as String?;
        _userStats = results[1] as UserStats;
        _unacknowledgedAlertsCount = results[2] as int;
      });
    }

    // Step 4: Initialize alert system (user ID is now guaranteed to exist)
    _initializeAlertSystem();
  }

  /// Initialize notification and connectivity services
  Future<void> _initializeNotificationServices() async {
    // Initialize notification service
    await _notificationService.initialize(
      onNotificationTapped: (payload) {
        // Handle notification tap - could navigate to alert screen
        debugPrint('Notification tapped with payload: $payload');
      },
    );

    // Initialize connectivity service with callbacks
    await _connectivityService.initialize(
      onLost: _handleConnectionLost,
      onRestored: _handleConnectionRestored,
    );

    // Check initial connection state
    _isOffline = !_connectivityService.isConnected;
    if (_isOffline && mounted) {
      setState(() => _showOfflineBanner = true);
    }
  }

  /// Handle connection lost
  void _handleConnectionLost() {
    if (!mounted) return;
    setState(() {
      _isOffline = true;
      _showOfflineBanner = true;
    });

    // Show a notification if app is in background
    _notificationService.showWarningNotification(
      title: 'No Internet Connection',
      body: 'You won\'t receive alerts until connection is restored.',
    );
  }

  /// Handle connection restored
  void _handleConnectionRestored() {
    if (!mounted) return;
    setState(() {
      _isOffline = false;
      _showOfflineBanner = false;
    });

    // Refresh data when connection is back
    _refreshAllData();
  }

  /// Helper to run futures without waiting (fire and forget)
  void unawaited(Future<void> future) {
    future.catchError((e) => debugPrint('Unawaited error: $e'));
  }

  // Data-only loaders (no setState) for batched updates
  Future<String?> _loadPrimaryPlateData() async {
    try {
      return await _plateStorageService.getPrimaryPlate();
    } catch (e) {
      return null;
    }
  }

  Future<UserStats> _loadUserStatsData() async {
    try {
      return await _statsService.getStats();
    } catch (e) {
      return UserStats(carsFreed: 0, situationsResolved: 0, alertsSent: 0, alertsReceived: 0);
    }
  }

  Future<int> _loadUnacknowledgedAlertsCountData() async {
    try {
      return await _unacknowledgedAlertService.getUnacknowledgedCount();
    } catch (e) {
      return 0;
    }
  }

  /// Refresh all home screen data - call when returning from other screens
  /// Uses batched setState for better performance
  Future<void> _refreshAllData() async {
    try {
      final results = await Future.wait([
        _loadPrimaryPlateData(),
        _loadUserStatsData(),
        _loadUnacknowledgedAlertsCountData(),
      ]);

      if (mounted) {
        setState(() {
          _primaryPlate = results[0] as String?;
          _userStats = results[1] as UserStats;
          _unacknowledgedAlertsCount = results[2] as int;
        });
      }
    } catch (e) {
      // Handle silently - data refresh is optional
    }
  }

  /// Load user stats and update state
  Future<void> _loadUserStats() async {
    final stats = await _loadUserStatsData();
    if (mounted) {
      setState(() => _userStats = stats);
    }
  }

  /// Load unacknowledged alerts count and update state
  Future<void> _loadUnacknowledgedAlertsCount() async {
    final count = await _loadUnacknowledgedAlertsCountData();
    if (mounted) {
      setState(() => _unacknowledgedAlertsCount = count);
    }
  }

  /// App lifecycle method - refresh data when app becomes active
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Track lifecycle state for notification handling
    _appLifecycleState = state;

    if (state == AppLifecycleState.resumed) {
      _refreshAllData();
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Cancel all timers to prevent memory leaks
    _taglineDelayTimer?.cancel();
    _shakeStopTimer?.cancel();
    _acknowledgeRefreshTimer?.cancel();

    // Dispose animation controllers
    _breathingController.dispose();
    _shakeController.dispose();
    _entranceController.dispose();
    _alertModeController.dispose();

    // Dispose alert mode controllers
    _alertPlateController.dispose();
    _alertPlateFocusNode.dispose();

    // Dispose audio player
    _alertAudioPlayer.dispose();

    // Dispose connectivity service
    _connectivityService.dispose();

    // Cancel alert stream subscriptions
    _alertStreamSubscription?.cancel();
    _sentAlertsStreamSubscription?.cancel();

    super.dispose();
  }

  /// Play premium alert sound when receiving an incoming alert
  Future<void> _playPremiumAlertSound() async {
    try {
      // Use WAV file - two-tone alert (A5 to C6) that's attention-grabbing but pleasant
      await _alertAudioPlayer.play(AssetSource('sounds/alert_sound.wav'));
    } catch (e) {
      debugPrint('Failed to play alert sound: $e');
      // Fallback to vibration if sound fails
      try {
        await _notificationService.vibrateOnly();
      } catch (_) {}
    }
  }

  /// Ensure user exists in database before accessing any features
  Future<void> _ensureUserExists() async {
    try {
      await _alertService.initialize();

      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      if (userId == null) {
        userId = await _alertService.getOrCreateUser();
        await prefs.setString('user_id', userId);
      }

      _currentUserId = userId;

      // Initialize subscription service
      await _subscriptionService.initialize(userId);
    } catch (e) {
      debugPrint('Failed to ensure user exists: $e');
    }
  }

  /// Initialize alert service and real-time alert listening
  Future<void> _initializeAlertSystem() async {
    try {
      // User creation is now handled by _ensureUserExists(), so we can use _currentUserId directly
      if (_currentUserId == null) {
        debugPrint('❌ Alert system initialization failed: No user ID available');
        return;
      }

      // Start listening for incoming alerts
      _startListeningForAlerts();

      // Start monitoring sent alerts for acknowledgments
      _startMonitoringSentAlerts();

      debugPrint('📱 Alert system initialized for user: $_currentUserId');
    } catch (e) {
      debugPrint('❌ Failed to initialize alert system: $e');
    }
  }

  /// Start listening for real-time incoming alerts
  void _startListeningForAlerts() {
    if (_currentUserId == null) return;

    try {
      _alertStreamSubscription =
          _alertService.getAlertsStream(_currentUserId!).listen(
        (alert) {
          debugPrint('🔔 Received incoming alert: ${alert.id}');

          // Update recent activity feed
          if (mounted) {
            setState(() {
              if (!_seenReceivedAlertIds.contains(alert.id)) {
                _seenReceivedAlertIds.add(alert.id);
                _recentReceivedAlerts.add(alert);
              } else {
                // Update existing alert
                final index = _recentReceivedAlerts.indexWhere((a) => a.id == alert.id);
                if (index != -1) {
                  _recentReceivedAlerts[index] = alert;
                }
              }
              // Keep only 5 most recent, sorted by newest first
              _recentReceivedAlerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (_recentReceivedAlerts.length > 5) {
                _recentReceivedAlerts = _recentReceivedAlerts.take(5).toList();
              }
            });
          }

          // Only show alerts that:
          // 1. Haven't been shown before
          // 2. Haven't been read yet
          // 3. Haven't been responded to
          // 4. Are recent (within 5 minutes) - prevents showing old alerts on app reopen
          final alertAge = DateTime.now().difference(alert.createdAt);
          final isRecent = alertAge.inMinutes < 5;

          if (!_shownAlertIds.contains(alert.id) &&
              alert.readAt == null &&
              alert.response == null &&
              isRecent) {
            _handleIncomingAlert(alert);
            _shownAlertIds.add(alert.id); // Mark as shown
          } else {
            if (!isRecent) {
              debugPrint('ℹ️ Alert ${alert.id} is ${alertAge.inMinutes}min old - skipping banner (too old)');
            } else {
              debugPrint('ℹ️ Alert ${alert.id} already shown, read, or responded to - skipping');
            }
            // Still mark as shown to prevent future triggers
            _shownAlertIds.add(alert.id);
          }
        },
        onError: (error) {
          debugPrint('❌ Alert stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start alert listening: $e');
    }
  }

  /// Start monitoring sent alerts for acknowledgments
  void _startMonitoringSentAlerts() {
    if (_currentUserId == null) return;

    try {
      _sentAlertsStreamSubscription =
          _alertService.getSentAlertsStream(_currentUserId!).listen(
        (alerts) {
          // Update recent sent alerts for activity feed
          if (mounted) {
            setState(() {
              // Deduplicate and keep 5 most recent
              final uniqueAlerts = <String, Alert>{};
              for (final alert in alerts) {
                uniqueAlerts[alert.id] = alert;
              }
              _recentSentAlerts = uniqueAlerts.values.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (_recentSentAlerts.length > 5) {
                _recentSentAlerts = _recentSentAlerts.take(5).toList();
              }
            });
          }
          _processSentAlertsForAcknowledgments(alerts);
        },
        onError: (error) {
          debugPrint('❌ Sent alerts stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start sent alerts monitoring: $e');
    }
  }

  /// Process sent alerts to mark acknowledged ones and show notifications
  void _processSentAlertsForAcknowledgments(List<Alert> alerts) {
    for (final alert in alerts) {
      // If alert has a response and hasn't been processed yet, mark it as acknowledged
      if (alert.response != null &&
          alert.responseAt != null &&
          !_acknowledgedAlertIds.contains(alert.id)) {

        // Mark this alert as processed to prevent duplicate marking
        _acknowledgedAlertIds.add(alert.id);

        // Show notification for the response
        _showResponseNotification(alert);

        // Mark as acknowledged and immediately refresh counter when done
        _unacknowledgedAlertService.markAlertAcknowledged(alert.id).then((_) {
          debugPrint('✅ Marked sent alert ${alert.id} as acknowledged');
          // Immediately refresh counter after successful marking
          if (mounted) {
            _loadUnacknowledgedAlertsCount();
          }
        }).catchError((error) {
          debugPrint('⚠️ Failed to mark alert ${alert.id} as acknowledged: $error');
          // Remove from set if marking failed, so we can retry
          _acknowledgedAlertIds.remove(alert.id);
        });
      }
    }
  }

  /// Show notification when a response is received for a sent alert
  void _showResponseNotification(Alert alert) {
    if (!mounted) return;

    final responseText = alert.responseText;
    String title;
    String body;

    // Customize notification based on response type
    switch (alert.response) {
      case 'moving_now':
        title = 'They\'re moving!';
        body = 'The car owner is moving their vehicle now';
        break;
      case '5_minutes':
        title = 'Give them 5 minutes';
        body = 'The car owner will move in about 5 minutes';
        break;
      case 'cant_move':
        title = 'Can\'t move right now';
        body = 'The car owner cannot move their vehicle at this time';
        break;
      case 'wrong_car':
        title = 'Wrong car!';
        body = 'You may have alerted the wrong person';
        break;
      default:
        title = 'Response received';
        body = responseText;
    }

    // Only show system notification when app is NOT in foreground
    if (_appLifecycleState != AppLifecycleState.resumed) {
      _notificationService.showAlertNotification(
        title: title,
        body: body,
        payload: alert.id,
        playSound: true,
        vibrate: true,
      );
      debugPrint('📢 Showed response notification: $title - $body');
    } else {
      debugPrint('ℹ️ Skipped system notification (app in foreground): $title - $body');
    }
  }


  /// Sync unacknowledged alerts with database (call when viewing alert history)
  Future<void> _syncUnacknowledgedAlerts() async {
    if (_currentUserId == null) return;

    try {
      debugPrint('🔄 Syncing unacknowledged alerts with database...');

      // Get all sent alerts from database
      final sentAlerts = await _alertService.getSentAlerts(_currentUserId!);

      // Process them to mark any with responses as acknowledged
      for (final alert in sentAlerts) {
        if (alert.response != null &&
            alert.responseAt != null &&
            !_acknowledgedAlertIds.contains(alert.id)) {

          _acknowledgedAlertIds.add(alert.id);

          await _unacknowledgedAlertService.markAlertAcknowledged(alert.id);
          debugPrint('✅ Synced and marked alert ${alert.id} as acknowledged');
        }
      }

      debugPrint('✅ Sync complete');
    } catch (e) {
      debugPrint('❌ Error syncing unacknowledged alerts: $e');
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
      debugPrint('❌ Failed to get sender alias: $e');
      senderAlias = 'Anonymous';
    }

    // Extract emoji from alert message (if present) using static regex
    String? emoji;
    if (alert.message != null && alert.message!.isNotEmpty) {
      final match = _emojiRegex.firstMatch(alert.message!);
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

    // Play premium alert sound
    _playPremiumAlertSound();

    // Only show system notification when app is NOT in foreground
    // (for lock screen, background, other apps - not when user is in the app)
    if (_appLifecycleState != AppLifecycleState.resumed) {
      _notificationService.showAlertNotification(
        title: 'Someone needs you to move!',
        body: '$senderAlias is asking you to move your car${emoji != null ? ' $emoji' : ''}',
        payload: alert.id,
        playSound: true,
        vibrate: true,
      );
    }

    // Premium haptic feedback - phone vibration
    HapticFeedback.heavyImpact();
    // Additional vibration patterns for emphasis
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();

    // Start shake animation for the banner
    _shakeController.repeat(reverse: true);

    // Stop shaking after 2 seconds (cancellable)
    _shakeStopTimer?.cancel();
    _shakeStopTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _shakeController.isAnimating) {
        _shakeController.stop();
        _shakeController.reset();
      }
    });

    // Auto-dismiss alert banner after 30 seconds if no response
    _alertAutoDismissTimer?.cancel();
    _alertAutoDismissTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _showingAlertBanner && _currentIncomingAlert != null) {
        debugPrint('⏰ Auto-dismissing alert banner after 30 seconds');
        _dismissCurrentAlert();
      }
    });
  }

  /// Dismiss current alert without responding
  Future<void> _dismissCurrentAlert() async {
    if (_currentIncomingAlert == null) return;

    // Cancel auto-dismiss timer
    _alertAutoDismissTimer?.cancel();

    debugPrint('🔕 Dismissing alert: ${_currentIncomingAlert!.id}');

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
      debugPrint('✅ Alert dismissed and marked as read');
    } catch (e) {
      debugPrint('❌ Failed to dismiss alert: $e');
    }
  }

  /// Respond to alert with acknowledgment
  Future<void> _respondToAlert(String response) async {
    if (_currentIncomingAlert == null) return;

    // Cancel auto-dismiss timer
    _alertAutoDismissTimer?.cancel();

    debugPrint(
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

        debugPrint('✅ Responded to alert: $response');
        debugPrint(
            '📡 Response should now appear on sender\'s device via real-time stream');

        // Show premium confirmation snackbar with enhanced animations
        if (mounted) {
          final responseText = _getResponseDisplayText(response);
          _showPremiumSnackBar(
            message: 'Response sent: $responseText',
            isSuccess: true,
            duration: const Duration(milliseconds: 500),
            icon: Icons.check_circle_outline,
          );
        }
      } else {
        throw Exception('Failed to send response');
      }
    } catch (e) {
      debugPrint('❌ Failed to respond to alert: $e');

      // Show premium error snackbar with enhanced animations
      if (mounted) {
        _showPremiumSnackBar(
          message: 'Failed to send response. Please try again.',
          isSuccess: false,
          duration: const Duration(milliseconds: 500),
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
                      PremiumTheme.accentColor.withValues(alpha: 0.9),
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
                    ? PremiumTheme.accentColor.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                    color: Colors.white.withValues(alpha: 0.2),
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
          textColor: Colors.white.withValues(alpha: 0.8),
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
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.5),
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
      onPopInvokedWithResult: (didPop, result) async {
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
                    color: PremiumTheme.primaryTextColor.withValues(alpha: 0.8)),
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

          if ((shouldExit ?? false) && mounted) {
            // ignore: use_build_context_synchronously
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

            // Offline banner - shows when no internet connection
            if (_showOfflineBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No internet - alerts may be delayed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showOfflineBanner = false),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Main content - bottom: false so footer can reach screen bottom
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomPadding = MediaQuery.of(context).padding.bottom;
                  // Determine if screen is compact (reduce spacing)
                  final isCompact = constraints.maxHeight < 700;

                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      left: isTablet ? 80.0 : 32.0,
                      right: isTablet ? 80.0 : 32.0,
                      top: isTablet ? 60.0 : (isCompact ? 16.0 : 40.0),
                      bottom: bottomPadding,
                    ),
                    // Always use static content with Expanded widgets - fits without scrolling
                    child: _buildStaticContent(theme, isTablet, isCompact: isCompact),
                  );
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
          // Logo on the left with blue accent filter
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              PremiumTheme.accentColor,
              BlendMode.srcIn,
            ),
            child: Image.asset(
              'assets/images/logo_transparent.png',
              height: isTablet ? 60 : 48,
              fit: BoxFit.contain,
            ),
          ),
          // Menu button on the right
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PremiumTheme.surfaceColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: PremiumTheme.accentColor.withValues(alpha: 0.1),
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
                  color: PremiumTheme.accentColor.withValues(alpha: 0.3),
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
                        transform: Matrix4.translationValues(0.0, _isPressed ? 4.0 : 0.0, 0.0),
                        child: Icon(
                          Icons.campaign_rounded,
                          size: isTablet ? 56 : 48,
                          color: _isPressed ? Colors.white.withValues(alpha: 0.9) : Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // App name / Brand identity
                      Text(
                        'YUH BLOCKIN\'',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Subtle tap hint
                      Text(
                        'Tap to alert',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.7),
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

  Widget _buildBranding() {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 12),
      child: Column(
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
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.tertiaryTextColor.withValues(alpha: 0.7),
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
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: PremiumTheme.tertiaryTextColor.withValues(alpha: 0.5),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact recent activity feed for home screen
  Widget _buildRecentActivityFeed(bool isTablet) {
    // Combine and sort all alerts by time
    final allAlerts = <_ActivityItem>[];

    for (final alert in _recentReceivedAlerts) {
      allAlerts.add(_ActivityItem(
        alert: alert,
        isReceived: true,
        time: alert.createdAt,
      ));
    }

    for (final alert in _recentSentAlerts) {
      allAlerts.add(_ActivityItem(
        alert: alert,
        isReceived: false,
        time: alert.createdAt,
      ));
    }

    // Sort by newest first and take only 3
    allAlerts.sort((a, b) => b.time.compareTo(a.time));
    final displayAlerts = allAlerts.take(3).toList();

    if (displayAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 0),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PremiumTheme.dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium header with gradient
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PremiumTheme.accentColor.withValues(alpha: 0.06),
                  PremiumTheme.accentColor.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PremiumTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: PremiumTheme.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: PremiumTheme.primaryTextColor,
                        ),
                      ),
                      Text(
                        '${displayAlerts.length} alert${displayAlerts.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: PremiumTheme.tertiaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (_currentUserId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlertHistoryScreen(userId: _currentUserId!),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: PremiumTheme.accentColor,
                  ),
                  label: Text(
                    'History',
                    style: TextStyle(
                      fontSize: 13,
                      color: PremiumTheme.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: PremiumTheme.accentColor.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alert items with padding
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Column(
              children: displayAlerts.map((item) => _buildActivityItem(item, isTablet)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Extract emoji from alert message
  String? _extractEmojiFromAlert(Alert alert) {
    if (alert.message != null && alert.message!.isNotEmpty) {
      final match = _emojiRegex.firstMatch(alert.message!);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  /// Build a single activity item - premium design with emoji
  Widget _buildActivityItem(_ActivityItem item, bool isTablet) {
    final alert = item.alert;
    final hasResponse = alert.response != null && alert.response!.isNotEmpty;

    // Extract emoji from alert message
    final emoji = _extractEmojiFromAlert(alert);

    // Determine status colors and text
    Color statusColor;
    String statusText;
    IconData? statusIcon;

    if (item.isReceived) {
      if (hasResponse) {
        statusColor = Colors.green;
        statusText = 'Done';
        statusIcon = Icons.check;
      } else {
        statusColor = Colors.orange;
        statusText = 'Respond';
        statusIcon = null;
      }
    } else {
      if (hasResponse) {
        switch (alert.response) {
          case 'moving_now':
            statusColor = Colors.green;
            statusText = 'Moving';
            statusIcon = Icons.directions_car;
            break;
          case '5_minutes':
            statusColor = Colors.orange;
            statusText = '5 min';
            statusIcon = Icons.timer;
            break;
          case 'cant_move':
            statusColor = Colors.red;
            statusText = "Can't";
            statusIcon = Icons.block;
            break;
          case 'wrong_car':
            statusColor = Colors.grey;
            statusText = 'Wrong';
            statusIcon = Icons.error_outline;
            break;
          default:
            statusColor = Colors.green;
            statusText = 'Done';
            statusIcon = Icons.check;
        }
      } else {
        statusColor = Colors.blue;
        statusText = 'Waiting';
        statusIcon = Icons.more_horiz;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.06),
            statusColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            if (_currentUserId != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AlertHistoryScreen(userId: _currentUserId!),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Emoji or fallback icon - premium styled
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PremiumTheme.surfaceColor,
                        statusColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: emoji != null
                        ? Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          )
                        : Icon(
                            item.isReceived ? Icons.notifications : Icons.send,
                            color: statusColor,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.isReceived ? 'Someone blocked you in' : 'You sent an alert',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: PremiumTheme.primaryTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isReceived && !hasResponse) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Time and status
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: PremiumTheme.tertiaryTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeAgo(item.time),
                            style: TextStyle(
                              fontSize: 12,
                              color: PremiumTheme.tertiaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status badge or respond button
                if (item.isReceived && !hasResponse)
                  // Quick respond button
                  GestureDetector(
                    onTap: () => _quickRespondToAlert(alert),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.reply,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (statusIcon != null) ...[
                          Icon(
                            statusIcon,
                            color: statusColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
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

  /// Quick respond dialog for home screen
  void _quickRespondToAlert(Alert alert) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: PremiumTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PremiumTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Quick Response',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: PremiumTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Response buttons
            Row(
              children: [
                Expanded(
                  child: _buildQuickResponseButton(
                    alert: alert,
                    label: 'Moving now',
                    response: 'moving_now',
                    color: Colors.green,
                    icon: Icons.directions_car,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickResponseButton(
                    alert: alert,
                    label: '5 min',
                    response: '5_minutes',
                    color: Colors.orange,
                    icon: Icons.timer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildQuickResponseButton(
                    alert: alert,
                    label: "Can't move",
                    response: 'cant_move',
                    color: Colors.red,
                    icon: Icons.block,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickResponseButton(
                    alert: alert,
                    label: 'Wrong car',
                    response: 'wrong_car',
                    color: Colors.grey,
                    icon: Icons.error_outline,
                  ),
                ),
              ],
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickResponseButton({
    required Alert alert,
    required String label,
    required String response,
    required Color color,
    required IconData icon,
  }) {
    return ElevatedButton.icon(
      onPressed: () async {
        Navigator.pop(context);

        try {
          final success = await _alertService.sendResponse(
            alertId: alert.id,
            response: response,
          );

          if (success && mounted) {
            HapticFeedback.mediumImpact();
            await _statsService.incrementCarsFreed();
            _showPremiumSnackBar(
              message: 'Response sent!',
              isSuccess: true,
              icon: Icons.check_circle_outline,
            );
          }
        } catch (e) {
          if (mounted) {
            _showPremiumSnackBar(
              message: 'Failed to respond',
              isSuccess: false,
              icon: Icons.error_outline,
            );
          }
        }
      },
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
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
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: PremiumTheme.secondaryTextColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  /// Subscription usage badge - shows remaining alerts or premium status
  Widget _buildSubscriptionBadge() {
    // Safe access - use defaults if service not ready yet
    bool isPremium = false;
    int remaining = SubscriptionService.freeDailyAlertLimit;
    int used = 0;
    const limit = SubscriptionService.freeDailyAlertLimit;

    try {
      isPremium = _subscriptionService.isPremium;
      remaining = _subscriptionService.remainingAlerts;
      used = _subscriptionService.dailyAlertsUsed;
    } catch (e) {
      // Service not initialized yet, use defaults
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (!isPremium) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const UpgradeScreen(),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: PremiumTheme.fastDuration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPremium
              ? PremiumTheme.accentColor.withValues(alpha: 0.15)
              : (remaining == 0
                  ? Colors.red.withValues(alpha: 0.1)
                  : PremiumTheme.surfaceColor),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPremium
                ? PremiumTheme.accentColor.withValues(alpha: 0.3)
                : (remaining == 0
                    ? Colors.red.withValues(alpha: 0.3)
                    : PremiumTheme.dividerColor),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPremium
                  ? Icons.workspace_premium_rounded
                  : (remaining == 0
                      ? Icons.warning_amber_rounded
                      : Icons.flash_on_rounded),
              size: 14,
              color: isPremium
                  ? PremiumTheme.accentColor
                  : (remaining == 0
                      ? Colors.red.shade400
                      : PremiumTheme.secondaryTextColor),
            ),
            const SizedBox(width: 6),
            Text(
              isPremium
                  ? 'Premium'
                  : '$used/$limit today',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isPremium
                    ? PremiumTheme.accentColor
                    : (remaining == 0
                        ? Colors.red.shade400
                        : PremiumTheme.secondaryTextColor),
              ),
            ),
            if (!isPremium) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: remaining == 0
                    ? Colors.red.shade400
                    : PremiumTheme.tertiaryTextColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Floating glass bottom bar with premium styling
  // ignore: unused_element
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
            color: PremiumTheme.surfaceColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: PremiumTheme.accentColor.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: PremiumTheme.accentColor.withValues(alpha: 0.05),
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
              PremiumTheme.surfaceColor.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PremiumTheme.accentColor.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: PremiumTheme.accentColor.withValues(alpha: 0.08),
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
                    PremiumTheme.accentColor.withValues(alpha: 0.1),
                    PremiumTheme.accentColor.withValues(alpha: 0.05),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAlertTap() async {
    // Check if user has a primary plate registered
    if (_primaryPlate == null || _primaryPlate!.isEmpty) {
      HapticFeedback.mediumImpact();
      _showPlateRequiredDialog();
      return;
    }

    // If alert mode is already active, just close it
    if (_isAlertModeActive) {
      _closeAlertMode();
      return;
    }

    // Show choice bottom sheet
    HapticFeedback.lightImpact();
    _showAlertTypeChoice();
  }

  void _showAlertTypeChoice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: PremiumTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PremiumTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'What would you like to do?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: PremiumTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 24),

            // Option 1: I'm Blocked (Free with limits)
            _buildAlertTypeOption(
              icon: Icons.block_rounded,
              title: "I'm Blocked",
              subtitle: 'Alert the driver blocking me',
              isPremium: false,
              onTap: () async {
                Navigator.pop(context);
                // Check subscription limit for free users
                if (!await _subscriptionService.canSendAlert()) {
                  HapticFeedback.mediumImpact();
                  if (mounted) {
                    PaywallDialog.show(context, remainingAlerts: 0);
                  }
                  return;
                }
                _openAlertMode('i_am_blocked');
              },
            ),

            const SizedBox(height: 12),

            // Option 2: I'm Blocking (Premium Only)
            _buildAlertTypeOption(
              icon: Icons.notifications_active_rounded,
              title: "I'm Blocking",
              subtitle: 'Alert the driver I blocked them',
              isPremium: true,
              onTap: () async {
                Navigator.pop(context);
                // Check if user is premium
                if (!_subscriptionService.isPremium) {
                  HapticFeedback.mediumImpact();
                  if (mounted) {
                    PaywallDialog.show(
                      context,
                      remainingAlerts: 0,
                      customMessage: 'Notify drivers you\'re blocking with Premium',
                    );
                  }
                  return;
                }
                _openAlertMode('i_am_blocking');
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTypeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPremium,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PremiumTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPremium
                ? PremiumTheme.accentColor.withValues(alpha: 0.3)
                : PremiumTheme.dividerColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPremium
                    ? PremiumTheme.accentColor.withValues(alpha: 0.1)
                    : PremiumTheme.dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPremium ? PremiumTheme.accentColor : PremiumTheme.secondaryTextColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: PremiumTheme.primaryTextColor,
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: PremiumTheme.heroGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: PremiumTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: PremiumTheme.tertiaryTextColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _openAlertMode(String modeType) {
    setState(() {
      _alertModeType = modeType;
      _isAlertModeActive = true;
    });
    _alertModeController.forward();
    // Focus on plate input after animation
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _alertPlateFocusNode.requestFocus();
    });
  }

  // Legacy handler for direct alert mode toggle
  void _handleAlertTapLegacy() async {
    // Check if user can send alert (subscription limit check)
    if (!await _subscriptionService.canSendAlert()) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        PaywallDialog.show(context, remainingAlerts: 0);
      }
      return;
    }

    // Toggle inline alert mode
    HapticFeedback.lightImpact();

    if (_isAlertModeActive) {
      // Collapse alert mode
      _alertModeController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isAlertModeActive = false;
            _alertPlateController.clear();
            _alertUrgencyLevel = 'Normal';
            _alertSelectedEmoji = '🚗';
          });
        }
      });
    } else {
      // Expand alert mode
      setState(() {
        _isAlertModeActive = true;
      });
      _alertModeController.forward();
      // Focus on plate input after animation
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _alertPlateFocusNode.requestFocus();
      });
    }
  }

  void _closeAlertMode() {
    HapticFeedback.lightImpact();
    _alertModeController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isAlertModeActive = false;
          _alertPlateController.clear();
          _alertUrgencyLevel = 'Normal';
          _alertSelectedEmoji = '🚗';
        });
      }
    });
  }

  Future<void> _sendInlineAlert() async {
    if (!_isAlertPlateValid || _isSendingAlert) return;

    setState(() => _isSendingAlert = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await _alertService.sendAlert(
        targetPlateNumber: _alertPlateController.text.trim().toUpperCase(),
        senderUserId: _currentUserId!,
        message: _alertSelectedEmoji ?? '🚗',
      );

      if (mounted) {
        if (result.success) {
          HapticFeedback.heavyImpact();
          // Record alert sent (increment daily usage for free users)
          await _subscriptionService.incrementDailyUsage();

          // Show success and close
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Alert sent to ${result.recipients} user${result.recipients == 1 ? '' : 's'}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          _closeAlertMode();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to send alert'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingAlert = false);
    }
  }

  // ignore: unused_element
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
            debugPrint('🔄 MainPremium: Navigating to vehicle management...');

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
            debugPrint(
                '🔄 MainPremium: Returned from vehicle management - refreshing all data...');
            await _refreshAllData();
            debugPrint('✅ MainPremium: Complete data refresh completed');
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
              color: PremiumTheme.accentColor.withValues(alpha: 0.1),
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

  // ignore: unused_element
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
            PremiumTheme.surfaceColor.withValues(alpha: 0.6),
            PremiumTheme.surfaceColor.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PremiumTheme.accentColor.withValues(alpha: 0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.accentColor.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            margin: const EdgeInsets.only(top: 2),
            color: PremiumTheme.accentColor.withValues(alpha: 0.1),
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

  // ignore: unused_element
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
            Colors.purple.shade50.withValues(alpha: 0.3),
            Colors.purple.shade50.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.purple.withValues(alpha: 0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.04),
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
                      Colors.purple.withValues(alpha: 0.15),
                      Colors.purple.withValues(alpha: 0.08),
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
                  fontSize: isTablet ? 15 : 13,
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
                color: Colors.purple.withValues(alpha: 0.15),
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
    return SizedBox(
      width: isTablet ? 80 : 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed height container for consistent alignment
          SizedBox(
            height: isTablet ? 20 : 18,
            child: Center(
              child: Icon(icon, color: color, size: isTablet ? 18 : 16),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w700,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 11 : 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCounterWithEmoji({
    required int count,
    required String label,
    required String emoji,
    required Color color,
    required bool isTablet,
  }) {
    return SizedBox(
      width: isTablet ? 80 : 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed height container for consistent alignment
          SizedBox(
            height: isTablet ? 20 : 18,
            child: Center(
              child: Text(emoji, style: TextStyle(fontSize: isTablet ? 16 : 14)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w700,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 11 : 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
            color: color.withValues(alpha: 0.12),
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
                fontSize: isTablet ? 11 : 10,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
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
                        Colors.green.shade500.withValues(alpha: 0.15),
                        Colors.green.shade600.withValues(alpha: 0.08),
                      ]
                    : [
                        PremiumTheme.surfaceColor.withValues(alpha: 0.6),
                        PremiumTheme.surfaceColor.withValues(alpha: 0.4),
                      ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: hasStats
                    ? Colors.green.withValues(alpha: 0.2)
                    : PremiumTheme.accentColor.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasStats
                      ? Colors.green.withValues(alpha: 0.1)
                      : PremiumTheme.accentColor.withValues(alpha: 0.05),
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
                      PremiumTheme.accentColor.withValues(alpha: 0.9),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PremiumTheme.backgroundColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PremiumTheme.accentColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    totalImpact > 99 ? '99+' : '$totalImpact',
                    style: TextStyle(
                      fontSize: isTablet ? 13 : 12,
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
      barrierColor: Colors.black.withValues(alpha: 0.5),
      child: Dialog(
        backgroundColor: PremiumTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 380 : 320,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                'Your Impact',
                style: TextStyle(
                  fontSize: isSmallScreen ? 20 : 22,
                  fontWeight: FontWeight.w700,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),

              SizedBox(height: isSmallScreen ? 20 : 24),

              // Two stat cards side by side
              Row(
                children: [
                  // I Moved
                  Expanded(
                    child: _buildImpactCard(
                      count: _userStats.carsFreed,
                      label: 'I Moved',
                      icon: Icons.directions_car_rounded,
                      color: PremiumTheme.accentColor,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // They Moved
                  Expanded(
                    child: _buildImpactCard(
                      count: _userStats.situationsResolved,
                      label: 'They Moved',
                      icon: Icons.handshake_rounded,
                      color: Colors.green.shade600,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                ],
              ),

              SizedBox(height: isSmallScreen ? 20 : 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.accentColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImpactCard({
    required int count,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 16 : 20,
        horizontal: isSmallScreen ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: isSmallScreen ? 28 : 32,
          ),
          SizedBox(height: isSmallScreen ? 8 : 10),
          Text(
            '$count',
            style: TextStyle(
              fontSize: isSmallScreen ? 28 : 32,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: PremiumTheme.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Show dialog requiring user to register a plate first
  void _showPlateRequiredDialog() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;
    final isSmallScreen = screenSize.height < 600;

    _showPremiumDialog(
      barrierColor: Colors.black.withValues(alpha: 0.4),
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
                      Colors.orange.withValues(alpha: 0.15),
                      Colors.orange.withValues(alpha: 0.08),
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

        // Reset counter immediately when opening notifications
        setState(() {
          _unacknowledgedAlertsCount = 0;
        });

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
                        Colors.orange.shade500.withValues(alpha: 0.2),
                        Colors.red.shade500.withValues(alpha: 0.1),
                      ]
                    : [
                        PremiumTheme.surfaceColor.withValues(alpha: 0.6),
                        PremiumTheme.surfaceColor.withValues(alpha: 0.4),
                      ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: showingUrgent
                    ? Colors.orange.withValues(alpha: 0.3)
                    : PremiumTheme.accentColor.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: showingUrgent
                      ? Colors.orange.withValues(alpha: 0.15)
                      : PremiumTheme.accentColor.withValues(alpha: 0.05),
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
                      PremiumTheme.accentColor.withValues(alpha: 0.9),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PremiumTheme.backgroundColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PremiumTheme.accentColor.withValues(alpha: 0.4),
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
  // ignore: unused_element
  void _showNotificationStats() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;
    final isSmallScreen = screenSize.height < 600;

    _showPremiumDialog(
      barrierColor: Colors.black.withValues(alpha: 0.4),
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
                            Colors.purple.withValues(alpha: 0.15),
                            Colors.purple.withValues(alpha: 0.08),
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
                        Colors.purple.shade50.withValues(alpha: 0.3),
                        Colors.purple.shade50.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.1),
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
                          color: Colors.purple.withValues(alpha: 0.15),
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
            color: color.withValues(alpha: 0.15),
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
            color: color.withValues(alpha: 0.8),
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ignore: unused_element
  void _showMinimalDialog() {
    _showPremiumDialog(
      barrierColor: Colors.black.withValues(alpha: 0.3),
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
              child: const Text(
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

  /// Build content layout (with Flexible widgets to fit without scrolling)
  Widget _buildStaticContent(ThemeData theme, bool isTablet, {bool isCompact = false}) {
    // When alert mode is active, use a simpler layout that doesn't cause overflow
    if (_isAlertModeActive) {
      return _buildAlertModeLayout(theme, isTablet);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we have very limited vertical space or activity feed is shown
        final isVeryCompact = constraints.maxHeight < 550;
        final hasActivityFeed = _recentReceivedAlerts.isNotEmpty || _recentSentAlerts.isNotEmpty;

        return SingleChildScrollView(
          physics: (isVeryCompact || hasActivityFeed)
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Subtle app identity
                  _buildAppHeader(theme, isTablet),

                  // Flexible space above - reduced to push content up
                  Expanded(flex: isCompact ? 1 : 2, child: const SizedBox()),

                  // MAIN CONTENT: Hero button when not in alert mode
                  ...[
                    // Hero button - the centerpiece
                    _buildHeroButton(theme, isTablet),

                    // Stats and notification icons with labels - animated entrance
                    SizedBox(height: isCompact ? 12 : (isTablet ? 28 : 20)),
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

                    // Subscription usage badge
                    SizedBox(height: isCompact ? 8 : 12),
                    _buildSubscriptionBadge(),

                    // Active vehicle display OR setup hint
                    SizedBox(height: isCompact ? 8 : (isTablet ? 24 : 16)),
                    if (_primaryPlate != null)
                      _buildActiveVehicleDisplay(isTablet)
                    else
                      _buildSetupHint(isTablet),

                    // Recent activity feed
                    if (_recentReceivedAlerts.isNotEmpty || _recentSentAlerts.isNotEmpty) ...[
                      SizedBox(height: isCompact ? 12 : 20),
                      _buildRecentActivityFeed(isTablet),
                    ],
                  ],

                  // Spacer pushes footer to absolute bottom
                  Expanded(flex: isCompact ? 1 : 2, child: const SizedBox()),

                  // DezeTingz branding at the very bottom
                  _buildBranding(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build layout specifically for alert mode (prevents overflow issues)
  Widget _buildAlertModeLayout(ThemeData theme, bool isTablet) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: isTablet ? 24 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App header at top
            _buildAppHeader(theme, isTablet),

            // Space before alert mode card
            SizedBox(height: isTablet ? 40 : 24),

            // The inline alert mode content
            _buildInlineAlertMode(isTablet),

            // Bottom padding for keyboard
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 40),
          ],
        ),
      ),
    );
  }

  /// Build content for smaller screens (scrollable, no Expanded widgets) - DEPRECATED
  // ignore: unused_element
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

        // Subscription usage badge
        const SizedBox(height: 12),
        _buildSubscriptionBadge(),

        // Active vehicle display OR setup hint
        SizedBox(height: isTablet ? 20 : 16),
        if (_primaryPlate != null)
          _buildActiveVehicleDisplay(isTablet)
        else
          _buildSetupHint(isTablet),

        SizedBox(height: isTablet ? 24 : 20),

        // DezeTingz branding at the very bottom
        _buildBranding(),
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
          color: PremiumTheme.accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PremiumTheme.accentColor.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PremiumTheme.accentColor.withValues(alpha: 0.1),
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
              color: PremiumTheme.accentColor.withValues(alpha: 0.6),
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
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
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
                        color: Colors.black.withValues(alpha: 0.15),
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
                              color: Colors.white.withValues(alpha: 0.2),
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
                          // Close button to dismiss alert - made more visible
                          GestureDetector(
                            onTap: _dismissCurrentAlert,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 24,
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
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
            ? PremiumTheme.accentColor.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.2),
        highlightColor: isPrimary
            ? PremiumTheme.accentColor.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.1),
        child: Ink(
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 12.0 : 10.0,
            horizontal: isTablet ? 16.0 : 12.0,
          ),
          decoration: BoxDecoration(
            color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: !isPrimary
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
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

  // ===== INLINE ALERT MODE UI (Steve Jobs - One Screen) =====

  Widget _buildInlineAlertMode(bool isTablet) {
    return AnimatedBuilder(
      animation: _alertModeAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * _alertModeAnimation.value),
          child: Opacity(
            opacity: _alertModeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16),
        padding: EdgeInsets.all(isTablet ? 28 : 20),
        decoration: BoxDecoration(
          // Premium glass morphism effect
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumTheme.surfaceColor.withValues(alpha: 0.95),
              PremiumTheme.surfaceColor.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: PremiumTheme.accentColor.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            // Outer glow
            BoxShadow(
              color: PremiumTheme.accentColor.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 0,
            ),
            // Soft shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium header with close button
            _buildAlertModeHeader(isTablet),

            SizedBox(height: isTablet ? 24 : 18),

            // Plate input with premium styling
            _buildInlinePlateInput(isTablet),

            SizedBox(height: isTablet ? 20 : 16),

            // Emoji selector
            _buildInlineEmojiSelector(isTablet),

            SizedBox(height: isTablet ? 20 : 16),

            // Urgency selector
            _buildInlineUrgencySelector(isTablet),

            SizedBox(height: isTablet ? 24 : 18),

            // Premium send button
            _buildInlineSendButton(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertModeHeader(bool isTablet) {
    final isNotifyMode = _alertModeType == 'i_am_blocking';

    return Row(
      children: [
        // Accent line - different color for notify mode
        Container(
          width: 4,
          height: isTablet ? 28 : 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isNotifyMode
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [PremiumTheme.accentColor, PremiumTheme.accentColor.withValues(alpha: 0.5)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isNotifyMode ? 'Notify Driver' : 'Send Alert',
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.w700,
                      color: PremiumTheme.primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (isNotifyMode) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: PremiumTheme.heroGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PREMIUM',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isNotifyMode
                    ? 'Let them know you parked behind them'
                    : 'Politely notify the driver blocking you',
                style: TextStyle(
                  fontSize: isTablet ? 13 : 12,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.tertiaryTextColor,
                ),
              ),
            ],
          ),
        ),
        // Premium close button
        GestureDetector(
          onTap: _closeAlertMode,
          child: Container(
            width: isTablet ? 40 : 36,
            height: isTablet ? 40 : 36,
            decoration: BoxDecoration(
              color: PremiumTheme.dividerColor.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: PremiumTheme.dividerColor,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.close_rounded,
              size: isTablet ? 22 : 20,
              color: PremiumTheme.secondaryTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlinePlateInput(bool isTablet) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PremiumTheme.backgroundColor.withValues(alpha: 0.8),
            PremiumTheme.backgroundColor.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAlertPlateValid
              ? PremiumTheme.accentColor.withValues(alpha: 0.6)
              : PremiumTheme.dividerColor.withValues(alpha: 0.5),
          width: _isAlertPlateValid ? 2 : 1,
        ),
        boxShadow: _isAlertPlateValid
            ? [
                BoxShadow(
                  color: PremiumTheme.accentColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _alertPlateController,
        focusNode: _alertPlateFocusNode,
        textCapitalization: TextCapitalization.characters,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isTablet ? 26 : 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 4,
          color: PremiumTheme.primaryTextColor,
        ),
        inputFormatters: [
          // Only allow valid plate characters
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s\-]')),
          // Limit to reasonable plate length (including dash)
          LengthLimitingTextInputFormatter(12),
        ],
        decoration: InputDecoration(
          hintText: 'ABC-1234',
          hintStyle: TextStyle(
            fontSize: isTablet ? 26 : 22,
            fontWeight: FontWeight.w400,
            letterSpacing: 4,
            color: PremiumTheme.tertiaryTextColor.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isTablet ? 18 : 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(
              Icons.directions_car_outlined,
              color: _isAlertPlateValid
                  ? PremiumTheme.accentColor
                  : PremiumTheme.tertiaryTextColor,
              size: isTablet ? 24 : 20,
            ),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: isTablet ? 48 : 40,
          ),
        ),
      ),
    );
  }

  Widget _buildInlineEmojiSelector(bool isTablet) {
    final emojis = ['🚗', '🙏', '⏰', '🚨', '😊', '👋'];
    final emojiSize = isTablet ? 44.0 : 40.0;
    final fontSize = isTablet ? 24.0 : 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.emoji_emotions_outlined,
              size: 16,
              color: PremiumTheme.tertiaryTextColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Express yourself',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PremiumTheme.tertiaryTextColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Wrap in scrollable to prevent overflow on small screens
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: emojis.asMap().entries.map((entry) {
              final index = entry.key;
              final emoji = entry.value;
              final isSelected = _alertSelectedEmoji == emoji;
              return Padding(
                padding: EdgeInsets.only(right: index < emojis.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _alertSelectedEmoji = emoji);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: emojiSize,
                    height: emojiSize,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                PremiumTheme.accentColor.withValues(alpha: 0.2),
                                PremiumTheme.accentColor.withValues(alpha: 0.1),
                              ],
                            )
                          : null,
                      color: isSelected ? null : PremiumTheme.backgroundColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? PremiumTheme.accentColor.withValues(alpha: 0.6)
                            : PremiumTheme.dividerColor.withValues(alpha: 0.3),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: PremiumTheme.accentColor.withValues(alpha: 0.15),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: AnimatedScale(
                        scale: isSelected ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: fontSize),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineUrgencySelector(bool isTablet) {
    final urgencyData = [
      {'level': 'Low', 'icon': Icons.schedule, 'color': Colors.green},
      {'level': 'Normal', 'icon': Icons.notifications_outlined, 'color': PremiumTheme.accentColor},
      {'level': 'High', 'icon': Icons.priority_high, 'color': Colors.red},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.speed_outlined,
              size: 16,
              color: PremiumTheme.tertiaryTextColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Urgency level',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PremiumTheme.tertiaryTextColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: urgencyData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final level = data['level'] as String;
            final icon = data['icon'] as IconData;
            final color = data['color'] as Color;
            final isSelected = _alertUrgencyLevel == level;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _alertUrgencyLevel = level);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(
                    right: index < urgencyData.length - 1 ? 8 : 0,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 12 : 10,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withValues(alpha: 0.2),
                              color.withValues(alpha: 0.1),
                            ],
                          )
                        : null,
                    color: isSelected ? null : PremiumTheme.backgroundColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? color.withValues(alpha: 0.5)
                          : PremiumTheme.dividerColor.withValues(alpha: 0.3),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.15),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          icon,
                          size: isTablet ? 20 : 18,
                          color: isSelected ? color : PremiumTheme.tertiaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        level,
                        style: TextStyle(
                          fontSize: isTablet ? 13 : 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? color : PremiumTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInlineSendButton(bool isTablet) {
    final canSend = _isAlertPlateValid && !_isSendingAlert;
    final isNotifyMode = _alertModeType == 'i_am_blocking';
    final buttonColor = isNotifyMode ? Colors.green.shade500 : PremiumTheme.accentColor;

    return GestureDetector(
      onTap: canSend ? _sendInlineAlert : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
        decoration: BoxDecoration(
          gradient: canSend
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    buttonColor,
                    buttonColor.withValues(alpha: 0.85),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PremiumTheme.dividerColor,
                    PremiumTheme.dividerColor.withValues(alpha: 0.8),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: canSend
              ? [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: _isSendingAlert
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated emoji
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _alertSelectedEmoji ?? (isNotifyMode ? '👋' : '🚗'),
                      key: ValueKey(_alertSelectedEmoji),
                      style: TextStyle(fontSize: isTablet ? 20 : 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isNotifyMode ? 'Send Notification' : 'Send Alert',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: canSend ? Colors.white : PremiumTheme.tertiaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: canSend ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isNotifyMode ? Icons.notifications_active_rounded : Icons.send_rounded,
                      size: isTablet ? 18 : 16,
                      color: canSend ? Colors.white : PremiumTheme.tertiaryTextColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Helper class for activity feed items
class _ActivityItem {
  final Alert alert;
  final bool isReceived;
  final DateTime time;

  _ActivityItem({
    required this.alert,
    required this.isReceived,
    required this.time,
  });
}
