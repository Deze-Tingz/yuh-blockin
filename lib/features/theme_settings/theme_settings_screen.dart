import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/premium_theme.dart';
import '../../main.dart';

/// Premium theme settings screen
/// Allows users to switch between Light, Dark, Caribbean Sunset, and Premium themes
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  String _selectedTheme = PremiumTheme.currentMode;
  bool _isPremiumUser = false;

  // TESTING: Set to true to bypass premium check for testing
  static const bool _bypassPremiumForTesting = true;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    // TODO: Replace with actual subscription check
    // For now, check if user has a stored premium flag or use testing bypass
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool('is_premium_user') ?? false;
    setState(() {
      _isPremiumUser = isPremium || _bypassPremiumForTesting;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: PremiumTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: PremiumTheme.primaryTextColor,
          ),
        ),
        title: Text(
          'Theme Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: PremiumTheme.primaryTextColor,

          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Choose Your Vibe',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the perfect theme mode for your experience',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 32),

              // Theme options
              _buildThemeOption(
                mode: PremiumTheme.lightMode,
                title: 'Light Mode',
                subtitle: 'Clean, minimal, and crisp',
                icon: Icons.wb_sunny_outlined,
                primaryColor: const Color(0xFF0A84FF),
                backgroundColor: const Color(0xFFFCFCFC),
                textColor: const Color(0xFF1C1C1E),
              ),

              const SizedBox(height: 16),

              _buildThemeOption(
                mode: PremiumTheme.darkMode,
                title: 'Dark Mode',
                subtitle: 'Sophisticated and elegant',
                icon: Icons.dark_mode_outlined,
                primaryColor: const Color(0xFF0A84FF),
                backgroundColor: const Color(0xFF000000),
                textColor: const Color(0xFFFFFFFF),
              ),

              const SizedBox(height: 16),

              _buildThemeOption(
                mode: PremiumTheme.sunsetMode,
                title: 'Caribbean Sunset',
                subtitle: 'Warm golden hour vibes',
                icon: Icons.wb_twilight_outlined,
                primaryColor: const Color(0xFFFF8C42),
                backgroundColor: const Color(0xFF2D1B14),
                textColor: const Color(0xFFFFF5E6),
              ),

              const SizedBox(height: 24),

              // Premium themes section header
              Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 18,
                    color: PremiumTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Premium Themes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildThemeOption(
                mode: PremiumTheme.pinkMode,
                title: 'Premium Pink',
                subtitle: 'Elegant rose & blush tones',
                icon: Icons.favorite_outline_rounded,
                primaryColor: const Color(0xFFFF6B9D),
                backgroundColor: const Color(0xFF1A1218),
                textColor: const Color(0xFFFFF0F5),
                isPremiumTheme: true,
              ),

              const SizedBox(height: 16),

              _buildThemeOption(
                mode: PremiumTheme.cyberpunkMode,
                title: 'Cyberpunk',
                subtitle: 'Neon-infused electric vibes',
                icon: Icons.bolt_rounded,
                primaryColor: const Color(0xFF00F5FF),
                backgroundColor: const Color(0xFF0A0A12),
                textColor: const Color(0xFFE0F7FA),
                isPremiumTheme: true,
                secondaryColor: const Color(0xFFFF00FF),
              ),

              const Spacer(),

              // Footer with DezeTingz branding
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 1,
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PremiumTheme.accentColor.withValues(alpha: 0.0),
                            PremiumTheme.accentColor.withValues(alpha: 0.3),
                            PremiumTheme.accentColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'DezeTingz © 2026',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: PremiumTheme.tertiaryTextColor,

                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required Color backgroundColor,
    required Color textColor,
    bool isPremiumTheme = false,
    Color? secondaryColor,
  }) {
    final isSelected = _selectedTheme == mode;
    final isLocked = isPremiumTheme && !_isPremiumUser;

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          // Show premium required message
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 12),
                  Text('Subscribe to unlock premium themes'),
                ],
              ),
              backgroundColor: primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        HapticFeedback.lightImpact();
        setState(() {
          _selectedTheme = mode;
        });

        // Update global theme using Provider
        context.read<ThemeNotifier>().setTheme(mode);

        // Brief delay for user feedback then pop
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? (isPremiumTheme ? primaryColor.withValues(alpha: 0.15) : PremiumTheme.accentColor.withValues(alpha: 0.1))
              : PremiumTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isPremiumTheme ? primaryColor.withValues(alpha: 0.4) : PremiumTheme.accentColor.withValues(alpha: 0.3))
                : PremiumTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isPremiumTheme ? primaryColor : PremiumTheme.accentColor).withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Theme preview circle with optional gradient for cyberpunk
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  if (secondaryColor != null)
                    BoxShadow(
                      color: secondaryColor.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(-4, 0),
                    ),
                ],
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 28,
              ),
            ),

            const SizedBox(width: 16),

            // Theme info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: PremiumTheme.primaryTextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPremiumTheme) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor,
                                secondaryColor ?? primaryColor.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
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
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: PremiumTheme.secondaryTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Selection indicator or lock icon
            if (isLocked)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PremiumTheme.tertiaryTextColor.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: PremiumTheme.tertiaryTextColor,
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (isPremiumTheme ? primaryColor : PremiumTheme.accentColor)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? (isPremiumTheme ? primaryColor : PremiumTheme.accentColor)
                        : PremiumTheme.tertiaryTextColor,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}