import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'core/theme/premium_theme.dart';
import 'core/services/plate_storage_service.dart';
import 'core/services/user_stats_service.dart';
import 'core/services/simple_alert_service.dart';
import 'config/premium_config.dart';
import 'features/premium_alert/alert_workflow_screen.dart';
import 'features/plate_registration/plate_registration_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/theme_settings/theme_settings_screen.dart';

/// Premium flagship-quality Yuh Blockin' app
/// Inspired by Uber, Airbnb, Apple Human Interface guidelines
/// Minimal, elegant, professional with subtle 2025 motion signature
void main() {
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
            home: const OnboardingFlow(),
          );
        },
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
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  final PlateStorageService _plateStorageService = PlateStorageService();
  final UserStatsService _statsService = UserStatsService();
  final SimpleAlertService _alertService = SimpleAlertService();
  String? _primaryPlate;
  UserStats _userStats = UserStats(carsFreed: 0, situationsResolved: 0);

  // Alert notification system
  String? _currentUserId;
  StreamSubscription<Alert>? _alertStreamSubscription;
  Alert? _currentIncomingAlert;
  bool _showingAlertBanner = false;

  @override
  void initState() {
    super.initState();

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

    _breathingController.repeat(reverse: true);

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

    // Step 3: Initialize alert system (user ID is now guaranteed to exist)
    _initializeAlertSystem();
  }

  // Load user's primary license plate
  Future<void> _loadPrimaryPlate() async {
    try {
      final primaryPlate = await _plateStorageService.getPrimaryPlate();
      if (mounted) {
        setState(() {
          _primaryPlate = primaryPlate;
        });
      }
    } catch (e) {
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

      print('📱 Alert system initialized for user: $_currentUserId');
    } catch (e) {
      print('❌ Failed to initialize alert system: $e');
    }
  }

  /// Start listening for real-time incoming alerts
  void _startListeningForAlerts() {
    if (_currentUserId == null) return;

    try {
      _alertStreamSubscription = _alertService
          .getAlertsStream(_currentUserId!)
          .listen(
        (alert) {
          print('🔔 Received incoming alert: ${alert.id}');
          _handleIncomingAlert(alert);
        },
        onError: (error) {
          print('❌ Alert stream error: $error');
        },
      );
    } catch (e) {
      print('❌ Failed to start alert listening: $e');
    }
  }

  /// Handle incoming alert with premium notification
  void _handleIncomingAlert(Alert alert) {
    if (!mounted) return;

    setState(() {
      _currentIncomingAlert = alert;
      _showingAlertBanner = true;
    });

    // Premium haptic feedback
    HapticFeedback.heavyImpact();

    // Auto-hide banner after 10 seconds if not interacted with
    Timer(const Duration(seconds: 10), () {
      if (mounted && _showingAlertBanner && _currentIncomingAlert?.id == alert.id) {
        setState(() {
          _showingAlertBanner = false;
        });
      }
    });
  }

  /// Respond to alert with acknowledgment
  Future<void> _respondToAlert(String response) async {
    if (_currentIncomingAlert == null) return;

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
        });

        print('✅ Responded to alert: $response');

        // Show confirmation snackbar with better response text
        if (mounted) {
          final responseText = _getResponseDisplayText(response);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Response sent: $responseText'),
              backgroundColor: PremiumTheme.accentColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to send response');
      }
    } catch (e) {
      print('❌ Failed to respond to alert: $e');

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send response. Please try again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
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

  @override
  void dispose() {
    _breathingController.dispose();
    _alertStreamSubscription?.cancel();
    super.dispose();
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
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: PremiumTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Exit Yuh Blockin?',
                style: TextStyle(
                  color: PremiumTheme.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Are you sure you want to exit the app?',
                style: TextStyle(color: PremiumTheme.primaryTextColor.withOpacity(0.8)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: TextStyle(color: PremiumTheme.primaryTextColor)),
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
          // Main content
          SafeArea(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 80.0 : 32.0,
                vertical: isTablet ? 60.0 : 50.0,
              ),
              child: Column(
                children: [
                  // Subtle app identity
                  _buildAppHeader(theme, isTablet),

                  SizedBox(height: isTablet ? 32 : 24),

                  // Premium user stats counters
                  _buildStatsCounters(isTablet),

                  // Adaptive flexible space - reduced when vehicle display is present
                  Expanded(
                    flex: _primaryPlate != null ? 1 : 2,
                    child: const SizedBox(),
                  ),

                  // Hero button - the centerpiece
                  _buildHeroButton(theme, isTablet),

                  // Active vehicle display (conditional)
                  if (_primaryPlate != null) ...[
                    const SizedBox(height: 16),
                    _buildActiveVehicleDisplay(isTablet),
                  ],

                  // Adaptive flexible space below
                  Expanded(
                    flex: _primaryPlate != null ? 1 : 2,
                    child: const SizedBox(),
                  ),

                  // Minimal footer
                  _buildFooter(theme),

                  SizedBox(height: isTablet ? 24 : 16),

                  // Settings access - dual buttons
                  _buildSettingsRow(),
                ],
              ),
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
    return Column(
      children: [
        // Enhanced app wordmark with premium styling
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PremiumTheme.surfaceColor,
                PremiumTheme.surfaceColor.withOpacity(0.8),
              ],
            ),
            borderRadius: PremiumTheme.mediumRadius,
            boxShadow: [
              BoxShadow(
                color: PremiumTheme.accentColor.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            PremiumConfig.appName,
            style: TextStyle(
              fontSize: isTablet ? 32 : 28,
              fontWeight: FontWeight.w200, // Ultra-light for premium elegance
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 1.2, // Increased letter spacing for premium feel
              height: 1.1,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Premium tagline with enhanced blend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PremiumTheme.accentColor.withOpacity(0.03),
                PremiumTheme.accentColor.withOpacity(0.06),
                PremiumTheme.accentColor.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: PremiumTheme.accentColor.withOpacity(0.08),
              width: 0.5,
            ),
          ),
          child: Text(
            'Respectful parking solutions',
            style: TextStyle(
              fontSize: isTablet ? 17 : 15,
              fontWeight: FontWeight.w400,
              color: PremiumTheme.secondaryTextColor.withOpacity(0.9),
              letterSpacing: 0.5,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroButton(ThemeData theme, bool isTablet) {
    final buttonSize = isTablet ? 280.0 : 240.0;

    return GestureDetector(
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
      child: AnimatedBuilder(
        animation: _breathingAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isPressed ? 0.97 : _breathingAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PremiumTheme.accentColor,
                    PremiumTheme.accentColor.withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  // Main shadow
                  BoxShadow(
                    color: PremiumTheme.accentColor.withOpacity(0.25),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                    spreadRadius: _isPressed ? 2 : 8,
                  ),
                  // Subtle glow effect
                  BoxShadow(
                    color: PremiumTheme.accentColor.withOpacity(
                      0.1 + (_glowAnimation.value * 0.15)
                    ),
                    blurRadius: 60,
                    offset: const Offset(0, 8),
                    spreadRadius: _isPressed ? 10 : 20,
                  ),
                ],
              ),
              child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with subtle animation
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: Matrix4.identity()
                          ..translate(0.0, _isPressed ? 2.0 : 0.0),
                        child: Icon(
                          Icons.notifications_outlined,
                          size: isTablet ? 48 : 40,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 12),

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
              ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      children: [
        // Elegant minimal status indicator
        Container(
          height: 2,
          width: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PremiumTheme.accentColor.withOpacity(0.0),
                PremiumTheme.accentColor.withOpacity(0.4),
                PremiumTheme.accentColor.withOpacity(0.0),
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),

        const SizedBox(height: 24),

        // DezeTingz branding
        Text(
          'DezeTingz © 2026',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: PremiumTheme.tertiaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveVehicleDisplay(bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isTablet ? 32.0 : 24.0,
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
                    SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: PremiumTheme.standardCurve,
                  )),
                  child: const ThemeSettingsScreen(),
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
          onTap: () {
            HapticFeedback.lightImpact();
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
            );
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
          // Cars Freed Counter
          _buildCompactStatCounterWithEmoji(
            count: _userStats.carsFreed,
            label: 'Times Blocked',
            emoji: '🤦‍♀️',
            color: PremiumTheme.accentColor,
            isTablet: isTablet,
          ),

          // Subtle divider
          Container(
            width: 0.5,
            height: isTablet ? 24 : 20,
            color: PremiumTheme.accentColor.withOpacity(0.1),
          ),

          // Situations Resolved Counter
          _buildCompactStatCounter(
            count: _userStats.situationsResolved,
            label: 'Times Unblocked',
            icon: Icons.check_circle_outline,
            color: Colors.green.shade600,
            isTablet: isTablet,
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
          crossAxisAlignment: CrossAxisAlignment.start,
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

  void _showMinimalDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => AlertDialog(
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  /// Premium incoming alert notification banner
  Widget _buildIncomingAlertBanner(bool isTablet) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          transform: Matrix4.translationValues(
            0,
            _showingAlertBanner ? 0 : -200,
            0,
          ),
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isTablet ? 40.0 : 16.0,
              vertical: 16.0,
            ),
            padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PremiumTheme.accentColor,
                  PremiumTheme.accentColor.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: PremiumTheme.accentColor.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
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
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _showingAlertBanner = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Alert message
                Text(
                  'Someone needs you to move your car',
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
          ),
        ),
      ),
    );
  }

  /// Response button for the alert banner
  Widget _buildResponseButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 12.0 : 10.0,
          horizontal: isTablet ? 16.0 : 12.0,
        ),
        decoration: BoxDecoration(
          color: isPrimary
              ? Colors.white
              : Colors.white.withOpacity(0.15),
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
              color: isPrimary
                  ? PremiumTheme.accentColor
                  : Colors.white,
              size: isTablet ? 16 : 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isTablet ? 13 : 12,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? PremiumTheme.accentColor
                      : Colors.white,
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
    );
  }
}