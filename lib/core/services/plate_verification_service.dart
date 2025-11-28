import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling plate ownership verification
/// Uses crypto-style ownership keys - no photos, no IDs required
///
/// How it works:
/// 1. When user registers a plate, they receive a unique ownership key
/// 2. This key is stored ONLY on their device (like a crypto private key)
/// 3. Server only stores a hash of the key
/// 4. To prove ownership, user must provide the original key
/// 5. If disputed, only the true owner can prove they have the key
class PlateVerificationService {
  static final PlateVerificationService _instance = PlateVerificationService._internal();
  factory PlateVerificationService() => _instance;
  PlateVerificationService._internal();

  // Lazy initialization - only access Supabase when needed
  SupabaseClient get _supabase => Supabase.instance.client;
  final _random = Random.secure();

  // Local storage key prefix
  static const String _storagePrefix = 'yuh_plate_key_';

  /// Verification status enum
  static const String statusUnverified = 'unverified';
  static const String statusVerified = 'verified';
  static const String statusDisputed = 'disputed';

  // ===== KEY GENERATION =====

  /// Generate a unique ownership key
  /// Format: YB-XXXX-XXXX-XXXX-XXXX (16 alphanumeric characters + prefix)
  String generateOwnershipKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed confusing chars (0,O,1,I)
    final buffer = StringBuffer('YB');

    for (int group = 0; group < 4; group++) {
      buffer.write('-');
      for (int i = 0; i < 4; i++) {
        buffer.write(chars[_random.nextInt(chars.length)]);
      }
    }

    return buffer.toString();
  }

  /// Hash an ownership key for secure storage
  String hashOwnershipKey(String key) {
    // Normalize key (remove dashes, uppercase)
    final normalized = key.replaceAll('-', '').toUpperCase();
    final bytes = utf8.encode(normalized);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // ===== LOCAL KEY STORAGE =====

  /// Save ownership key locally (never sent to server in plain text)
  Future<bool> saveKeyLocally({
    required String plateNumber,
    required String ownershipKey,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Store with plate number hash as key for privacy
      final storageKey = _storagePrefix + _hashPlateForStorage(plateNumber);
      await prefs.setString(storageKey, ownershipKey);

      if (kDebugMode) {
        debugPrint('✅ Ownership key saved locally for plate');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to save key locally: $e');
      }
      return false;
    }
  }

  /// Retrieve ownership key from local storage
  Future<String?> getLocalKey(String plateNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = _storagePrefix + _hashPlateForStorage(plateNumber);
      return prefs.getString(storageKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get local key: $e');
      }
      return null;
    }
  }

  /// Check if user has the ownership key stored locally
  Future<bool> hasLocalKey(String plateNumber) async {
    final key = await getLocalKey(plateNumber);
    return key != null && key.isNotEmpty;
  }

  /// Delete ownership key from local storage
  Future<bool> deleteLocalKey(String plateNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = _storagePrefix + _hashPlateForStorage(plateNumber);
      await prefs.remove(storageKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all locally stored keys (for backup/export)
  Future<Map<String, String>> getAllLocalKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_storagePrefix));
      final result = <String, String>{};

      for (final key in keys) {
        final value = prefs.getString(key);
        if (value != null) {
          result[key.replaceFirst(_storagePrefix, '')] = value;
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  /// Clean up orphaned ownership keys (keys for plates that no longer exist)
  /// Call this after plate sync to ensure consistency
  Future<int> cleanupOrphanedKeys(List<String> validPlates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeyNames = prefs.getKeys().where((k) => k.startsWith(_storagePrefix)).toList();

      // Build set of valid hashes
      final validHashes = <String>{};
      for (final plate in validPlates) {
        validHashes.add(_hashPlateForStorage(plate));
      }

      int removedCount = 0;
      for (final keyName in allKeyNames) {
        final hash = keyName.replaceFirst(_storagePrefix, '');
        if (!validHashes.contains(hash)) {
          await prefs.remove(keyName);
          removedCount++;
          if (kDebugMode) {
            debugPrint('🗑️ Removed orphaned ownership key: $hash');
          }
        }
      }

      if (kDebugMode && removedCount > 0) {
        debugPrint('✅ Cleaned up $removedCount orphaned ownership key(s)');
      }

      return removedCount;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to cleanup orphaned keys: $e');
      }
      return 0;
    }
  }

  /// Clear all local ownership keys (for account switch or reset)
  Future<void> clearAllLocalKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeyNames = prefs.getKeys().where((k) => k.startsWith(_storagePrefix)).toList();

      for (final keyName in allKeyNames) {
        await prefs.remove(keyName);
      }

      if (kDebugMode) {
        debugPrint('🗑️ Cleared all ${allKeyNames.length} local ownership keys');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to clear local keys: $e');
      }
    }
  }

  String _hashPlateForStorage(String plateNumber) {
    final normalized = plateNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  // ===== VERIFICATION FLOW =====

  /// Register a plate and generate ownership key
  /// Returns the ownership key that MUST be saved by the user
  Future<RegistrationResult> registerPlateWithKey({
    required String plateNumber,
    required String userId,
  }) async {
    try {
      // Generate unique ownership key
      final ownershipKey = generateOwnershipKey();
      final keyHash = hashOwnershipKey(ownershipKey);

      // Hash the plate number for privacy
      final plateHash = _hashPlateNumber(plateNumber);

      // Check if plate already registered
      final existing = await _supabase
          .from('plates')
          .select('user_id, verification_status')
          .eq('hashed_plate', plateHash)
          .maybeSingle();

      if (existing != null) {
        if (existing['user_id'] == userId) {
          return RegistrationResult(
            success: false,
            error: 'You already registered this plate',
          );
        } else {
          // Plate registered by someone else - can initiate dispute
          return RegistrationResult(
            success: false,
            error: 'This plate is already registered. You can dispute ownership if you believe it\'s yours.',
            canDispute: true,
          );
        }
      }

      // Register the plate
      await _supabase.from('plates').insert({
        'hashed_plate': plateHash,
        'user_id': userId,
        'verification_status': statusVerified,
        'ownership_key_hash': keyHash,
        'verified_at': DateTime.now().toIso8601String(),
      });

      // Save key locally
      await saveKeyLocally(plateNumber: plateNumber, ownershipKey: ownershipKey);

      if (kDebugMode) {
        debugPrint('✅ Plate registered with ownership key');
      }

      return RegistrationResult(
        success: true,
        ownershipKey: ownershipKey,
        message: 'Plate registered! Save your ownership key securely.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to register plate: $e');
      }
      return RegistrationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  String _hashPlateNumber(String plateNumber) {
    final normalized = plateNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    final bytes = utf8.encode('YuhBlockin_$normalized');
    return sha256.convert(bytes).toString();
  }

  /// Verify ownership using the ownership key
  Future<VerificationResult> verifyOwnership({
    required String plateNumber,
    required String ownershipKey,
    required String userId,
  }) async {
    try {
      final plateHash = _hashPlateNumber(plateNumber);
      final keyHash = hashOwnershipKey(ownershipKey);

      // Get the plate record
      final record = await _supabase
          .from('plates')
          .select('id, user_id, ownership_key_hash, verification_status')
          .eq('hashed_plate', plateHash)
          .maybeSingle();

      if (record == null) {
        return VerificationResult(
          success: false,
          error: 'Plate not found in registry',
        );
      }

      // Check if the key matches
      if (record['ownership_key_hash'] == keyHash) {
        // Key is valid!
        if (record['user_id'] != userId) {
          // Transfer ownership to the user with the correct key
          await _supabase
              .from('plates')
              .update({
                'user_id': userId,
                'verification_status': statusVerified,
                'verified_at': DateTime.now().toIso8601String(),
              })
              .eq('id', record['id']);

          return VerificationResult(
            success: true,
            message: 'Ownership verified and plate transferred to your account!',
            ownershipTransferred: true,
          );
        } else {
          return VerificationResult(
            success: true,
            message: 'Ownership verified! You are the rightful owner.',
          );
        }
      } else {
        return VerificationResult(
          success: false,
          error: 'Invalid ownership key',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to verify ownership: $e');
      }
      return VerificationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Copy ownership key to clipboard
  Future<void> copyKeyToClipboard(String key) async {
    await Clipboard.setData(ClipboardData(text: key));
  }

  /// Get verification status for a plate
  Future<PlateVerificationStatus?> getVerificationStatus({
    required String plateNumber,
    required String userId,
  }) async {
    try {
      final plateHash = _hashPlateNumber(plateNumber);

      final result = await _supabase
          .from('plates')
          .select('verification_status, verified_at, ownership_key_hash')
          .eq('hashed_plate', plateHash)
          .eq('user_id', userId)
          .maybeSingle();

      if (result != null) {
        final hasLocalKey = await this.hasLocalKey(plateNumber);

        return PlateVerificationStatus(
          status: result['verification_status'] as String? ?? statusUnverified,
          verifiedAt: result['verified_at'] != null
              ? DateTime.parse(result['verified_at'] as String)
              : null,
          hasOwnershipKey: result['ownership_key_hash'] != null,
          hasLocalKey: hasLocalKey,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get verification status: $e');
      }
      return null;
    }
  }

  // ===== DISPUTE FLOW =====

  /// Initiate a dispute for a plate you believe you own
  Future<DisputeResult> initiateDispute({
    required String plateNumber,
    required String challengerId,
    required String challengerOwnershipKey,
  }) async {
    try {
      final plateHash = _hashPlateNumber(plateNumber);
      final challengerKeyHash = hashOwnershipKey(challengerOwnershipKey);

      // Get existing registration
      final existing = await _supabase
          .from('plates')
          .select('id, user_id, ownership_key_hash')
          .eq('hashed_plate', plateHash)
          .maybeSingle();

      if (existing == null) {
        return DisputeResult(
          success: false,
          error: 'Plate not registered',
        );
      }

      if (existing['user_id'] == challengerId) {
        return DisputeResult(
          success: false,
          error: 'You already own this plate',
        );
      }

      // Check if challenger has the correct key
      if (existing['ownership_key_hash'] == challengerKeyHash) {
        // Challenger has the correct key! Transfer ownership immediately
        await _supabase
            .from('plates')
            .update({
              'user_id': challengerId,
              'verification_status': statusVerified,
              'verified_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);

        return DisputeResult(
          success: true,
          resolved: true,
          message: 'Ownership verified! Plate has been transferred to your account.',
        );
      } else {
        return DisputeResult(
          success: false,
          error: 'Invalid ownership key. You must have the original ownership key to claim this plate.',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initiate dispute: $e');
      }
      return DisputeResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Recover plate using ownership key (if you lost access to your account)
  Future<VerificationResult> recoverPlateWithKey({
    required String plateNumber,
    required String ownershipKey,
    required String newUserId,
  }) async {
    return verifyOwnership(
      plateNumber: plateNumber,
      ownershipKey: ownershipKey,
      userId: newUserId,
    );
  }

  // ===== KEY MANAGEMENT =====

  /// Generate a new ownership key (rotate key)
  Future<RotateKeyResult> rotateOwnershipKey({
    required String plateNumber,
    required String currentKey,
    required String userId,
  }) async {
    try {
      final plateHash = _hashPlateNumber(plateNumber);
      final currentKeyHash = hashOwnershipKey(currentKey);

      // Verify current key
      final record = await _supabase
          .from('plates')
          .select('id, ownership_key_hash')
          .eq('hashed_plate', plateHash)
          .eq('user_id', userId)
          .maybeSingle();

      if (record == null) {
        return RotateKeyResult(
          success: false,
          error: 'Plate not found or you don\'t own it',
        );
      }

      if (record['ownership_key_hash'] != currentKeyHash) {
        return RotateKeyResult(
          success: false,
          error: 'Current ownership key is incorrect',
        );
      }

      // Generate new key
      final newKey = generateOwnershipKey();
      final newKeyHash = hashOwnershipKey(newKey);

      // Update in database
      await _supabase
          .from('plates')
          .update({
            'ownership_key_hash': newKeyHash,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', record['id']);

      // Update local storage
      await saveKeyLocally(plateNumber: plateNumber, ownershipKey: newKey);

      return RotateKeyResult(
        success: true,
        newKey: newKey,
        message: 'Ownership key rotated. Save your new key securely!',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to rotate key: $e');
      }
      return RotateKeyResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Export all ownership keys (for backup)
  Future<String> exportKeysAsJson() async {
    final keys = await getAllLocalKeys();
    return jsonEncode(keys);
  }

  /// Import ownership keys from backup
  Future<int> importKeysFromJson(String jsonData) async {
    try {
      final keys = jsonDecode(jsonData) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      int imported = 0;

      for (final entry in keys.entries) {
        await prefs.setString(_storagePrefix + entry.key, entry.value as String);
        imported++;
      }

      return imported;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to import keys: $e');
      }
      return 0;
    }
  }
}

// ===== RESULT CLASSES =====

class RegistrationResult {
  final bool success;
  final String? ownershipKey;
  final String? message;
  final String? error;
  final bool canDispute;

  RegistrationResult({
    required this.success,
    this.ownershipKey,
    this.message,
    this.error,
    this.canDispute = false,
  });
}

class VerificationResult {
  final bool success;
  final String? message;
  final String? error;
  final bool ownershipTransferred;

  VerificationResult({
    required this.success,
    this.message,
    this.error,
    this.ownershipTransferred = false,
  });
}

class DisputeResult {
  final bool success;
  final bool resolved;
  final String? message;
  final String? error;

  DisputeResult({
    required this.success,
    this.resolved = false,
    this.message,
    this.error,
  });
}

class RotateKeyResult {
  final bool success;
  final String? newKey;
  final String? message;
  final String? error;

  RotateKeyResult({
    required this.success,
    this.newKey,
    this.message,
    this.error,
  });
}

class PlateVerificationStatus {
  final String status;
  final DateTime? verifiedAt;
  final bool hasOwnershipKey;
  final bool hasLocalKey;

  PlateVerificationStatus({
    required this.status,
    this.verifiedAt,
    required this.hasOwnershipKey,
    required this.hasLocalKey,
  });

  bool get isVerified => status == PlateVerificationService.statusVerified;
  bool get isDisputed => status == PlateVerificationService.statusDisputed;
  bool get isUnverified => status == PlateVerificationService.statusUnverified;

  /// User is fully secure if they have both server-side hash and local key
  bool get isFullySecure => hasOwnershipKey && hasLocalKey;

  /// User needs to backup their key
  bool get needsKeyBackup => hasOwnershipKey && !hasLocalKey;
}
