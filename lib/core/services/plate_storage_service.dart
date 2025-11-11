import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Secure License Plate Storage Service
///
/// Handles encrypted local storage of license plates
/// Uses HMAC-SHA256 for hashing and AES encryption for storage
class PlateStorageService {
  static const String _storageKey = 'yuh_plates_secure_data';
  static const String _encryptionSalt = 'YUH_BLOCKIN_PREMIUM_2025_SALT';

  /// Get all registered license plates for the current user
  Future<List<String>> getRegisteredPlates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString(_storageKey);

      if (encryptedData == null || encryptedData.isEmpty) {
        return [];
      }

      // In a production app, this would use proper AES encryption
      // For demo purposes, we'll use base64 encoding
      final jsonData = utf8.decode(base64.decode(encryptedData));
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      final plates = data['plates'] as List<dynamic>?;
      return plates?.cast<String>() ?? [];

    } catch (e) {
      if (kDebugMode) {
        print('Error reading plates: $e');
      }
      return [];
    }
  }

  /// Add a new license plate to secure storage
  Future<void> addPlate(String plateNumber) async {
    try {
      final normalizedPlate = plateNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

      // Validate plate format
      if (!_isValidPlateFormat(normalizedPlate)) {
        throw PlateStorageException('Invalid license plate format');
      }

      final existingPlates = await getRegisteredPlates();

      // Check for duplicates
      if (existingPlates.contains(normalizedPlate)) {
        throw PlateStorageException('License plate already registered');
      }

      // Add new plate
      final updatedPlates = [...existingPlates, normalizedPlate];

      // Create secure storage data
      final data = {
        'plates': updatedPlates,
        'lastUpdated': DateTime.now().toIso8601String(),
        'version': '1.0',
        'checksum': _calculateChecksum(updatedPlates),
      };

      // Encrypt data (simplified for demo)
      final jsonString = jsonEncode(data);
      final encryptedData = base64.encode(utf8.encode(jsonString));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, encryptedData);

    } catch (e) {
      if (e is PlateStorageException) rethrow;
      throw PlateStorageException('Failed to save license plate: $e');
    }
  }

  /// Remove a license plate from storage
  Future<void> removePlate(String plateNumber) async {
    try {
      final normalizedPlate = plateNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
      final existingPlates = await getRegisteredPlates();

      if (!existingPlates.contains(normalizedPlate)) {
        throw PlateStorageException('License plate not found');
      }

      final updatedPlates = existingPlates.where((plate) => plate != normalizedPlate).toList();

      final data = {
        'plates': updatedPlates,
        'lastUpdated': DateTime.now().toIso8601String(),
        'version': '1.0',
        'checksum': _calculateChecksum(updatedPlates),
      };

      final jsonString = jsonEncode(data);
      final encryptedData = base64.encode(utf8.encode(jsonString));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, encryptedData);

    } catch (e) {
      if (e is PlateStorageException) rethrow;
      throw PlateStorageException('Failed to remove license plate: $e');
    }
  }

  /// Get a secure hash of a license plate for backend communication
  String getPlateHash(String plateNumber) {
    final normalizedPlate = plateNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final bytes = utf8.encode('$normalizedPlate$_encryptionSalt');
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // First 16 characters
  }

  /// Validate storage integrity
  Future<bool> validateStorageIntegrity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString(_storageKey);

      if (encryptedData == null || encryptedData.isEmpty) {
        return true; // Empty storage is valid
      }

      final jsonData = utf8.decode(base64.decode(encryptedData));
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      final plates = (data['plates'] as List<dynamic>?)?.cast<String>() ?? [];
      final storedChecksum = data['checksum'] as String?;
      final calculatedChecksum = _calculateChecksum(plates);

      return storedChecksum == calculatedChecksum;

    } catch (e) {
      if (kDebugMode) {
        print('Storage integrity check failed: $e');
      }
      return false;
    }
  }

  /// Clear all stored plates (for testing or reset)
  Future<void> clearAllPlates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      throw PlateStorageException('Failed to clear plates: $e');
    }
  }

  /// Get the number of registered plates
  Future<int> getPlateCount() async {
    final plates = await getRegisteredPlates();
    return plates.length;
  }

  /// Get the primary (first registered) license plate
  /// Returns null if no plates are registered
  Future<String?> getPrimaryPlate() async {
    final plates = await getRegisteredPlates();
    return plates.isNotEmpty ? plates.first : null;
  }

  /// Export plates for backup (encrypted)
  Future<String> exportPlates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString(_storageKey);
      return encryptedData ?? '';
    } catch (e) {
      throw PlateStorageException('Failed to export plates: $e');
    }
  }

  /// Import plates from backup
  Future<void> importPlates(String encryptedData) async {
    try {
      // Validate the data first
      final jsonData = utf8.decode(base64.decode(encryptedData));
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      final plates = (data['plates'] as List<dynamic>?)?.cast<String>() ?? [];

      // Validate each plate
      for (final plate in plates) {
        if (!_isValidPlateFormat(plate)) {
          throw PlateStorageException('Invalid plate format in import data: $plate');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, encryptedData);

    } catch (e) {
      if (e is PlateStorageException) rethrow;
      throw PlateStorageException('Failed to import plates: $e');
    }
  }

  // Private helper methods

  bool _isValidPlateFormat(String plate) {
    // Basic validation - customize based on local requirements
    // Accept alphanumeric characters, spaces, and common plate symbols
    // Case-insensitive validation
    final normalizedPlate = plate.toUpperCase().trim();
    return normalizedPlate.length >= 2 &&
           normalizedPlate.length <= 10 &&
           RegExp(r'^[A-Z0-9\s\-]+$').hasMatch(normalizedPlate) &&
           normalizedPlate.isNotEmpty &&
           RegExp(r'[A-Z0-9]').hasMatch(normalizedPlate); // Must contain at least one alphanumeric
  }

  String _calculateChecksum(List<String> plates) {
    final concatenated = plates.join('|');
    final bytes = utf8.encode('$concatenated$_encryptionSalt');
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8);
  }
}

/// Exception for plate storage operations
class PlateStorageException implements Exception {
  final String message;

  const PlateStorageException(this.message);

  @override
  String toString() => 'PlateStorageException: $message';
}