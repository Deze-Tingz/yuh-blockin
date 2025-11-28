import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Subscription Service for managing premium features
/// Integrates with RevenueCat for payments and Supabase for server-side validation
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // RevenueCat Public API Key
  // Test key for development - replace with production key before release
  static const String _revenueCatApiKey = 'test_WQsERIofLdSzQyuTszjVbFSEdvu';

  // Product identifiers - Must match Google Play Console
  static const String monthlyProductId = 'yuh_blockin_monthly';
  static const String lifetimeProductId = 'yuh_blockin_lifetime';

  // Free tier limits
  static const int freeDailyAlertLimit = 3;

  // State
  bool _isInitialized = false;
  bool _isPremium = false;
  String _subscriptionStatus = 'free'; // free, premium, lifetime
  int _dailyAlertsUsed = 0;
  DateTime? _lastUsageDate;
  String? _currentUserId;

  // Getters
  bool get isPremium => _isPremium;
  String get subscriptionStatus => _subscriptionStatus;
  int get dailyAlertsUsed => _dailyAlertsUsed;
  int get remainingAlerts => _isPremium ? 999 : max(0, freeDailyAlertLimit - _dailyAlertsUsed);
  bool get hasUnlimitedAlerts => _isPremium;

  /// Initialize the subscription service
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) return;

    _currentUserId = userId;

    try {
      // Configure RevenueCat
      if (_revenueCatApiKey != 'YOUR_REVENUECAT_API_KEY') {
        await Purchases.configure(
          PurchasesConfiguration(_revenueCatApiKey)..appUserID = userId,
        );

        // Listen for customer info updates
        Purchases.addCustomerInfoUpdateListener((customerInfo) {
          _handleCustomerInfoUpdate(customerInfo);
        });
      }

      // Load cached subscription status
      await _loadCachedStatus();

      // Sync with server
      await _syncSubscriptionStatus();

      // Load daily usage
      await _loadDailyUsage();

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ SubscriptionService initialized for user: $userId');
        debugPrint('   Status: $_subscriptionStatus, Premium: $_isPremium');
        debugPrint('   Alerts used today: $_dailyAlertsUsed/$freeDailyAlertLimit');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ SubscriptionService initialization failed: $e');
      }
      // Default to free tier on error
      _isPremium = false;
      _subscriptionStatus = 'free';
      _isInitialized = true;
    }
  }

  /// Check if user can send an alert
  Future<bool> canSendAlert() async {
    if (_isPremium) return true;

    // Reset usage if it's a new day
    await _checkAndResetDailyUsage();

    return _dailyAlertsUsed < freeDailyAlertLimit;
  }

  /// Increment daily usage after sending an alert
  Future<void> incrementDailyUsage() async {
    if (_isPremium) return; // Premium users don't track usage

    _dailyAlertsUsed++;
    await _saveDailyUsage();

    // Also update server
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('increment_daily_usage', params: {
        'p_user_id': _currentUserId,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to sync daily usage to server: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('📊 Daily usage: $_dailyAlertsUsed/$freeDailyAlertLimit');
    }
  }

  /// Purchase monthly subscription
  Future<PurchaseResult> purchaseMonthly() async {
    return _purchaseProduct(monthlyProductId);
  }

  /// Purchase lifetime access
  Future<PurchaseResult> purchaseLifetime() async {
    return _purchaseProduct(lifetimeProductId);
  }

  /// Restore purchases
  Future<PurchaseResult> restorePurchases() async {
    try {
      if (_revenueCatApiKey == 'YOUR_REVENUECAT_API_KEY') {
        return PurchaseResult(
          success: false,
          error: 'Payment system not configured yet',
        );
      }

      final customerInfo = await Purchases.restorePurchases();
      await _handleCustomerInfoUpdate(customerInfo);

      if (_isPremium) {
        return PurchaseResult(success: true, message: 'Purchases restored!');
      } else {
        return PurchaseResult(
          success: false,
          error: 'No previous purchases found',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Restore failed: $e');
      }
      return PurchaseResult(success: false, error: e.toString());
    }
  }

  /// Get available offerings from RevenueCat
  Future<Offerings?> getOfferings() async {
    try {
      if (_revenueCatApiKey == 'YOUR_REVENUECAT_API_KEY') {
        return null;
      }
      return await Purchases.getOfferings();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get offerings: $e');
      }
      return null;
    }
  }

  // Private methods

  Future<PurchaseResult> _purchaseProduct(String productId) async {
    try {
      if (_revenueCatApiKey == 'YOUR_REVENUECAT_API_KEY') {
        // Demo mode - simulate purchase for testing
        if (kDebugMode) {
          debugPrint('🧪 Demo mode: Simulating purchase of $productId');
          await _simulatePurchase(productId);
          return PurchaseResult(success: true, message: 'Demo purchase successful!');
        }
        return PurchaseResult(
          success: false,
          error: 'Payment system not configured. Contact support.',
        );
      }

      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        return PurchaseResult(success: false, error: 'No offerings available');
      }

      Package? package;
      if (productId == monthlyProductId) {
        package = offerings.current!.monthly;
      } else if (productId == lifetimeProductId) {
        package = offerings.current!.lifetime;
      }

      if (package == null) {
        return PurchaseResult(success: false, error: 'Product not found');
      }

      final customerInfo = await Purchases.purchasePackage(package);
      await _handleCustomerInfoUpdate(customerInfo);

      if (_isPremium) {
        return PurchaseResult(success: true, message: 'Purchase successful!');
      } else {
        return PurchaseResult(success: false, error: 'Purchase not activated');
      }
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult(success: false, error: 'Purchase cancelled');
      }
      return PurchaseResult(success: false, error: 'Purchase failed: $e');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Purchase failed: $e');
      }
      return PurchaseResult(success: false, error: e.toString());
    }
  }

  /// Simulate purchase for demo/testing mode
  Future<void> _simulatePurchase(String productId) async {
    _isPremium = true;
    _subscriptionStatus = productId == lifetimeProductId ? 'lifetime' : 'premium';
    await _saveCachedStatus();

    // Update server
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('subscriptions').upsert({
        'user_id': _currentUserId,
        'status': _subscriptionStatus,
        'plan_type': productId == lifetimeProductId ? 'lifetime' : 'monthly',
        'started_at': DateTime.now().toIso8601String(),
        'expires_at': productId == lifetimeProductId
            ? null
            : DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to update server subscription: $e');
      }
    }
  }

  Future<void> _handleCustomerInfoUpdate(CustomerInfo customerInfo) async {
    final entitlements = customerInfo.entitlements.active;

    if (entitlements.containsKey('premium') || entitlements.containsKey('lifetime')) {
      _isPremium = true;
      _subscriptionStatus = entitlements.containsKey('lifetime') ? 'lifetime' : 'premium';
    } else {
      _isPremium = false;
      _subscriptionStatus = 'free';
    }

    await _saveCachedStatus();
    await _syncToServer();

    if (kDebugMode) {
      debugPrint('🔄 Subscription updated: $_subscriptionStatus');
    }
  }

  Future<void> _syncSubscriptionStatus() async {
    try {
      final supabase = Supabase.instance.client;
      final result = await supabase
          .from('subscriptions')
          .select('status, plan_type, expires_at')
          .eq('user_id', _currentUserId!)
          .maybeSingle();

      if (result != null) {
        _subscriptionStatus = result['status'] ?? 'free';
        _isPremium = _subscriptionStatus != 'free';

        // Check if subscription has expired
        if (result['expires_at'] != null) {
          final expiresAt = DateTime.parse(result['expires_at']);
          if (expiresAt.isBefore(DateTime.now())) {
            _isPremium = false;
            _subscriptionStatus = 'free';
          }
        }
      }

      await _saveCachedStatus();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to sync subscription status: $e');
      }
    }
  }

  Future<void> _syncToServer() async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('subscriptions').upsert({
        'user_id': _currentUserId,
        'status': _subscriptionStatus,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to sync to server: $e');
      }
    }
  }

  Future<void> _loadCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _subscriptionStatus = prefs.getString('yuh_subscription_status') ?? 'free';
      _isPremium = _subscriptionStatus != 'free';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to load cached status: $e');
      }
    }
  }

  Future<void> _saveCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('yuh_subscription_status', _subscriptionStatus);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to save cached status: $e');
      }
    }
  }

  Future<void> _loadDailyUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDateStr = prefs.getString('yuh_last_usage_date');
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';

      if (lastDateStr == todayStr) {
        _dailyAlertsUsed = prefs.getInt('yuh_daily_alerts_used') ?? 0;
      } else {
        // New day, reset usage
        _dailyAlertsUsed = 0;
        await _saveDailyUsage();
      }
      _lastUsageDate = today;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to load daily usage: $e');
      }
    }
  }

  Future<void> _saveDailyUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';

      await prefs.setString('yuh_last_usage_date', todayStr);
      await prefs.setInt('yuh_daily_alerts_used', _dailyAlertsUsed);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to save daily usage: $e');
      }
    }
  }

  Future<void> _checkAndResetDailyUsage() async {
    final today = DateTime.now();
    if (_lastUsageDate == null ||
        _lastUsageDate!.day != today.day ||
        _lastUsageDate!.month != today.month ||
        _lastUsageDate!.year != today.year) {
      _dailyAlertsUsed = 0;
      _lastUsageDate = today;
      await _saveDailyUsage();
    }
  }
}

/// Result of a purchase operation
class PurchaseResult {
  final bool success;
  final String? message;
  final String? error;

  PurchaseResult({
    required this.success,
    this.message,
    this.error,
  });
}
