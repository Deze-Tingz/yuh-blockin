import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing alert sound preferences per urgency level
/// Stores user's selected alert sounds for Low, Normal, and High urgency alerts
class SoundPreferencesService {
  // SharedPreferences keys
  static const String _lowSoundKey = 'alert_sound_low';
  static const String _normalSoundKey = 'alert_sound_normal';
  static const String _highSoundKey = 'alert_sound_high';

  // Default sounds per level
  static const String defaultLowSound = 'sounds/low/low_alert_1.wav';
  static const String defaultNormalSound = 'sounds/normal/normal_alert.wav';
  static const String defaultHighSound = 'sounds/high/high_alert_1.wav';

  // Available sounds per urgency level
  static const List<Map<String, String>> lowSounds = [
    {'label': 'Alert 1', 'path': 'sounds/low/low_alert_1.wav'},
    {'label': 'Alert 2', 'path': 'sounds/low/low_alert_2.wav'},
    {'label': 'Alert 3', 'path': 'sounds/low/low_alert_3.wav'},
  ];

  static const List<Map<String, String>> normalSounds = [
    {'label': 'Alert 1', 'path': 'sounds/normal/normal_alert.wav'},
  ];

  static const List<Map<String, String>> highSounds = [
    {'label': 'Alert 1', 'path': 'sounds/high/high_alert_1.wav'},
    {'label': 'Alert 2', 'path': 'sounds/high/high_alert_2.wav'},
  ];

  /// Get sounds list for a given urgency level
  static List<Map<String, String>> getSoundsForLevel(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return lowSounds;
      case 'normal':
        return normalSounds;
      case 'high':
        return highSounds;
      default:
        return normalSounds;
    }
  }

  /// Get the currently selected sound path for a given urgency level
  Future<String> getSoundForLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();

    switch (level.toLowerCase()) {
      case 'low':
        return prefs.getString(_lowSoundKey) ?? defaultLowSound;
      case 'normal':
        return prefs.getString(_normalSoundKey) ?? defaultNormalSound;
      case 'high':
        return prefs.getString(_highSoundKey) ?? defaultHighSound;
      default:
        return prefs.getString(_normalSoundKey) ?? defaultNormalSound;
    }
  }

  /// Set the sound path for a given urgency level
  Future<void> setSoundForLevel(String level, String path) async {
    final prefs = await SharedPreferences.getInstance();

    switch (level.toLowerCase()) {
      case 'low':
        await prefs.setString(_lowSoundKey, path);
        break;
      case 'normal':
        await prefs.setString(_normalSoundKey, path);
        break;
      case 'high':
        await prefs.setString(_highSoundKey, path);
        break;
    }
  }

  /// Get the label for a sound path
  static String getLabelForPath(String level, String path) {
    final sounds = getSoundsForLevel(level);
    for (final sound in sounds) {
      if (sound['path'] == path) {
        return sound['label'] ?? 'Unknown';
      }
    }
    return 'Alert 1';
  }

  /// Get default sound for a level
  static String getDefaultForLevel(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return defaultLowSound;
      case 'normal':
        return defaultNormalSound;
      case 'high':
        return defaultHighSound;
      default:
        return defaultNormalSound;
    }
  }
}
