import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Native splash removed - using custom AppInitializer splash instead
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:shimmer/shimmer.dart';

import 'core/theme/premium_theme.dart';
import 'core/services/plate_storage_service.dart';
import 'core/services/user_stats_service.dart';
import 'core/services/simple_alert_service.dart';
import 'core/services/unacknowledged_alert_service.dart';
import 'core/services/user_alias_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/background_alert_service.dart';
import 'config/premium_config.dart';
import 'features/premium_alert/alert_history_screen.dart';
import 'features/plate_registration/plate_registration_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/theme_settings/theme_settings_screen.dart';
import 'features/subscription/paywall_dialog.dart';
import 'features/subscription/upgrade_screen.dart';
import 'features/subscription/subscription_status_screen.dart';
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

/// Premium splash screen with island-tech aesthetic
/// Brand: "Move with respect." - from DezeTingz
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _exitController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoSlide;
  late Animation<double> _taglineFade;
  late Animation<double> _footerFade;
  late Animation<double> _footerSlide;
  // Exit animations
  late Animation<double> _exitFade;
  late Animation<double> _exitScale;
  bool _goToHome = false;
  bool _showShimmer = false;
  bool _isExiting = false;

  // Brand colors
  static const Color _teal = Color(0xFF0B6E7D);
  static const Color _coral = Color(0xFFFF847C);
  static const Color _deepBlue = Color(0xFF045C71);
  static const Color _softTeal = Color(0xFFE8F6F8);

  // Logo size
  static const double _logoSize = 260.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 900), // Premium timing
      vsync: this,
    );

    // Logo: gentle scale with ease
    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // Logo: fade in first
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Logo: subtle slide up
    _logoSlide = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // Tagline: fade in after logo
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    // Footer: fade in last
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Footer: slide up effect
    _footerSlide = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Exit animation controller
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInCubic,
      ),
    );

    _exitScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInCubic,
      ),
    );

    _controller.forward();

    // Start shimmer after logo fades in
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _showShimmer = true);
      }
    });

    _checkOnboardingStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
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

      // Show splash for 3.5 seconds to display branding properly
      await Future.delayed(const Duration(milliseconds: 3500));

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

  void _navigateToNextScreen() async {
    debugPrint(_goToHome
        ? '✅ AppInitializer: Going to home screen'
        : '🔄 AppInitializer: Going to onboarding');

    // Stop shimmer and play exit animation
    setState(() {
      _showShimmer = false;
      _isExiting = true;
    });

    // Play exit animation
    await _exitController.forward();

    if (!mounted) return;

    // Navigate with seamless transition
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _goToHome
            ? const PremiumHomeScreen()
            : const OnboardingFlow(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Fade in the new screen
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Premium gradient background: white to soft teal
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              _softTeal,
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_controller, _exitController]),
            builder: (context, child) {
              // Apply exit animation when transitioning out
              final exitOpacity = _isExiting ? _exitFade.value : 1.0;
              final exitScale = _isExiting ? _exitScale.value : 1.0;

              return Opacity(
                opacity: exitOpacity,
                child: Transform.scale(
                  scale: exitScale,
                  child: Column(
              children: [
                // Spacer to push logo 20% above center
                const Spacer(flex: 2),

                // Logo - clean without shimmer
                Transform.translate(
                  offset: Offset(0, _logoSlide.value),
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: _logoSize,
                        height: _logoSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Tagline with premium shimmer on text
                FadeTransition(
                  opacity: _taglineFade,
                  child: _showShimmer
                      ? Shimmer.fromColors(
                          baseColor: _deepBlue,
                          highlightColor: _teal.withValues(alpha: 0.7),
                          period: const Duration(milliseconds: 2000),
                          direction: ShimmerDirection.ltr,
                          child: Text(
                            'Move with respect.',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              color: _deepBlue,

                            ),
                          ),
                        )
                      : Text(
                          'Move with respect.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            color: _deepBlue,

                          ),
                        ),
                ),

                // Spacer to balance layout
                const Spacer(flex: 3),

                // Premium footer with slide-up animation
                Transform.translate(
                  offset: Offset(0, _footerSlide.value),
                  child: FadeTransition(
                    opacity: _footerFade,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // "from" with decorative lines
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 0.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      _teal.withValues(alpha: 0.3),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'from',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w300,
                                    color: _teal.withValues(alpha: 0.5),

                                  ),
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 0.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _teal.withValues(alpha: 0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // "DezeTingz" with brand gradient
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [_teal, _coral],
                            ).createShader(bounds),
                            child: const Text(
                              'DezeTingz',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,

                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
                  ),
                ),
              );
            },
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
  final BackgroundAlertService _backgroundAlertService = BackgroundAlertService();
  bool _isOffline = false;
  bool _showOfflineBanner = false;
  bool _isActivityFeedExpanded = true; // Activity feed collapse state

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

    // Initialize background alert service for reliable locked-screen notifications
    try {
      await _backgroundAlertService.initializeService();
      await _backgroundAlertService.startService();
      debugPrint('Background alert service started');
    } catch (e) {
      debugPrint('Background service initialization error: $e');
    }

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

      // Refresh subscription entitlements if needed (hourly check)
      if (_subscriptionService.shouldRefreshEntitlements) {
        unawaited(_subscriptionService.refreshEntitlements());
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
  /// Uses redundant storage and database verification to prevent data loss
  Future<void> _ensureUserExists() async {
    try {
      await _alertService.initialize();

      final prefs = await SharedPreferences.getInstance();

      // Try to get user_id from primary key, fall back to backup key
      String? userId = prefs.getString('user_id');
      final backupUserId = prefs.getString('user_id_backup');

      // If primary is missing but backup exists, restore it
      if (userId == null && backupUserId != null) {
        debugPrint('🔄 Restoring user_id from backup: $backupUserId');
        userId = backupUserId;
        await prefs.setString('user_id', userId);
      }

      // Verify the user exists in database before using it
      if (userId != null) {
        final exists = await _alertService.userExists(userId);
        if (!exists) {
          debugPrint('⚠️ Stored user_id not found in database: $userId');
          // User doesn't exist in DB - might have been deleted or DB was reset
          // Create a new user instead of using invalid ID
          userId = null;
        } else {
          debugPrint('✅ Verified user exists in database: $userId');
        }
      }

      // Create new user only if we don't have a valid one
      if (userId == null) {
        debugPrint('🆕 Creating new user...');
        userId = await _alertService.getOrCreateUser();
        // Store in both primary and backup keys for redundancy
        await prefs.setString('user_id', userId);
        await prefs.setString('user_id_backup', userId);
        debugPrint('✅ New user created and stored: $userId');
      } else {
        // Ensure backup is always in sync
        await prefs.setString('user_id_backup', userId);
      }

      _currentUserId = userId;

      // Initialize subscription service
      await _subscriptionService.initialize(userId);

      // Update background service with user ID for reliable locked-screen alerts
      await _backgroundAlertService.setUserId(userId);
    } catch (e) {
      debugPrint('❌ Failed to ensure user exists: $e');
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

        // Increment "They Moved" counter - someone responded to your alert
        _statsService.incrementSituationsResolved().then((_) {
          _loadUserStats(); // Refresh stats display
        });

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

  /// Show premium animated toast with smooth morph animation
  /// Much more elegant than SnackBar - scales in, holds briefly, fades out
  OverlayEntry? _currentToastEntry;

  void _showPremiumSnackBar({
    required String message,
    bool isSuccess = true,
    Duration? duration,
    IconData? icon,
  }) {
    if (!mounted) return;

    // Remove any existing toast immediately
    _currentToastEntry?.remove();
    _currentToastEntry = null;

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _PremiumToast(
        message: message,
        isSuccess: isSuccess,
        icon: icon,
        screenWidth: screenSize.width,
        bottomPadding: bottomPadding,
        duration: duration ?? const Duration(milliseconds: 1800),
        onDismiss: () {
          entry.remove();
          if (_currentToastEntry == entry) {
            _currentToastEntry = null;
          }
        },
      ),
    );

    _currentToastEntry = entry;
    overlay.insert(entry);
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

            ),
          ),
        ],
      ),
    );
  }

  /// Check if there are any alerts within the recent time threshold (15 minutes)
  bool _hasRecentAlerts() {
    final now = DateTime.now();
    final recentThreshold = now.subtract(const Duration(minutes: 15));

    for (final alert in _recentReceivedAlerts) {
      if (alert.createdAt.isAfter(recentThreshold)) return true;
    }
    for (final alert in _recentSentAlerts) {
      if (alert.createdAt.isAfter(recentThreshold)) return true;
    }
    return false;
  }

  /// Compact recent activity feed for home screen
  /// Only shows alerts from the last 15 minutes - older ones accessible via "See all"
  Widget _buildRecentActivityFeed(bool isTablet) {
    // Time threshold - only show alerts from last 15 minutes on home screen
    final now = DateTime.now();
    final recentThreshold = now.subtract(const Duration(minutes: 15));

    // Combine and sort all alerts by time
    final allAlerts = <_ActivityItem>[];

    for (final alert in _recentReceivedAlerts) {
      // Only include if within time threshold
      if (alert.createdAt.isAfter(recentThreshold)) {
        allAlerts.add(_ActivityItem(
          alert: alert,
          isReceived: true,
          time: alert.createdAt,
        ));
      }
    }

    for (final alert in _recentSentAlerts) {
      // Only include if within time threshold
      if (alert.createdAt.isAfter(recentThreshold)) {
        allAlerts.add(_ActivityItem(
          alert: alert,
          isReceived: false,
          time: alert.createdAt,
        ));
      }
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PremiumTheme.dividerColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact header with collapse toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isActivityFeedExpanded = !_isActivityFeedExpanded);
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: PremiumTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Activity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.primaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Item count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: PremiumTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${displayAlerts.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PremiumTheme.accentColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // See all link (only when expanded) - compact to prevent overflow
                  if (_isActivityFeedExpanded)
                    GestureDetector(
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
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          'All',
                          style: TextStyle(
                            fontSize: 12,
                            color: PremiumTheme.accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // Collapse/expand icon
                  AnimatedRotation(
                    turns: _isActivityFeedExpanded ? 0 : -0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: PremiumTheme.tertiaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated content section - using ClipRect + AnimatedSize to prevent overflow
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isActivityFeedExpanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Divider
                        Container(
                          height: 1,
                          color: PremiumTheme.dividerColor.withValues(alpha: 0.2),
                        ),
                        // Compact alert items
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: displayAlerts.map((item) => _buildActivityItem(item, isTablet)).toList(),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
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

  /// Build a single activity item - compact and clear
  Widget _buildActivityItem(_ActivityItem item, bool isTablet) {
    final alert = item.alert;
    final hasResponse = alert.response != null && alert.response!.isNotEmpty;

    // Check if response was received recently (within 2 minutes) for highlight effect
    final isRecentResponse = hasResponse &&
        alert.responseAt != null &&
        DateTime.now().difference(alert.responseAt!).inMinutes < 2;

    // Determine status colors, text, and icons
    Color statusColor;
    String statusText;
    IconData statusIcon;
    String title;

    if (item.isReceived) {
      // User received alert = Their car is blocking someone else
      if (hasResponse) {
        statusColor = Colors.green;
        statusText = 'Responded';
        statusIcon = Icons.check_circle;
        title = 'You were blocking';
      } else {
        statusColor = Colors.orange;
        statusText = 'Action needed';
        statusIcon = Icons.warning_rounded;
        title = 'You\'re blocking someone';
      }
    } else {
      // User sent alert = Someone else is blocking them
      title = 'Someone blocking you';
      if (hasResponse) {
        switch (alert.response) {
          case 'moving_now':
            statusColor = Colors.green;
            statusText = 'Moving now!';
            statusIcon = Icons.directions_car;
            break;
          case '5_minutes':
            statusColor = Colors.orange;
            statusText = '5 min';
            statusIcon = Icons.timer;
            break;
          case 'cant_move':
            statusColor = Colors.red;
            statusText = "Can't move";
            statusIcon = Icons.block;
            break;
          case 'wrong_car':
            statusColor = Colors.grey;
            statusText = 'Wrong car';
            statusIcon = Icons.error_outline;
            break;
          default:
            statusColor = Colors.green;
            statusText = 'Responded';
            statusIcon = Icons.check_circle;
        }
      } else {
        statusColor = Colors.blue;
        statusText = 'Waiting...';
        statusIcon = Icons.schedule;
      }
    }

    final needsAction = item.isReceived && !hasResponse;

    // Highlight sent alerts with recent responses
    final showResponseHighlight = !item.isReceived && isRecentResponse;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (needsAction) {
            _quickRespondToAlert(alert);
          } else if (_currentUserId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AlertHistoryScreen(userId: _currentUserId!),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: needsAction
                ? Colors.orange.withValues(alpha: 0.08)
                : showResponseHighlight
                    ? statusColor.withValues(alpha: 0.12)
                    : null,
            border: showResponseHighlight
                ? Border(
                    left: BorderSide(
                      color: statusColor,
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.isReceived ? Icons.call_received_rounded : Icons.call_made_rounded,
                  color: statusColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),

              // Content - use Expanded to constrain width
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title row with proper overflow handling
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title takes remaining space, shrinks if needed
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: needsAction ? FontWeight.w700 : FontWeight.w500,
                              color: needsAction ? Colors.orange.shade800 : PremiumTheme.primaryTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        // Fixed-width badges after title
                        if (needsAction) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        // NEW badge for recent responses
                        if (showResponseHighlight) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,

                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatTimeAgo(item.time)} · $statusText',
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              // Action indicator - constrained to prevent overflow
              if (needsAction)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Reply',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 16,
                ),
            ],
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

            // Dismiss the alert banner if it's showing this same alert
            if (_showingAlertBanner && _currentIncomingAlert?.id == alert.id) {
              _alertAutoDismissTimer?.cancel();
              setState(() {
                _showingAlertBanner = false;
                _currentIncomingAlert = null;
                _currentSenderAlias = null;
                _currentAlertEmoji = null;
              });
            }

            // Update the local received alerts list immediately for responsive UI
            setState(() {
              final index = _recentReceivedAlerts.indexWhere((a) => a.id == alert.id);
              if (index != -1) {
                // Create updated alert with response
                final updatedAlert = Alert(
                  id: alert.id,
                  senderId: alert.senderId,
                  receiverId: alert.receiverId,
                  plateHash: alert.plateHash,
                  message: alert.message,
                  response: response,
                  responseMessage: null,
                  createdAt: alert.createdAt,
                  readAt: DateTime.now(),
                  responseAt: DateTime.now(),
                );
                _recentReceivedAlerts[index] = updatedAlert;
              }
            });

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
    final limit = SubscriptionService.freeDailyAlertLimit;

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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SubscriptionStatusScreen(),
          ),
        );
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

                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _primaryPlate!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.primaryTextColor,
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
      // Server-side validation before sending alert
      final validation = await _subscriptionService.validateAlertPermission();

      if (!validation.allowed) {
        // Show paywall if user has reached limit
        if (mounted) {
          setState(() => _isSendingAlert = false);
          PaywallDialog.show(
            context,
            remainingAlerts: validation.remainingAlerts,
            customMessage: validation.userMessage,
          );
        }
        return;
      }

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

          // Close alert mode first, then show toast
          _closeAlertMode();

          // Show premium success toast
          _showPremiumSnackBar(
            message: 'Alert sent successfully',
            isSuccess: true,
            icon: Icons.check_circle_rounded,
            duration: const Duration(milliseconds: 2500),
          );
        } else {
          _showPremiumSnackBar(
            message: result.error ?? 'Failed to send alert',
            isSuccess: false,
            icon: Icons.error_outline_rounded,
            duration: const Duration(milliseconds: 3000),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar(
          message: 'Something went wrong. Try again.',
          isSuccess: false,
          icon: Icons.error_outline_rounded,
          duration: const Duration(milliseconds: 3000),
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

              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 11 : 10,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),

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
    // Count unresponded received alerts (alerts where YOU are blocking someone)
    final unrespondedReceivedCount = _recentReceivedAlerts
        .where((alert) => !alert.hasResponse)
        .length;

    // Total actionable items: sent alerts waiting + received alerts needing response
    final totalActionableCount = _unacknowledgedAlertsCount + unrespondedReceivedCount;
    final hasActionableAlerts = totalActionableCount > 0;

    // Badge should show when there are any actionable alerts
    final showingUrgent = hasActionableAlerts;
    final badgeCount = totalActionableCount;
    final shouldShowBadge = hasActionableAlerts;

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

          ),
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 10 : 12,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.8),

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
        final hasActivityFeed = _hasRecentAlerts();

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

                    // Recent activity feed (only shows last 15 minutes)
                    if (_hasRecentAlerts()) ...[
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

                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'to start receiving alerts',
                  style: TextStyle(
                    fontSize: isTablet ? 13 : 12,
                    fontWeight: FontWeight.w400,
                    color: PremiumTheme.secondaryTextColor,

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
    // IMPORTANT: Include safe area padding for iOS notch/dynamic island
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final iconSpaceHeight = isTablet ? 56 : 48;
    final additionalMargin = isTablet ? 8 : 6;
    final topOffset = safeAreaTop + (iconSpaceHeight + additionalMargin).toDouble();

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
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
                  _showingAlertBanner ? 0 : -200,
                  0,
                ),
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32.0 : 12.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E88E5), // Vibrant blue
                        const Color(0xFF1565C0), // Deeper blue
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Compact header
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isTablet ? 16 : 12,
                          isTablet ? 12 : 10,
                          isTablet ? 12 : 8,
                          8,
                        ),
                        child: Row(
                          children: [
                            // Alert indicator
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.notifications_active_rounded,
                                color: Colors.white,
                                size: isTablet ? 18 : 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Title and message
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (_currentAlertEmoji != null) ...[
                                        Text(
                                          _currentAlertEmoji!,
                                          style: TextStyle(fontSize: isTablet ? 16 : 14),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        'Move Request',
                                        style: TextStyle(
                                          fontSize: isTablet ? 14 : 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,

                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currentSenderAlias != null
                                        ? '${_aliasService.formatAliasForDisplay(_currentSenderAlias!)} needs you to move'
                                        : 'Someone needs you to move',
                                    style: TextStyle(
                                      fontSize: isTablet ? 13 : 11,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Close button
                            GestureDetector(
                              onTap: _dismissCurrentAlert,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: isTablet ? 18 : 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Compact response buttons in single row
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          isTablet ? 12 : 8,
                          0,
                          isTablet ? 12 : 8,
                          isTablet ? 12 : 10,
                        ),
                        child: Row(
                          children: [
                            _buildCompactResponseChip(
                              label: 'Moving',
                              icon: Icons.directions_car_rounded,
                              isPrimary: true,
                              onTap: () => _respondToAlert('moving_now'),
                              isTablet: isTablet,
                            ),
                            const SizedBox(width: 6),
                            _buildCompactResponseChip(
                              label: '5 min',
                              icon: Icons.schedule_rounded,
                              isPrimary: false,
                              onTap: () => _respondToAlert('5_minutes'),
                              isTablet: isTablet,
                            ),
                            const SizedBox(width: 6),
                            _buildCompactResponseChip(
                              label: "Can't",
                              icon: Icons.block_rounded,
                              isPrimary: false,
                              onTap: () => _respondToAlert('cant_move'),
                              isTablet: isTablet,
                            ),
                            const SizedBox(width: 6),
                            _buildCompactResponseChip(
                              label: 'Wrong',
                              icon: Icons.help_outline_rounded,
                              isPrimary: false,
                              onTap: () => _respondToAlert('wrong_car'),
                              isTablet: isTablet,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ), // Closes SafeArea
    ); // Closes Positioned
  }

  /// Response button for the alert banner with visual feedback
  /// Compact response chip for the premium alert banner
  Widget _buildCompactResponseChip({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 8 : 6,
              horizontal: 4,
            ),
            decoration: BoxDecoration(
              color: isPrimary
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: !isPrimary
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: isTablet ? 14 : 12,
                  color: isPrimary
                      ? const Color(0xFF1565C0)
                      : Colors.white,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: isTablet ? 11 : 10,
                      fontWeight: FontWeight.w600,
                      color: isPrimary
                          ? const Color(0xFF1565C0)
                          : Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

/// Premium animated toast widget with smooth morph-like animations
/// Replaces SnackBar for a more elegant, premium feel
class _PremiumToast extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final IconData? icon;
  final double screenWidth;
  final double bottomPadding;
  final Duration duration;
  final VoidCallback onDismiss;

  const _PremiumToast({
    required this.message,
    required this.isSuccess,
    this.icon,
    required this.screenWidth,
    required this.bottomPadding,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_PremiumToast> createState() => _PremiumToastState();
}

class _PremiumToastState extends State<_PremiumToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Scale: starts small, grows to full size, then shrinks on exit
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Fade: fades in, holds, fades out
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_controller);

    // Slide: subtle upward drift
    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 20.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -10.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Start animation and auto-dismiss
    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = widget.screenWidth > 600;

    return Positioned(
      bottom: widget.bottomPadding + (isTablet ? 40 : 32),
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
          );
        },
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 24),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 14 : 12,
              ),
              decoration: BoxDecoration(
                color: widget.isSuccess
                    ? PremiumTheme.accentColor
                    : Colors.red.shade600,
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isSuccess
                            ? PremiumTheme.accentColor
                            : Colors.red)
                        .withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated check/error icon
                  Container(
                    width: isTablet ? 28 : 24,
                    height: isTablet ? 28 : 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon ??
                          (widget.isSuccess
                              ? Icons.check_rounded
                              : Icons.close_rounded),
                      size: isTablet ? 16 : 14,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: isTablet ? 12 : 10),
                  // Message text
                  Flexible(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,

                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
