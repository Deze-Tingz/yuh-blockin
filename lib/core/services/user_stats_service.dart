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

  /// Get current cars freed count
  Future<int> getCarsFreed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsData = prefs.getString(_statsDataKey);

      if (statsData == null) {
        return 0;
      }

      final data = jsonDecode(statsData) as Map<String, dynamic>;
      return data['carsFreed'] as int? ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cars freed count: $e');
      }
      return 0;
    }
  }

  /// Get current situations resolved count
  Future<int> getSituationsResolved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsData = prefs.getString(_statsDataKey);

      if (statsData == null) {
        return 0;
      }

      final data = jsonDecode(statsData) as Map<String, dynamic>;
      return data['situationsResolved'] as int? ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting situations resolved count: $e');
      }
      return 0;
    }
  }

  /// Increment cars freed counter (when user responds to an alert by moving their car)
  Future<void> incrementCarsFreed() async {
    try {
      final currentCarsFreed = await getCarsFreed();
      final currentSituationsResolved = await getSituationsResolved();

      await _saveStatsData(
        carsFreed: currentCarsFreed + 1,
        situationsResolved: currentSituationsResolved,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error incrementing cars freed: $e');
      }
    }
  }

  /// Increment situations resolved counter (when user sends an alert)
  Future<void> incrementSituationsResolved() async {
    try {
      final currentCarsFreed = await getCarsFreed();
      final currentSituationsResolved = await getSituationsResolved();

      await _saveStatsData(
        carsFreed: currentCarsFreed,
        situationsResolved: currentSituationsResolved + 1,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error incrementing situations resolved: $e');
      }
    }
  }

  /// Get both stats in a single call
  Future<UserStats> getStats() async {
    try {
      final carsFreed = await getCarsFreed();
      final situationsResolved = await getSituationsResolved();

      return UserStats(
        carsFreed: carsFreed,
        situationsResolved: situationsResolved,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user stats: $e');
      }
      return UserStats(carsFreed: 0, situationsResolved: 0);
    }
  }

  /// Private helper to save stats data
  Future<void> _saveStatsData({
    required int carsFreed,
    required int situationsResolved,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'carsFreed': carsFreed,
      'situationsResolved': situationsResolved,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_statsDataKey, jsonEncode(data));
  }

  /// Reset all stats (for testing or user preference)
  Future<void> resetStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsDataKey);
  }
}

/// Simple data class for user statistics
class UserStats {
  final int carsFreed;
  final int situationsResolved;

  UserStats({
    required this.carsFreed,
    required this.situationsResolved,
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