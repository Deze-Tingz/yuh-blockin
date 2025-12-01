/// Payment Configuration for Yuh Blockin'
///
/// IMPORTANT: For production, set these values via:
/// 1. Environment variables (preferred for CI/CD)
/// 2. Or create a payment_config_secrets.dart file (add to .gitignore)
///
/// To use environment variables, run:
/// flutter run --dart-define=REVENUECAT_API_KEY=your_production_key
/// flutter run --dart-define=REVENUECAT_IOS_API_KEY=your_ios_key (if different)
class PaymentConfig {
  PaymentConfig._();

  /// RevenueCat API Keys - Set via environment variables at compile time
  ///
  /// REQUIRED for production builds:
  /// flutter run --dart-define=REVENUECAT_API_KEY=goog_xxx
  /// flutter build apk --dart-define=REVENUECAT_API_KEY=goog_xxx
  ///
  /// For iOS (if different from Android):
  /// --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx

  // Android/Google Play API Key - MUST be provided via environment variable
  static const String _androidApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '', // No default - must be provided
  );

  // iOS App Store API Key - Optional, falls back to Android key
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );

  /// Get the appropriate API key based on platform
  static String getApiKey({required bool isIOS}) {
    if (isIOS && _iosApiKey.isNotEmpty) {
      return _iosApiKey;
    }
    return _androidApiKey;
  }

  /// Check if payment system is properly configured
  static bool get isConfiguredForProduction {
    return _androidApiKey.isNotEmpty;
  }

  /// Get a user-friendly error message if not configured
  static String get configurationError {
    if (_androidApiKey.isEmpty) {
      return 'Payment system not configured. Run with: --dart-define=REVENUECAT_API_KEY=your_key';
    }
    return '';
  }

  /// Product identifiers - Must match App Store Connect & Google Play Console
  static const String monthlyProductId = 'yuh_blockin_monthly';
  static const String lifetimeProductId = 'yuh_blockin_lifetime';

  /// Entitlement identifiers - Must match RevenueCat dashboard
  static const String premiumEntitlement = 'premium';
  static const String lifetimeEntitlement = 'lifetime';

  /// Free tier configuration
  static const int freeDailyAlertLimit = 3;
  static const int freeMaxPlates = 3;

  /// Premium tier configuration
  static const int premiumMaxPlates = 10;
  static const int premiumDailyAlertLimit = 200; // Effectively unlimited

  /// URLs for Terms and Privacy
  static const String termsOfServiceUrl = 'https://yuhblockin.com/terms';
  static const String privacyPolicyUrl = 'https://yuhblockin.com/privacy';

  /// Support email
  static const String supportEmail = 'support@yuhblockin.com';
}
