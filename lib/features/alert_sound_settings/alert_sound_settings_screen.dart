import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../core/theme/premium_theme.dart';
import '../../core/services/sound_preferences_service.dart';

/// Premium alert sound settings screen
/// Allows users to customize alert sounds for Low, Normal, and High urgency levels
class AlertSoundSettingsScreen extends StatefulWidget {
  const AlertSoundSettingsScreen({super.key});

  @override
  State<AlertSoundSettingsScreen> createState() => _AlertSoundSettingsScreenState();
}

class _AlertSoundSettingsScreenState extends State<AlertSoundSettingsScreen> {
  final SoundPreferencesService _soundService = SoundPreferencesService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Currently selected sounds per level
  String _selectedLowSound = SoundPreferencesService.defaultLowSound;
  String _selectedNormalSound = SoundPreferencesService.defaultNormalSound;
  String _selectedHighSound = SoundPreferencesService.defaultHighSound;

  // Currently playing sound (for UI feedback)
  String? _playingSound;

  // Urgency level colors
  static const Color _lowColor = Color(0xFF34D399); // Green
  static const Color _normalColor = Color(0xFF0A84FF); // Blue
  static const Color _highColor = Color(0xFFEF4444); // Red

  @override
  void initState() {
    super.initState();
    _loadSavedSounds();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSounds() async {
    final low = await _soundService.getSoundForLevel('Low');
    final normal = await _soundService.getSoundForLevel('Normal');
    final high = await _soundService.getSoundForLevel('High');

    if (mounted) {
      setState(() {
        _selectedLowSound = low;
        _selectedNormalSound = normal;
        _selectedHighSound = high;
      });
    }
  }

  Future<void> _playSound(String path) async {
    try {
      setState(() => _playingSound = path);
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(path));

      // Reset playing state after sound completes (approx 2 seconds)
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _playingSound = null);
        }
      });
    } catch (e) {
      debugPrint('Failed to play sound: $e');
      if (mounted) {
        setState(() => _playingSound = null);
      }
    }
  }

  Future<void> _selectSound(String level, String path) async {
    HapticFeedback.lightImpact();

    setState(() {
      switch (level.toLowerCase()) {
        case 'low':
          _selectedLowSound = path;
          break;
        case 'normal':
          _selectedNormalSound = path;
          break;
        case 'high':
          _selectedHighSound = path;
          break;
      }
    });

    await _soundService.setSoundForLevel(level, path);
    await _playSound(path);
  }

  String _getSelectedSound(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return _selectedLowSound;
      case 'normal':
        return _selectedNormalSound;
      case 'high':
        return _selectedHighSound;
      default:
        return _selectedNormalSound;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: PremiumTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: PremiumTheme.primaryTextColor,
          ),
        ),
        title: Text(
          'Alert Sounds',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: PremiumTheme.primaryTextColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Customize Alerts',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose different sounds for each alert urgency level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 32),

              // Low urgency section
              _buildUrgencySection(
                level: 'Low',
                color: _lowColor,
                icon: Icons.notifications_none_outlined,
                description: 'For gentle reminders',
              ),

              const SizedBox(height: 24),

              // Normal urgency section
              _buildUrgencySection(
                level: 'Normal',
                color: _normalColor,
                icon: Icons.notifications_outlined,
                description: 'Standard alert tone',
              ),

              const SizedBox(height: 24),

              // High urgency section
              _buildUrgencySection(
                level: 'High',
                color: _highColor,
                icon: Icons.notification_important_outlined,
                description: 'For urgent situations',
              ),

              const SizedBox(height: 32),

              // Footer
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 1,
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PremiumTheme.accentColor.withValues(alpha: 0.0),
                            PremiumTheme.accentColor.withValues(alpha: 0.3),
                            PremiumTheme.accentColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to preview and select',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: PremiumTheme.tertiaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrgencySection({
    required String level,
    required Color color,
    required IconData icon,
    required String description,
  }) {
    final sounds = SoundPreferencesService.getSoundsForLevel(level);
    final selectedSound = _getSelectedSound(level);

    return Container(
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$level Urgency',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: PremiumTheme.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: PremiumTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: PremiumTheme.dividerColor,
          ),

          // Sound options
          ...sounds.map((sound) => _buildSoundOption(
                level: level,
                label: sound['label']!,
                path: sound['path']!,
                color: color,
                isSelected: selectedSound == sound['path'],
              )),
        ],
      ),
    );
  }

  Widget _buildSoundOption({
    required String level,
    required String label,
    required String path,
    required Color color,
    required bool isSelected,
  }) {
    final isPlaying = _playingSound == path;

    return GestureDetector(
      onTap: () => _selectSound(level, path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: PremiumTheme.dividerColor.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Play indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isPlaying
                    ? color.withValues(alpha: 0.2)
                    : PremiumTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPlaying ? color : PremiumTheme.dividerColor,
                  width: 1,
                ),
              ),
              child: Icon(
                isPlaying ? Icons.volume_up : Icons.play_arrow,
                color: isPlaying ? color : PremiumTheme.secondaryTextColor,
                size: 18,
              ),
            ),

            const SizedBox(width: 12),

            // Sound label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? color : PremiumTheme.primaryTextColor,
                ),
              ),
            ),

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : PremiumTheme.tertiaryTextColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
