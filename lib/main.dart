import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/premium_theme.dart';
import 'core/services/plate_storage_service.dart';
import 'core/services/user_stats_service.dart';
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
  String? _primaryPlate;
  UserStats _userStats = UserStats(carsFreed: 0, situationsResolved: 0);

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

    // Load primary license plate and user stats
    _loadPrimaryPlate();
    _loadUserStats();
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

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 80.0 : 32.0,
            vertical: 60.0,
          ),
          child: Column(
            children: [
              // Subtle app identity
              _buildAppHeader(theme, isTablet),

              const SizedBox(height: 32),

              // Premium user stats counters
              _buildStatsCounters(isTablet),

              // Flexible space to center the hero button
              const Expanded(flex: 2, child: SizedBox()),

              // Hero button - the centerpiece
              _buildHeroButton(theme, isTablet),

              // Active vehicle display
              if (_primaryPlate != null)
                _buildActiveVehicleDisplay(isTablet),

              // Flexible space below
              const Expanded(flex: 2, child: SizedBox()),

              // Settings access - dual buttons
              _buildSettingsRow(),

              const SizedBox(height: 24),

              // Minimal footer
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
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
                PremiumTheme.surfaceColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: PremiumTheme.mediumRadius,
            boxShadow: [
              BoxShadow(
                color: PremiumTheme.accentColor.withValues(alpha: 0.08),
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
                PremiumTheme.accentColor.withValues(alpha: 0.03),
                PremiumTheme.accentColor.withValues(alpha: 0.06),
                PremiumTheme.accentColor.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: PremiumTheme.accentColor.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Text(
            'Respectful parking solutions',
            style: TextStyle(
              fontSize: isTablet ? 17 : 15,
              fontWeight: FontWeight.w400,
              color: PremiumTheme.secondaryTextColor.withValues(alpha: 0.9),
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
                    PremiumTheme.accentColor.withValues(alpha: 0.8),
                  ],
                ),
                boxShadow: [
                  // Main shadow
                  BoxShadow(
                    color: PremiumTheme.accentColor.withValues(alpha: 0.25),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                    spreadRadius: _isPressed ? 2 : 8,
                  ),
                  // Subtle glow effect
                  BoxShadow(
                    color: PremiumTheme.accentColor.withValues(
                      alpha: 0.1 + (_glowAnimation.value * 0.15)
                    ),
                    blurRadius: 60,
                    offset: const Offset(0, 8),
                    spreadRadius: _isPressed ? 10 : 20,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.05),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with subtle animation
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: Matrix4.identity()
                          ..setTranslationRaw(0.0, _isPressed ? 2.0 : 0.0, 0.0),
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
                PremiumTheme.accentColor.withValues(alpha: 0.0),
                PremiumTheme.accentColor.withValues(alpha: 0.4),
                PremiumTheme.accentColor.withValues(alpha: 0.0),
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
          label: 'Plates',
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
        children: [
          // Cars Freed Counter
          _buildCompactStatCounterWithEmoji(
            count: _userStats.carsFreed,
            label: 'Freed',
            emoji: '🤦‍♀️',
            color: PremiumTheme.accentColor,
            isTablet: isTablet,
          ),

          // Subtle divider
          Container(
            width: 0.5,
            height: isTablet ? 24 : 20,
            color: PremiumTheme.accentColor.withValues(alpha: 0.1),
          ),

          // Situations Resolved Counter
          _buildCompactStatCounter(
            count: _userStats.situationsResolved,
            label: 'Resolved',
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
          color: color.withValues(alpha: 0.7),
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
}
