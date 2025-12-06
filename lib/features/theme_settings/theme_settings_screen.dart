import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/premium_theme.dart';
import '../../main.dart';

/// Premium theme settings screen
/// Allows users to switch between Light, Dark, and Caribbean Sunset modes
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  String _selectedTheme = PremiumTheme.currentMode;

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
                  fontWeight: FontWeight.w300,
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
  }) {
    final isSelected = _selectedTheme == mode;

    return GestureDetector(
      onTap: () {
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
              ? PremiumTheme.accentColor.withValues(alpha: 0.1)
              : PremiumTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? PremiumTheme.accentColor.withValues(alpha: 0.3)
                : PremiumTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: PremiumTheme.accentColor.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Theme preview circle
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.primaryTextColor,

                    ),
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

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? PremiumTheme.accentColor
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? PremiumTheme.accentColor
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