import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

/// Service for generating and managing random user aliases
/// Provides privacy-friendly user identification without exposing license plates
class UserAliasService {
  static const String _storageKey = 'yuh_user_aliases_data';
  static const String _myAliasKey = 'yuh_my_alias_data';

  // Pool of adjectives and nouns for generating aliases
  static const List<String> _adjectives = [
    'Swift', 'Quick', 'Bright', 'Sharp', 'Cool', 'Smooth', 'Fast', 'Smart',
    'Bold', 'Wise', 'Calm', 'Strong', 'Lucky', 'Happy', 'Brave', 'Kind',
    'Clever', 'Steady', 'Gentle', 'Noble', 'Pure', 'Wild', 'Free', 'True',
    'Golden', 'Silver', 'Crystal', 'Mighty', 'Proud', 'Royal', 'Elite', 'Prime',
    'Super', 'Ultra', 'Mega', 'Turbo', 'Hyper', 'Zen', 'Alpha', 'Beta'
  ];

  static const List<String> _nouns = [
    'Driver', 'Rider', 'Parker', 'Cruiser', 'Pilot', 'Captain', 'Chief', 'Hero',
    'Guardian', 'Warrior', 'Knight', 'Ranger', 'Scout', 'Hunter', 'Seeker', 'Runner',
    'Eagle', 'Hawk', 'Wolf', 'Lion', 'Tiger', 'Bear', 'Fox', 'Owl',
    'Storm', 'Thunder', 'Lightning', 'Wind', 'Fire', 'Star', 'Moon', 'Sun',
    'Mountain', 'Ocean', 'River', 'Forest', 'Valley', 'Peak', 'Rock', 'Stone'
  ];

  /// Generate a random alias
  String _generateRandomAlias() {
    final random = Random();
    final adjective = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    final number = random.nextInt(999) + 1; // 1-999

    return '$adjective$noun$number';
  }

  /// Get or create alias for the current user
  Future<String> getMyAlias() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we already have an alias
    final existingAlias = prefs.getString(_myAliasKey);
    if (existingAlias != null) {
      return existingAlias;
    }

    // Generate new alias
    final newAlias = _generateRandomAlias();
    await prefs.setString(_myAliasKey, newAlias);

    return newAlias;
  }

  /// Get or create alias for any user ID
  Future<String> getAliasForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    // Load existing aliases map
    final aliasesJson = prefs.getString(_storageKey);
    Map<String, String> aliases = {};

    if (aliasesJson != null) {
      try {
        final data = jsonDecode(aliasesJson) as Map<String, dynamic>;
        aliases = data.cast<String, String>();
      } catch (e) {
        print('Error loading aliases: $e');
      }
    }

    // Check if alias already exists for this user
    if (aliases.containsKey(userId)) {
      return aliases[userId]!;
    }

    // Generate new unique alias
    String newAlias;
    int attempts = 0;
    do {
      newAlias = _generateRandomAlias();
      attempts++;
    } while (aliases.values.contains(newAlias) && attempts < 10);

    // If we couldn't find a unique alias in 10 attempts, add a timestamp suffix
    if (aliases.values.contains(newAlias)) {
      newAlias = '${newAlias}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    }

    // Save the new alias
    aliases[userId] = newAlias;
    await prefs.setString(_storageKey, jsonEncode(aliases));

    return newAlias;
  }

  /// Clear all stored aliases (for testing or reset)
  Future<void> clearAllAliases() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_myAliasKey);
  }

  /// Get all stored aliases (for debugging)
  Future<Map<String, String>> getAllAliases() async {
    final prefs = await SharedPreferences.getInstance();
    final aliasesJson = prefs.getString(_storageKey);

    if (aliasesJson == null) return {};

    try {
      final data = jsonDecode(aliasesJson) as Map<String, dynamic>;
      return data.cast<String, String>();
    } catch (e) {
      print('Error loading aliases: $e');
      return {};
    }
  }

  /// Format alias for display (add emoji prefix for visual appeal)
  String formatAliasForDisplay(String alias) {
    // Add a car emoji or user emoji to make it more visual
    return '🚗 $alias';
  }
}