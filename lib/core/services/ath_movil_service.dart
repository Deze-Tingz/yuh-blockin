import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ATH Móvil Payment Service
///
/// Handles ATH Móvil Business payments for Puerto Rico users.
/// This service integrates with Supabase Edge Functions that securely
/// communicate with the ATH Móvil API (private key never leaves server).
///
/// Usage:
/// ```dart
/// final athService = AthMovilService();
///
/// // Create a payment
/// final result = await athService.createPayment(
///   userId: 'user123',
///   productType: AthProductType.monthly,
///   phoneNumber: '7875551234',
/// );
///
/// if (result.success) {
///   // Watch for status updates
///   athService.watchPaymentStatus(result.transactionId!).listen((status) {
///     print('Status: ${status.status}');
///     if (status.isSuccess) {
///       print('Payment completed!');
///     }
///   });
/// }
/// ```
class AthMovilService {
  static final AthMovilService _instance = AthMovilService._internal();
  factory AthMovilService() => _instance;
  AthMovilService._internal();

  // Persistence key for pending transactions
  static const String _pendingTransactionKey = 'ath_pending_transaction';
  static const String _pendingUserIdKey = 'ath_pending_user_id';
  static const String _athPathCacheKey = 'ath_movil_path';

  // Poll configuration
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _maxPollDuration = Duration(minutes: 10);

  Timer? _pollTimer;
  StreamController<AthPaymentStatus>? _statusController;
  bool _isPolling = false;
  String? _cachedAthPath;

  /// Check if ATH Móvil payments are available
  /// Currently always returns true - could be enhanced to check locale
  bool get isAvailable => true;

  /// Get ATH Móvil business path from Supabase config
  /// Caches the value to avoid repeated DB calls
  Future<String> getAthPath() async {
    // Return cached value if available
    if (_cachedAthPath != null) return _cachedAthPath!;

    try {
      // Try to get from SharedPreferences first (offline support)
      final prefs = await SharedPreferences.getInstance();
      final cachedPath = prefs.getString(_athPathCacheKey);

      // Fetch from Supabase
      final supabase = Supabase.instance.client;
      final result = await supabase
          .from('app_config')
          .select('value')
          .eq('key', 'ath_movil_path')
          .maybeSingle();

      if (result != null && result['value'] != null) {
        final path = result['value'] as String;
        _cachedAthPath = path;
        // Cache locally for offline use
        await prefs.setString(_athPathCacheKey, path);
        return path;
      }

      // Fall back to cached value if DB fetch failed
      if (cachedPath != null) {
        _cachedAthPath = cachedPath;
        return cachedPath;
      }

      // Default fallback (should not happen if DB is configured)
      return 'dezetingz';
    } catch (e) {
      debugPrint('Error fetching ATH path: $e');
      // Try cached value
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_athPathCacheKey) ?? 'dezetingz';
    }
  }

  /// Get the full ATH Móvil deep link URL
  Future<String> getAthDeepLink() async {
    final path = await getAthPath();
    // Path already includes leading slash (e.g., "/dezetingz")
    return 'athmovil://business$path';
  }

  /// Get formatted display path (already includes leading slash)
  Future<String> getDisplayPath() async {
    return await getAthPath();
  }

  /// Validate phone number for ATH Móvil
  /// Accepts: 7875551234, 787-555-1234, (787) 555-1234, etc.
  /// Returns cleaned 10-digit number or null if invalid
  String? validatePhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // Must be 10 digits
    if (cleaned.length != 10) return null;

    return cleaned;
  }

  /// Format phone number for display (787-555-1234)
  String formatPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 10) return phone;
    return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
  }

  /// Create a new ATH Móvil payment
  ///
  /// Returns [AthPaymentResult] with transaction details if successful,
  /// or error message if failed.
  Future<AthPaymentResult> createPayment({
    required String userId,
    required AthProductType productType,
    required String phoneNumber,
  }) async {
    try {
      // Validate phone number
      final cleanPhone = validatePhoneNumber(phoneNumber);
      if (cleanPhone == null) {
        return AthPaymentResult(
          success: false,
          error: 'Please enter a valid Puerto Rico phone number (787 or 939)',
        );
      }

      final supabase = Supabase.instance.client;

      // Call Edge Function to create payment
      final response = await supabase.functions.invoke(
        'ath-create-payment',
        body: {
          'user_id': userId,
          'product_type': productType.name,
          'phone_number': cleanPhone,
        },
      );

      if (response.status != 200) {
        final errorData = response.data;
        final error = errorData is Map ? errorData['error'] : 'Failed to create payment';
        debugPrint('ATH Móvil create payment failed: $error');
        return AthPaymentResult(success: false, error: error.toString());
      }

      final data = response.data as Map<String, dynamic>;

      // Store pending transaction for recovery (e.g., if app is closed)
      await _storePendingTransaction(data['transaction_id'], userId);

      return AthPaymentResult(
        success: true,
        transactionId: data['transaction_id'],
        ecommerceId: data['ecommerce_id'],
        amount: (data['amount'] as num).toDouble(),
        productType: productType,
        expiresAt: DateTime.parse(data['expires_at']),
      );
    } catch (e) {
      debugPrint('ATH Móvil create payment error: $e');
      return AthPaymentResult(
        success: false,
        error: 'Failed to connect to payment service. Please try again.',
      );
    }
  }

  /// Start watching payment status with polling
  ///
  /// Returns a Stream that emits [AthPaymentStatus] updates.
  /// The stream completes when payment reaches a terminal state
  /// (completed, failed, expired, or cancelled).
  Stream<AthPaymentStatus> watchPaymentStatus(String transactionId) {
    // Close any existing stream
    _statusController?.close();
    _pollTimer?.cancel();

    _statusController = StreamController<AthPaymentStatus>.broadcast(
      onCancel: () {
        _stopPolling();
      },
    );

    _startPolling(transactionId);

    return _statusController!.stream;
  }

  void _startPolling(String transactionId) {
    if (_isPolling) return;
    _isPolling = true;

    final startTime = DateTime.now();

    // Emit initial pending status
    _statusController?.add(AthPaymentStatus(
      status: AthStatus.pending,
      message: 'Opening ATH Móvil...',
    ));

    _pollTimer = Timer.periodic(_pollInterval, (timer) async {
      // Check timeout
      if (DateTime.now().difference(startTime) > _maxPollDuration) {
        _statusController?.add(AthPaymentStatus(
          status: AthStatus.expired,
          message: 'Payment session expired. Please try again.',
        ));
        _stopPolling();
        await _clearPendingTransaction();
        return;
      }

      try {
        final status = await checkPaymentStatus(transactionId);
        _statusController?.add(status);

        // Handle confirmed status - needs authorization
        if (status.status == AthStatus.confirmed) {
          _stopPolling();
          await _authorizePayment(transactionId);
          return;
        }

        // Stop polling on other terminal states
        if (status.isTerminal) {
          _stopPolling();
          if (status.status != AthStatus.completed) {
            await _clearPendingTransaction();
          }
        }
      } catch (e) {
        debugPrint('Poll error: $e');
        // Don't stop polling on transient errors
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
  }

  /// Check current payment status (single check, no polling)
  Future<AthPaymentStatus> checkPaymentStatus(String transactionId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'ath-check-payment',
        body: {'transaction_id': transactionId},
      );

      if (response.status != 200) {
        return AthPaymentStatus(
          status: AthStatus.error,
          message: 'Failed to check payment status',
        );
      }

      final data = response.data as Map<String, dynamic>;
      return AthPaymentStatus.fromJson(data);
    } catch (e) {
      debugPrint('Check status error: $e');
      return AthPaymentStatus(
        status: AthStatus.error,
        message: 'Connection error. Retrying...',
      );
    }
  }

  /// Authorize payment after user confirmation in ATH Móvil
  Future<AthPaymentStatus> _authorizePayment(String transactionId) async {
    try {
      // Emit authorizing status
      _statusController?.add(AthPaymentStatus(
        status: AthStatus.authorizing,
        message: 'Completing payment...',
      ));

      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'ath-authorize-payment',
        body: {'transaction_id': transactionId},
      );

      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        // Clear pending transaction
        await _clearPendingTransaction();

        final status = AthPaymentStatus(
          status: AthStatus.completed,
          message: 'Payment successful! Welcome to Premium!',
          subscriptionType: data['subscription_type'],
          referenceNumber: data['reference_number'],
        );
        _statusController?.add(status);
        return status;
      } else {
        await _clearPendingTransaction();

        final status = AthPaymentStatus(
          status: AthStatus.failed,
          message: data['error'] ?? 'Payment authorization failed',
        );
        _statusController?.add(status);
        return status;
      }
    } catch (e) {
      debugPrint('Authorization error: $e');
      final status = AthPaymentStatus(
        status: AthStatus.error,
        message: 'Failed to complete payment. Please contact support.',
      );
      _statusController?.add(status);
      return status;
    }
  }

  /// Cancel the current payment process
  void cancelPayment() {
    _stopPolling();
    _statusController?.add(AthPaymentStatus(
      status: AthStatus.cancelled,
      message: 'Payment cancelled',
    ));
    _clearPendingTransaction();
  }

  /// Check for a pending transaction from a previous session
  /// (e.g., if app was closed during payment)
  Future<PendingTransaction?> getPendingTransaction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionId = prefs.getString(_pendingTransactionKey);
      final userId = prefs.getString(_pendingUserIdKey);

      if (transactionId == null || userId == null) return null;

      // Check if transaction is still valid
      final status = await checkPaymentStatus(transactionId);

      // If still pending or open, return it for recovery
      if (status.status == AthStatus.pending ||
          status.status == AthStatus.open) {
        return PendingTransaction(
          transactionId: transactionId,
          userId: userId,
        );
      }

      // Otherwise, clear it
      await _clearPendingTransaction();
      return null;
    } catch (e) {
      debugPrint('Get pending transaction error: $e');
      return null;
    }
  }

  Future<void> _storePendingTransaction(String transactionId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingTransactionKey, transactionId);
    await prefs.setString(_pendingUserIdKey, userId);
  }

  Future<void> _clearPendingTransaction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingTransactionKey);
    await prefs.remove(_pendingUserIdKey);
  }

  /// Check renewal status for monthly ATH Móvil subscribers
  Future<RenewalInfo?> checkRenewalStatus(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final result = await supabase
          .from('ath_monthly_subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (result == null) return null;

      return RenewalInfo(
        status: _parseRenewalStatus(result['renewal_status']),
        currentPeriodEnd: DateTime.parse(result['current_period_end']),
        consecutiveMonths: result['consecutive_months'] ?? 1,
      );
    } catch (e) {
      debugPrint('Check renewal status error: $e');
      return null;
    }
  }

  /// Get transaction history for a user
  Future<List<AthTransaction>> getTransactionHistory(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final result = await supabase
          .from('ath_movil_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      return (result as List)
          .map((e) => AthTransaction.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Get transaction history error: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _stopPolling();
    _statusController?.close();
    _statusController = null;
  }

  /// Parse renewal status from database string to enum
  static RenewalStatus _parseRenewalStatus(String? status) {
    switch (status) {
      case 'active':
        return RenewalStatus.active;
      case 'grace_period':
        return RenewalStatus.gracePeriod;
      case 'expired':
        return RenewalStatus.expired;
      case 'cancelled':
        return RenewalStatus.cancelled;
      default:
        return RenewalStatus.active;
    }
  }
}

// ============================================
// Enums
// ============================================

/// Product types available for ATH Móvil purchase
enum AthProductType {
  monthly,
  lifetime,
}

/// ATH Móvil payment status
enum AthStatus {
  pending,      // Payment created, waiting for user
  open,         // User opened ATH Móvil app
  confirmed,    // User confirmed, awaiting authorization
  authorizing,  // Authorizing payment
  completed,    // Payment successful
  failed,       // Payment failed
  expired,      // Payment session expired
  cancelled,    // User cancelled
  error,        // System error
}

/// Renewal status for monthly subscribers
enum RenewalStatus {
  active,
  gracePeriod,
  expired,
  cancelled,
}

// ============================================
// Data Classes
// ============================================

/// Result of creating an ATH Móvil payment
class AthPaymentResult {
  final bool success;
  final String? transactionId;
  final String? ecommerceId;
  final double? amount;
  final AthProductType? productType;
  final DateTime? expiresAt;
  final String? error;

  AthPaymentResult({
    required this.success,
    this.transactionId,
    this.ecommerceId,
    this.amount,
    this.productType,
    this.expiresAt,
    this.error,
  });

  /// Formatted amount string (e.g., "$2.99")
  String get formattedAmount =>
      amount != null ? '\$${amount!.toStringAsFixed(2)}' : '';

  /// Product type display name
  String get productName {
    switch (productType) {
      case AthProductType.monthly:
        return 'Monthly Premium';
      case AthProductType.lifetime:
        return 'Lifetime Premium';
      case null:
        return '';
    }
  }
}

/// Current status of an ATH Móvil payment
class AthPaymentStatus {
  final AthStatus status;
  final String message;
  final String? referenceNumber;
  final String? subscriptionType;

  AthPaymentStatus({
    required this.status,
    required this.message,
    this.referenceNumber,
    this.subscriptionType,
  });

  factory AthPaymentStatus.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    final athStatus = AthStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => AthStatus.pending,
    );

    return AthPaymentStatus(
      status: athStatus,
      message: _getMessageForStatus(athStatus),
      referenceNumber: json['reference_number'],
      subscriptionType: json['subscription_type'],
    );
  }

  static String _getMessageForStatus(AthStatus status) {
    switch (status) {
      case AthStatus.pending:
        return 'Waiting for ATH Móvil...';
      case AthStatus.open:
        return 'Please confirm payment in your ATH Móvil app';
      case AthStatus.confirmed:
        return 'Payment confirmed! Completing...';
      case AthStatus.authorizing:
        return 'Completing payment...';
      case AthStatus.completed:
        return 'Payment successful!';
      case AthStatus.failed:
        return 'Payment failed. Please try again.';
      case AthStatus.expired:
        return 'Payment session expired';
      case AthStatus.cancelled:
        return 'Payment cancelled';
      case AthStatus.error:
        return 'An error occurred';
    }
  }

  /// Whether this is a terminal (final) state
  bool get isTerminal => [
        AthStatus.completed,
        AthStatus.failed,
        AthStatus.expired,
        AthStatus.cancelled,
        AthStatus.confirmed, // Terminal for polling, triggers authorization
      ].contains(status);

  /// Whether payment was successful
  bool get isSuccess => status == AthStatus.completed;

  /// Whether payment is still in progress
  bool get isInProgress => [
        AthStatus.pending,
        AthStatus.open,
        AthStatus.authorizing,
      ].contains(status);
}

/// Pending transaction from a previous session
class PendingTransaction {
  final String transactionId;
  final String userId;

  PendingTransaction({
    required this.transactionId,
    required this.userId,
  });
}

/// Renewal information for monthly subscribers
class RenewalInfo {
  final RenewalStatus status;
  final DateTime currentPeriodEnd;
  final int consecutiveMonths;

  RenewalInfo({
    required this.status,
    required this.currentPeriodEnd,
    required this.consecutiveMonths,
  });

  /// Days until subscription expires
  int get daysUntilExpiry {
    return currentPeriodEnd.difference(DateTime.now()).inDays;
  }

  /// Whether user needs to renew soon (within 3 days)
  bool get needsRenewal {
    return daysUntilExpiry <= 3 && status == RenewalStatus.active;
  }

  /// Whether user is in grace period
  bool get isInGracePeriod => status == RenewalStatus.gracePeriod;

  /// Whether subscription has expired
  bool get isExpired => status == RenewalStatus.expired;

  /// User-friendly status message
  String get statusMessage {
    if (isExpired) {
      return 'Your subscription has expired';
    }
    if (isInGracePeriod) {
      return 'Your subscription has expired. Renew now to keep premium access!';
    }
    if (needsRenewal) {
      return 'Your subscription expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
    }
    return 'Active for $consecutiveMonths month${consecutiveMonths == 1 ? '' : 's'}';
  }
}

/// ATH Móvil transaction record
class AthTransaction {
  final String id;
  final String ecommerceId;
  final String? referenceNumber;
  final String productType;
  final double amount;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;

  AthTransaction({
    required this.id,
    required this.ecommerceId,
    this.referenceNumber,
    required this.productType,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  factory AthTransaction.fromJson(Map<String, dynamic> json) {
    return AthTransaction(
      id: json['id'],
      ecommerceId: json['ecommerce_id'],
      referenceNumber: json['reference_number'],
      productType: json['product_type'],
      amount: (json['amount'] as num).toDouble(),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';

  String get productName =>
      productType == 'lifetime' ? 'Lifetime Premium' : 'Monthly Premium';

  bool get isCompleted => status == 'completed';
}
