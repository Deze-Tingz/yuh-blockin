import 'dart:io';
import 'package:flutter/material.dart';

/// Premium theme system inspired by Apple, Uber, Airbnb design languages
/// Professional, minimal, with subtle 2025 glow signature
///
/// iOS Letter Spacing Fix:
/// Flutter Issue #150824 - text rendering differs from iOS native.
/// Solution: Use CupertinoSystemDisplay font + Apple's official letterSpacing values
/// from Flutter's cupertino/text_theme.dart
class PremiumTheme {
  // MARK: - iOS-Native Typography Helpers

  /// Check if running on iOS
  static bool get isIOS => Platform.isIOS;

  /// iOS font family - uses CupertinoSystemDisplay for proper SF Pro rendering
  /// This fixes Flutter's default which incorrectly uses SF Pro Text for all sizes
  /// Reference: https://github.com/flutter/flutter/issues/150824
  static String? get _iosFontFamily => isIOS ? 'CupertinoSystemDisplay' : null;

  /// Apple's official letter spacing values from Flutter's cupertino/text_theme.dart
  /// These match iOS native text rendering exactly
  static double _appleLetterSpacing(double fontSize) {
    if (!isIOS) return 0.0;

    // Values from Flutter's official Cupertino theme (iOS 14+ specs)
    if (fontSize >= 34) return 0.38;      // Large title
    if (fontSize >= 28) return 0.36;      // Title 1
    if (fontSize >= 22) return -0.26;     // Title 2
    if (fontSize >= 21) return -0.6;      // Picker text
    if (fontSize >= 20) return -0.45;     // Title 3
    if (fontSize >= 17) return -0.41;     // Body/Headline
    if (fontSize >= 16) return -0.32;     // Callout
    if (fontSize >= 15) return -0.23;     // Subhead
    if (fontSize >= 13) return -0.08;     // Footnote
    if (fontSize >= 12) return 0.0;       // Caption 1
    if (fontSize >= 11) return 0.07;      // Caption 2
    if (fontSize >= 10) return -0.24;     // Tab label
    return 0.0;
  }
  // MARK: - Premium Theme Modes

  /// Theme mode enumeration
  static const String lightMode = 'light';
  static const String darkMode = 'dark';
  static const String sunsetMode = 'caribbean_sunset';
  static const String pinkMode = 'premium_pink';       // Premium theme
  static const String cyberpunkMode = 'cyberpunk';     // Premium theme

  /// Premium-only themes (require subscription)
  static const List<String> premiumThemes = [pinkMode, cyberpunkMode];

  /// Check if a theme requires premium subscription
  static bool isPremiumTheme(String mode) => premiumThemes.contains(mode);

  // MARK: - Light Theme Colors

  /// Light mode - Soft neutral background - almost white with warmth
  static const Color lightBackgroundColor = Color(0xFFFCFCFC);
  static const Color lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color lightAccentColor = Color(0xFF0A84FF); // Apple system blue refined
  static const Color lightPrimaryTextColor = Color(0xFF1C1C1E);
  static const Color lightSecondaryTextColor = Color(0xFF8E8E93);
  static const Color lightTertiaryTextColor = Color(0xFFC7C7CC);
  static const Color lightDividerColor = Color(0xFFE5E5EA);

  // MARK: - Dark Theme Colors

  /// Dark mode - Deep sophisticated blacks and grays
  static const Color darkBackgroundColor = Color(0xFF000000);
  static const Color darkSurfaceColor = Color(0xFF1C1C1E);
  static const Color darkAccentColor = Color(0xFF0A84FF); // Same blue works well in dark
  static const Color darkPrimaryTextColor = Color(0xFFFFFFFF);
  static const Color darkSecondaryTextColor = Color(0xFF8E8E93);
  static const Color darkTertiaryTextColor = Color(0xFF48484A);
  static const Color darkDividerColor = Color(0xFF38383A);

  // MARK: - Caribbean Sunset Theme Colors

  /// Caribbean sunset mode - Warm golden hour vibes with island sunset colors
  static const Color sunsetBackgroundColor = Color(0xFF2D1B14); // Deep sunset brown
  static const Color sunsetSurfaceColor = Color(0xFF3D2A1F); // Warm surface
  static const Color sunsetAccentColor = Color(0xFFFF8C42); // Bright sunset orange
  static const Color sunsetPrimaryTextColor = Color(0xFFFFF5E6); // Warm white
  static const Color sunsetSecondaryTextColor = Color(0xFFE6C9A8); // Sunset beige
  static const Color sunsetTertiaryTextColor = Color(0xFFBF9F7A); // Muted sunset
  static const Color sunsetDividerColor = Color(0xFF4D3426); // Sunset brown divider

  // MARK: - Premium Pink Theme Colors

  /// Premium Pink mode - Elegant rose and blush tones with luxurious feel
  static const Color pinkBackgroundColor = Color(0xFF1A1218); // Deep rose black
  static const Color pinkSurfaceColor = Color(0xFF2A1F26); // Rich plum surface
  static const Color pinkAccentColor = Color(0xFFFF6B9D); // Vibrant hot pink
  static const Color pinkPrimaryTextColor = Color(0xFFFFF0F5); // Lavender blush
  static const Color pinkSecondaryTextColor = Color(0xFFE8B4C8); // Muted rose
  static const Color pinkTertiaryTextColor = Color(0xFFB87D98); // Dusty pink
  static const Color pinkDividerColor = Color(0xFF3D2A35); // Rose divider

  // MARK: - Cyberpunk Theme Colors

  /// Cyberpunk mode - Neon-infused dark theme with electric accents
  static const Color cyberpunkBackgroundColor = Color(0xFF0A0A12); // Deep cyber black
  static const Color cyberpunkSurfaceColor = Color(0xFF12121C); // Dark tech surface
  static const Color cyberpunkAccentColor = Color(0xFF00F5FF); // Electric cyan
  static const Color cyberpunkSecondaryAccent = Color(0xFFFF00FF); // Neon magenta
  static const Color cyberpunkPrimaryTextColor = Color(0xFFE0F7FA); // Ice white
  static const Color cyberpunkSecondaryTextColor = Color(0xFF7DD3E8); // Cyber blue
  static const Color cyberpunkTertiaryTextColor = Color(0xFF4A6670); // Muted steel
  static const Color cyberpunkDividerColor = Color(0xFF1A1A2E); // Neon dark divider

  // MARK: - Dynamic Color System

  /// Current theme mode
  static String _currentMode = lightMode;

  /// Get colors based on current theme mode
  static Color get backgroundColor {
    switch (_currentMode) {
      case darkMode:
        return darkBackgroundColor;
      case sunsetMode:
        return sunsetBackgroundColor;
      case pinkMode:
        return pinkBackgroundColor;
      case cyberpunkMode:
        return cyberpunkBackgroundColor;
      default:
        return lightBackgroundColor;
    }
  }

  static Color get surfaceColor {
    switch (_currentMode) {
      case darkMode:
        return darkSurfaceColor;
      case sunsetMode:
        return sunsetSurfaceColor;
      case pinkMode:
        return pinkSurfaceColor;
      case cyberpunkMode:
        return cyberpunkSurfaceColor;
      default:
        return lightSurfaceColor;
    }
  }

  static Color get accentColor {
    switch (_currentMode) {
      case darkMode:
        return darkAccentColor;
      case sunsetMode:
        return sunsetAccentColor;
      case pinkMode:
        return pinkAccentColor;
      case cyberpunkMode:
        return cyberpunkAccentColor;
      default:
        return lightAccentColor;
    }
  }

  static Color get primaryTextColor {
    switch (_currentMode) {
      case darkMode:
        return darkPrimaryTextColor;
      case sunsetMode:
        return sunsetPrimaryTextColor;
      case pinkMode:
        return pinkPrimaryTextColor;
      case cyberpunkMode:
        return cyberpunkPrimaryTextColor;
      default:
        return lightPrimaryTextColor;
    }
  }

  static Color get secondaryTextColor {
    switch (_currentMode) {
      case darkMode:
        return darkSecondaryTextColor;
      case sunsetMode:
        return sunsetSecondaryTextColor;
      case pinkMode:
        return pinkSecondaryTextColor;
      case cyberpunkMode:
        return cyberpunkSecondaryTextColor;
      default:
        return lightSecondaryTextColor;
    }
  }

  static Color get tertiaryTextColor {
    switch (_currentMode) {
      case darkMode:
        return darkTertiaryTextColor;
      case sunsetMode:
        return sunsetTertiaryTextColor;
      case pinkMode:
        return pinkTertiaryTextColor;
      case cyberpunkMode:
        return cyberpunkTertiaryTextColor;
      default:
        return lightTertiaryTextColor;
    }
  }

  static Color get dividerColor {
    switch (_currentMode) {
      case darkMode:
        return darkDividerColor;
      case sunsetMode:
        return sunsetDividerColor;
      case pinkMode:
        return pinkDividerColor;
      case cyberpunkMode:
        return cyberpunkDividerColor;
      default:
        return lightDividerColor;
    }
  }

  // MARK: - Typography System

  /// Premium font family - system font optimized for each platform
  static const String? fontFamily = null; // Use platform default fonts (Roboto on Android, SF Pro on iOS, Segoe UI on Windows)

  // MARK: - Spacing System

  /// Base unit for consistent spacing
  static const double baseUnit = 8.0;

  /// Common spacing values
  static double space(double multiplier) => baseUnit * multiplier;

  // MARK: - Accessibility & Text Scaling

  /// Clamp text scale factor for better accessibility while preventing layout breaks
  /// Allows scaling up to 2x for accessibility but prevents extreme scaling that breaks UI
  static double clampTextScale(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaler.scale(1.0);
    return textScaleFactor.clamp(0.8, 2.0);
  }

  /// Get responsive font size that scales with accessibility settings but stays within bounds
  static double responsiveFontSize(BuildContext context, double baseFontSize) {
    final clampedScale = clampTextScale(context);
    return baseFontSize * clampedScale;
  }

  // MARK: - Theme Switching

  /// Set the current theme mode
  static void setThemeMode(String mode) {
    _currentMode = mode;
  }

  /// Get current theme mode
  static String get currentMode => _currentMode;

  /// Get brightness for current theme
  static Brightness get currentBrightness {
    if (_currentMode == darkMode ||
        _currentMode == sunsetMode ||
        _currentMode == pinkMode ||
        _currentMode == cyberpunkMode) {
      return Brightness.dark;
    }
    return Brightness.light;
  }

  // MARK: - Theme Configuration

  static ThemeData get currentTheme {
    // Use CupertinoSystemDisplay on iOS for proper SF Pro rendering
    final fontFamilyToUse = _iosFontFamily ?? fontFamily;

    return ThemeData(
      useMaterial3: false, // Material2 for consistent text rendering across iOS/Android
      fontFamily: fontFamilyToUse,

      // Font fallbacks for emoji support across all platforms
      // This prevents the "missing Noto fonts" error for emoji characters
      fontFamilyFallback: const <String>[
        'Noto Color Emoji',
        'Apple Color Emoji',
        'Segoe UI Emoji',
        'Segoe UI Symbol',
        'Noto Sans Symbols',
      ],

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: currentBrightness,
        surface: surfaceColor,
      ),

      // Background
      scaffoldBackgroundColor: backgroundColor,

      // Text Theme - Uses Apple's official letter spacing values on iOS
      // Reference: Flutter's cupertino/text_theme.dart
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: primaryTextColor,
          fontFamily: fontFamilyToUse,
          letterSpacing: _appleLetterSpacing(34),
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: primaryTextColor,
          fontFamily: fontFamilyToUse,
          letterSpacing: _appleLetterSpacing(28),
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w400,
          color: primaryTextColor,
          fontFamily: fontFamilyToUse,
          letterSpacing: _appleLetterSpacing(22),
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: primaryTextColor,
          fontFamily: fontFamilyToUse,
          letterSpacing: _appleLetterSpacing(20),
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
          fontFamily: fontFamilyToUse,
          letterSpacing: _appleLetterSpacing(17),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primaryTextColor,
          fontFamily: fontFamilyToUse,
          letterSpacing: _appleLetterSpacing(16),
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: primaryTextColor,
          fontFamily: fontFamilyToUse,
          letterSpacing: _appleLetterSpacing(17),
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: secondaryTextColor,
          fontFamily: fontFamilyToUse,
          letterSpacing: _appleLetterSpacing(15),
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: tertiaryTextColor,
          fontFamily: fontFamilyToUse,
          letterSpacing: _appleLetterSpacing(13),
        ),
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,

          color: primaryTextColor,
        ),
        iconTheme: IconThemeData(color: primaryTextColor),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,

          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,

          ),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 0.5,
        space: 1,
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: primaryTextColor,
        size: 24,
      ),
    );
  }

  // MARK: - Motion Constants

  /// Standard duration for micro-interactions
  static const Duration fastDuration = Duration(milliseconds: 150);

  /// Standard duration for transitions
  static const Duration mediumDuration = Duration(milliseconds: 200);

  /// Standard duration for page transitions
  static const Duration slowDuration = Duration(milliseconds: 250);

  /// Breathing animation duration for hero elements
  static const Duration breathingDuration = Duration(seconds: 4);

  // MARK: - Curves

  /// Standard easing for interactive elements
  static const Curve standardCurve = Curves.easeOut;

  /// Smooth easing for breathing animations
  static const Curve breathingCurve = Curves.easeInOut;

  /// Gentle bounce for satisfying interactions
  static const Curve bounceCurve = Curves.elasticOut;

  // MARK: - Shadow Styles

  /// Subtle elevation for cards
  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
      ];

  /// Medium elevation for elevated elements
  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  /// Strong elevation for hero elements
  static List<BoxShadow> get strongShadow => [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.25),
          blurRadius: 32,
          offset: const Offset(0, 16),
          spreadRadius: 8,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 48,
          offset: const Offset(0, 24),
          spreadRadius: 0,
        ),
      ];

  // MARK: - Gradient Styles

  /// Subtle gradient overlay for depth
  static LinearGradient get subtleOverlay => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  /// Hero button gradient
  static LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accentColor,
          accentColor.withValues(alpha: 0.8),
        ],
      );

  // MARK: - Border Radius

  /// Small radius for subtle rounding
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));

  /// Medium radius for cards and buttons
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(12));

  /// Large radius for hero elements
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(16));

  /// Extra large radius for special elements
  static const BorderRadius extraLargeRadius = BorderRadius.all(Radius.circular(24));
}