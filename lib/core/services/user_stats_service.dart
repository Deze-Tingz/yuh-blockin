import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// User Statistics Service
///
/// Simple tracking service for user achievements:
/// - Cars Freed: Number of times user moved their car when notified
/// - Situations Resolved: Number of times user sent alerts to get cars moved
class UserStatsService {
  static const String _statsDataKey = 'yuh_user_stats_data';

  // Cached SharedPreferences instance for performance
  static SharedPreferences? _cachedPrefs;

  /// Get cached SharedPreferences instance
  Future<SharedPreferences> _getPrefs() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  /// Get current cars freed count
  Future<int> getCarsFreed() async {
    final stats = await getStats();
    return stats.carsFreed;
  }

  /// Get current situations resolved count
  Future<int> getSituationsResolved() async {
    final stats = await getStats();
    return stats.situationsResolved;
  }

  /// Increment cars freed counter (when user responds to an alert by moving their car)
  Future<void> incrementCarsFreed() async {
    await _incrementField('carsFreed');
  }

  /// Increment situations resolved counter (when user sends an alert)
  Future<void> incrementSituationsResolved() async {
    await _incrementField('situationsResolved');
  }

  /// Get all stats in a single call
  Future<UserStats> getStats() async {
    try {
      final prefs = await _getPrefs();
      final statsData = prefs.getString(_statsDataKey);

      if (statsData == null) {
        return UserStats(
          carsFreed: 0,
          situationsResolved: 0,
          alertsSent: 0,
          alertsReceived: 0,
        );
      }

      final data = jsonDecode(statsData) as Map<String, dynamic>;
      return UserStats(
        carsFreed: data['carsFreed'] as int? ?? 0,
        situationsResolved: data['situationsResolved'] as int? ?? 0,
        alertsSent: data['alertsSent'] as int? ?? 0,
        alertsReceived: data['alertsReceived'] as int? ?? 0,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user stats: $e');
      }
      return UserStats(
        carsFreed: 0,
        situationsResolved: 0,
        alertsSent: 0,
        alertsReceived: 0,
      );
    }
  }

  /// Increment alerts sent counter
  Future<void> incrementAlertsSent() async {
    await _incrementField('alertsSent');
  }

  /// Increment alerts received counter
  Future<void> incrementAlertsReceived() async {
    await _incrementField('alertsReceived');
  }

  /// Atomic increment of a single field (avoids N+1 read pattern)
  Future<void> _incrementField(String fieldName) async {
    try {
      final prefs = await _getPrefs();
      final statsData = prefs.getString(_statsDataKey);

      Map<String, dynamic> data;
      if (statsData == null) {
        data = {
          'carsFreed': 0,
          'situationsResolved': 0,
          'alertsSent': 0,
          'alertsReceived': 0,
        };
      } else {
        data = Map<String, dynamic>.from(jsonDecode(statsData));
      }

      // Increment only the specified field
      data[fieldName] = (data[fieldName] as int? ?? 0) + 1;
      data['lastUpdated'] = DateTime.now().toIso8601String();

      await prefs.setString(_statsDataKey, jsonEncode(data));
    } catch (e) {
      if (kDebugMode) {
        print('Error incrementing $fieldName: $e');
      }
    }
  }

  /// Private helper to save stats data
  Future<void> _saveStatsData({
    required int carsFreed,
    required int situationsResolved,
    int? alertsSent,
    int? alertsReceived,
  }) async {
    final prefs = await _getPrefs();
    final data = {
      'carsFreed': carsFreed,
      'situationsResolved': situationsResolved,
      'alertsSent': alertsSent ?? 0,
      'alertsReceived': alertsReceived ?? 0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_statsDataKey, jsonEncode(data));
  }

  /// Reset all stats (for testing or user preference)
  Future<void> resetStats() async {
    final prefs = await _getPrefs();
    await prefs.remove(_statsDataKey);
  }
}

/// Simple data class for user statistics
class UserStats {
  final int carsFreed;
  final int situationsResolved;
  final int alertsSent;
  final int alertsReceived;

  UserStats({
    required this.carsFreed,
    required this.situationsResolved,
    this.alertsSent = 0,
    this.alertsReceived = 0,
  });

  /// Get total positive impact count
  int get totalImpact => carsFreed + situationsResolved;

  /// Get a friendly description of the user's impact
  String get impactDescription {
    if (totalImpact == 0) {
      return "Ready to make a positive parking impact!";
    } else if (totalImpact == 1) {
      return "Made your first positive parking impact! 🌟";
    } else if (totalImpact < 10) {
      return "Building a respectful parking community! ✨";
    } else if (totalImpact < 50) {
      return "Parking community champion! 🏆";
    } else {
      return "Legendary parking problem solver! 👑";
    }
  }
}