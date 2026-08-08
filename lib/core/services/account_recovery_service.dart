import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'plate_storage_service.dart';
import 'plate_verification_service.dart';
import 'simple_alert_service.dart';

/// Service for handling account recovery using secret ownership keys
///
/// Enables users to:
/// 1. Auto-login if they have registered plates on the device
/// 2. Recover their account on a new device using their secret key
/// 3. View and copy their secret keys for backup
class AccountRecoveryService {
  static final AccountRecoveryService _instance = AccountRecoveryService._internal();
  factory AccountRecoveryService() => _instance;
  AccountRecoveryService._internal();

  final PlateStorageService _storageService = PlateStorageService();
  final PlateVerificationService _verificationService = PlateVerificationService();
  final SimpleAlertService _alertService = SimpleAlertService();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Check if user can auto-login (has existing plates registered)
  Future<AutoLoginResult> checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        return AutoLoginResult(
          canAutoLogin: false,
          reason: 'No user ID found',
        );
      }

      // Check if user exists in database
      final userExists = await _alertService.userExists(userId);
      if (!userExists) {
        return AutoLoginResult(
          canAutoLogin: false,
          reason: 'User not found in database',
        );
      }

      // Check if user has plates registered locally
      final localPlates = await _storageService.getRegisteredPlates();
      if (localPlates.isEmpty) {
        return AutoLoginResult(
          canAutoLogin: false,
          reason: 'No plates registered locally',
        );
      }

      // Verify plates exist in database for this user
      final dbPlates = await _getDbPlates(userId);
      if (dbPlates.isEmpty) {
        return AutoLoginResult(
          canAutoLogin: false,
          reason: 'No plates found in database',
        );
      }

      // User has valid plates - can auto-login
      return AutoLoginResult(
        canAutoLogin: true,
        userId: userId,
        plateCount: dbPlates.length,
        reason: 'User has ${dbPlates.length} registered plate(s)',
      );

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Auto-login check failed: $e');
      }
      return AutoLoginResult(
        canAutoLogin: false,
        reason: 'Error checking status: $e',
      );
    }
  }

  /// Recover account using plate number and secret ownership key
  /// This allows users who changed devices to regain access to their plates
  Future<RecoveryResult> recoverWithSecretKey({
    required String plateNumber,
    required String secretKey,
  }) async {
    try {
      await _alertService.initialize();

      final normalizedPlate = plateNumber.trim().toUpperCase();
      final normalizedKey = secretKey.trim().toUpperCase();

      // Validate key format (YB-XXXX-XXXX-XXXX-XXXX)
      if (!_isValidKeyFormat(normalizedKey)) {
        return RecoveryResult(
          success: false,
          error: 'Invalid key format. Key should be like: YB-XXXX-XXXX-XXXX-XXXX',
        );
      }

      // Get or create user ID for this device
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      if (userId == null) {
        // Create new user for this device
        userId = await _alertService.getOrCreateUser();
        await prefs.setString('user_id', userId);
        if (kDebugMode) {
          debugPrint('🆕 Created new user for recovery: $userId');
        }
      }

      // Verify ownership and transfer plate to this user
      final verifyResult = await _verificationService.verifyOwnership(
        plateNumber: normalizedPlate,
        ownershipKey: normalizedKey,
        userId: userId,
      );

      if (!verifyResult.success) {
        return RecoveryResult(
          success: false,
          error: verifyResult.error ?? 'Verification failed',
        );
      }

      // Save plate to local storage
      await _storageService.addPlate(normalizedPlate);

      // Save the ownership key locally
      await _verificationService.saveKeyLocally(
        plateNumber: normalizedPlate,
        ownershipKey: normalizedKey,
      );

      // Mark onboarding as complete since they're a returning user
      await prefs.setBool('onboarding_completed', true);

      if (kDebugMode) {
        debugPrint('✅ Account recovered successfully for plate: $normalizedPlate');
      }

      return RecoveryResult(
        success: true,
        userId: userId,
        plateNumber: normalizedPlate,
        message: verifyResult.ownershipTransferred
            ? 'Plate recovered and transferred to your new device!'
            : 'Plate verified! Welcome back.',
      );

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Account recovery failed: $e');
      }
      return RecoveryResult(
        success: false,
        error: 'Recovery failed: $e',
      );
    }
  }

  /// Get all ownership keys for the user's plates
  /// Returns a map of plate number -> ownership key
  Future<Map<String, String?>> getAllOwnershipKeys() async {
    try {
      final plates = await _storageService.getRegisteredPlates();
      final keys = <String, String?>{};

      for (final plate in plates) {
        final key = await _verificationService.getLocalKey(plate);
        keys[plate] = key;
      }

      return keys;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get ownership keys: $e');
      }
      return {};
    }
  }

  /// Get ownership key for a specific plate
  Future<String?> getOwnershipKey(String plateNumber) async {
    return _verificationService.getLocalKey(plateNumber);
  }

  /// Check if a plate has a locally stored ownership key
  Future<bool> hasOwnershipKey(String plateNumber) async {
    return _verificationService.hasLocalKey(plateNumber);
  }

  /// Sync local plates with database after recovery
  Future<void> syncAfterRecovery(String userId) async {
    try {
      await _storageService.syncWithDatabase(userId);
      if (kDebugMode) {
        debugPrint('✅ Plates synced after recovery');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Sync after recovery failed: $e');
      }
    }
  }

  // Private helpers

  Future<List<String>> _getDbPlates(String userId) async {
    try {
      final result = await _supabase
          .from('plates')
          .select('plate_number')
          .eq('user_id', userId);

      return (result as List)
          .map((row) => row['plate_number'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get DB plates: $e');
      }
      return [];
    }
  }

  bool _isValidKeyFormat(String key) {
    // Format: YB-XXXX-XXXX-XXXX-XXXX (total 22 chars with dashes)
    final pattern = RegExp(r'^YB-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    return pattern.hasMatch(key);
  }
}

/// Result of auto-login check
class AutoLoginResult {
  final bool canAutoLogin;
  final String? userId;
  final int plateCount;
  final String reason;

  AutoLoginResult({
    required this.canAutoLogin,
    this.userId,
    this.plateCount = 0,
    required this.reason,
  });
}

/// Result of account recovery
class RecoveryResult {
  final bool success;
  final String? userId;
  final String? plateNumber;
  final String? message;
  final String? error;

  RecoveryResult({
    required this.success,
    this.userId,
    this.plateNumber,
    this.message,
    this.error,
  });
}
