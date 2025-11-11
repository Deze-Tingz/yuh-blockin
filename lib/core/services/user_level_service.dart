import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// User Level and Progression Service
///
/// Manages user leveling, emoji unlocks, and achievement tracking.
/// XP gained through using the app respectfully.
class UserLevelService {
  static const String _levelDataKey = 'yuh_user_level_data';
  static const String _unlockedEmojisKey = 'yuh_unlocked_emojis';

  // XP required for each level (exponential growth)
  static const Map<int, int> xpRequiredForLevel = {
    1: 0,
    2: 100,    // First emoji unlock
    3: 250,    // Second emoji unlock
    4: 450,    // Third emoji unlock
    5: 700,    // Fourth emoji unlock
    6: 1000,   // Fifth emoji unlock
    7: 1350,   // Sixth emoji unlock
    8: 1750,   // Seventh emoji unlock
    9: 2200,   // Eighth emoji unlock
    10: 2700,  // Ninth emoji unlock
    11: 3250,  // Tenth emoji unlock
    12: 3850,  // Eleventh emoji unlock
    13: 4500,  // Final Gen Z emoji unlock
  };

  /// Get current user level
  Future<int> getCurrentLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final levelData = prefs.getString(_levelDataKey);

      if (levelData == null) {
        return 1; // Starting level
      }

      final data = jsonDecode(levelData) as Map<String, dynamic>;
      return data['level'] as int? ?? 1;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current level: $e');
      }
      return 1;
    }
  }

  /// Get current user XP
  Future<int> getCurrentXP() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final levelData = prefs.getString(_levelDataKey);

      if (levelData == null) {
        return 0; // Starting XP
      }

      final data = jsonDecode(levelData) as Map<String, dynamic>;
      return data['xp'] as int? ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current XP: $e');
      }
      return 0;
    }
  }

  /// Add XP and check for level ups
  Future<LevelUpResult> addXP(int xpToAdd) async {
    try {
      final currentLevel = await getCurrentLevel();
      final currentXP = await getCurrentXP();

      final newXP = currentXP + xpToAdd;
      int newLevel = currentLevel;
      List<String> newlyUnlockedEmojis = [];

      // Check for level ups
      for (int level = currentLevel + 1; level <= xpRequiredForLevel.length; level++) {
        if (newXP >= (xpRequiredForLevel[level] ?? 999999)) {
          newLevel = level;

          // Unlock emoji for this level
          final emojiId = _getEmojiIdForLevel(level);
          if (emojiId != null) {
            await _unlockEmoji(emojiId);
            newlyUnlockedEmojis.add(emojiId);
          }
        } else {
          break;
        }
      }

      // Save new level and XP
      await _saveLevelData(newLevel, newXP);

      return LevelUpResult(
        oldLevel: currentLevel,
        newLevel: newLevel,
        currentXP: newXP,
        leveledUp: newLevel > currentLevel,
        newlyUnlockedEmojis: newlyUnlockedEmojis,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error adding XP: $e');
      }
      return LevelUpResult(
        oldLevel: 1,
        newLevel: 1,
        currentXP: 0,
        leveledUp: false,
        newlyUnlockedEmojis: [],
      );
    }
  }

  /// Get XP needed for next level
  Future<int> getXPForNextLevel() async {
    final currentLevel = await getCurrentLevel();
    final nextLevel = currentLevel + 1;
    return xpRequiredForLevel[nextLevel] ?? 999999;
  }

  /// Get progress to next level (0.0 to 1.0)
  Future<double> getProgressToNextLevel() async {
    final currentXP = await getCurrentXP();
    final currentLevel = await getCurrentLevel();

    final currentLevelXP = xpRequiredForLevel[currentLevel] ?? 0;
    final nextLevelXP = xpRequiredForLevel[currentLevel + 1] ?? currentLevelXP;

    if (nextLevelXP == currentLevelXP) {
      return 1.0; // Max level reached
    }

    final progressXP = currentXP - currentLevelXP;
    final totalXPNeeded = nextLevelXP - currentLevelXP;

    return (progressXP / totalXPNeeded).clamp(0.0, 1.0);
  }

  /// Check if an emoji is unlocked
  Future<bool> isEmojiUnlocked(String emojiId) async {
    try {
      final unlockedEmojis = await getUnlockedEmojis();
      return unlockedEmojis.contains(emojiId);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking emoji unlock: $e');
      }
      return false;
    }
  }

  /// Get all unlocked emoji IDs
  Future<List<String>> getUnlockedEmojis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedData = prefs.getStringList(_unlockedEmojisKey);
      return unlockedData ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting unlocked emojis: $e');
      }
      return [];
    }
  }

  // Private helper methods

  Future<void> _saveLevelData(int level, int xp) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'level': level,
      'xp': xp,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_levelDataKey, jsonEncode(data));
  }

  Future<void> _unlockEmoji(String emojiId) async {
    final currentUnlocked = await getUnlockedEmojis();
    if (!currentUnlocked.contains(emojiId)) {
      currentUnlocked.add(emojiId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_unlockedEmojisKey, currentUnlocked);
    }
  }

  String? _getEmojiIdForLevel(int level) {
    // Map levels to Gen Z emoji IDs (in order of unlock)
    const emojiUnlockOrder = [
      'chill_coconut',      // Level 2
      'wave_surf',          // Level 3
      'palm_sway',          // Level 4
      'sunset_aesthetic',   // Level 5
      'pineapple_crown',    // Level 6
      'tropical_flow',      // Level 7
      'hibiscus_soft',      // Level 8
      'tiki_wisdom',        // Level 9
      'shell_treasure',     // Level 10
      'volcano_energy',     // Level 11
      'flamingo_stance',    // Level 12
      'shaved_ice_chill',   // Level 13
    ];

    if (level >= 2 && level <= 13) {
      return emojiUnlockOrder[level - 2];
    }

    return null;
  }

  /// Reset user progress (for testing)
  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_levelDataKey);
    await prefs.remove(_unlockedEmojisKey);
  }

  /// Give XP for different actions
  static const int xpForSendingAlert = 25;
  static const int xpForReceivingPositiveResponse = 50;
  static const int xpForUsingRespectfulTone = 15;
  static const int xpForQuickResolution = 30;
}

/// Result of adding XP and potential level up
class LevelUpResult {
  final int oldLevel;
  final int newLevel;
  final int currentXP;
  final bool leveledUp;
  final List<String> newlyUnlockedEmojis;

  LevelUpResult({
    required this.oldLevel,
    required this.newLevel,
    required this.currentXP,
    required this.leveledUp,
    required this.newlyUnlockedEmojis,
  });
}

/// User Level Exception
class UserLevelException implements Exception {
  final String message;

  const UserLevelException(this.message);

  @override
  String toString() => 'UserLevelException: $message';
}