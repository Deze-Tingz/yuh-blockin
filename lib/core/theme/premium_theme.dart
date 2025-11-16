import 'package:flutter/material.dart';

/// Premium theme system inspired by Apple, Uber, Airbnb design languages
/// Professional, minimal, with subtle 2025 glow signature
class PremiumTheme {
  // MARK: - Premium Theme Modes

  /// Theme mode enumeration
  static const String lightMode = 'light';
  static const String darkMode = 'dark';
  static const String sunsetMode = 'caribbean_sunset';

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
    if (_currentMode == darkMode || _currentMode == sunsetMode) {
      return Brightness.dark;
    }
    return Brightness.light;
  }

  // MARK: - Theme Configuration

  static ThemeData get currentTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: currentBrightness,
        surface: surfaceColor,
        background: backgroundColor,
      ),

      // Background
      scaffoldBackgroundColor: backgroundColor,

      // Text Theme - Clean, elevated, minimal
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w300, // Light for elegance
          letterSpacing: -0.5,
          height: 1.2,
          color: primaryTextColor,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w300,
          letterSpacing: -0.3,
          height: 1.25,
          color: primaryTextColor,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.0,
          height: 1.3,
          color: primaryTextColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          height: 1.35,
          color: primaryTextColor,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1.4,
          color: primaryTextColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          height: 1.4,
          color: primaryTextColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
          color: primaryTextColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          height: 1.4,
          color: secondaryTextColor,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          height: 1.35,
          color: tertiaryTextColor,
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
          letterSpacing: 0.1,
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
            letterSpacing: 0.2,
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
            letterSpacing: 0.1,
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
  static const Duration fastDuration = Duration(milliseconds: 200);

  /// Standard duration for transitions
  static const Duration mediumDuration = Duration(milliseconds: 350);

  /// Standard duration for page transitions
  static const Duration slowDuration = Duration(milliseconds: 500);

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
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
      ];

  /// Medium elevation for elevated elements
  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  /// Strong elevation for hero elements
  static List<BoxShadow> get strongShadow => [
        BoxShadow(
          color: accentColor.withOpacity(0.25),
          blurRadius: 32,
          offset: const Offset(0, 16),
          spreadRadius: 8,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
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
          Colors.white.withOpacity(0.1),
          Colors.transparent,
          Colors.black.withOpacity(0.05),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  /// Hero button gradient
  static LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accentColor,
          accentColor.withOpacity(0.8),
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