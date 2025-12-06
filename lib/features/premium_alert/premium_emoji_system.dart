import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/premium_theme.dart';

/// Premium Animated Emoji Expression System
///
/// Curated set of high-quality animated emojis with Telegram Premium-level
/// animation quality. Each emoji conveys emotional tone through motion.
///
/// Final alert format: [Selected Animated Emoji] + "Yuh Blockin'!"
class PremiumEmojiExpression {
  final String id;
  final String unicode;
  final String title;
  final String description;
  final Color accentColor;
  final EmojiAnimationType animationType;
  final int urgencyLevel; // 1-5 scale

  const PremiumEmojiExpression({
    required this.id,
    required this.unicode,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.animationType,
    required this.urgencyLevel,
  });
}

/// Animation types for premium emoji expressions
enum EmojiAnimationType {
  gentle,      // Calm floating motion
  playful,     // Bouncy, friendly motion
  pulse,       // Rhythmic attention-getting
  urgent,      // Sharp, immediate motion
  apologetic,  // Subtle, humble motion
  celebration, // Joyful, expansive motion
}

/// Gen Z Island Vibes Emoji Pack - Trendy island-themed expressions
class GenZIslandEmojiPack {
  static const List<PremiumEmojiExpression> expressions = [
    // Chill beach vibes - "no worries, just island time"
    PremiumEmojiExpression(
      id: 'chill_coconut',
      unicode: '🥥',
      title: 'Coconut Chill',
      description: 'Total island vibes - no rush, just chill',
      accentColor: Color(0xFF10B981), // Tropical green
      animationType: EmojiAnimationType.gentle,
      urgencyLevel: 1,
    ),

    // Surf wave energy - playful but respectful
    PremiumEmojiExpression(
      id: 'wave_surf',
      unicode: '🌊',
      title: 'Wave Check',
      description: 'Surf vibes - respectful but confident',
      accentColor: Color(0xFF0EA5E9), // Ocean blue
      animationType: EmojiAnimationType.playful,
      urgencyLevel: 2,
    ),

    // Palm tree sway - gentle reminder
    PremiumEmojiExpression(
      id: 'palm_sway',
      unicode: '🌴',
      title: 'Palm Sway',
      description: 'Tropical reminder with good vibes',
      accentColor: Color(0xFF22C55E), // Fresh green
      animationType: EmojiAnimationType.gentle,
      urgencyLevel: 2,
    ),

    // Island sunset energy - aesthetic alert
    PremiumEmojiExpression(
      id: 'sunset_aesthetic',
      unicode: '🌅',
      title: 'Sunset Energy',
      description: 'Aesthetic vibes with gentle urgency',
      accentColor: Color(0xFFFF6B35), // Sunset orange
      animationType: EmojiAnimationType.pulse,
      urgencyLevel: 3,
    ),

    // Pineapple crown energy - main character moment
    PremiumEmojiExpression(
      id: 'pineapple_crown',
      unicode: '🍍',
      title: 'Pineapple Crown',
      description: 'Main character energy - respectful but firm',
      accentColor: Color(0xFFFBBF24), // Golden yellow
      animationType: EmojiAnimationType.playful,
      urgencyLevel: 3,
    ),

    // Tropical fish flowing - smooth operator
    PremiumEmojiExpression(
      id: 'tropical_flow',
      unicode: '🐠',
      title: 'Tropical Flow',
      description: 'Smooth operator vibes - going with the flow',
      accentColor: Color(0xFF06B6D4), // Cyan
      animationType: EmojiAnimationType.gentle,
      urgencyLevel: 2,
    ),

    // Hibiscus flower - soft feminine energy
    PremiumEmojiExpression(
      id: 'hibiscus_soft',
      unicode: '🌺',
      title: 'Hibiscus Softness',
      description: 'Soft feminine energy - gentle but clear',
      accentColor: Color(0xFFEC4899), // Pink
      animationType: EmojiAnimationType.gentle,
      urgencyLevel: 1,
    ),

    // Tiki mask - ancestral wisdom vibes
    PremiumEmojiExpression(
      id: 'tiki_wisdom',
      unicode: '🗿',
      title: 'Tiki Wisdom',
      description: 'Ancient wisdom meets modern respect',
      accentColor: Color(0xFF8B5A2B), // Earth tone
      animationType: EmojiAnimationType.apologetic,
      urgencyLevel: 2,
    ),

    // Seashell treasure - beachy gratitude
    PremiumEmojiExpression(
      id: 'shell_treasure',
      unicode: '🐚',
      title: 'Shell Treasure',
      description: 'Grateful beach energy - appreciative vibes',
      accentColor: Color(0xFFDDD6FE), // Lavender
      animationType: EmojiAnimationType.celebration,
      urgencyLevel: 1,
    ),

    // Volcano energy - island intensity (rare use)
    PremiumEmojiExpression(
      id: 'volcano_energy',
      unicode: '🌋',
      title: 'Volcano Energy',
      description: 'Island intensity - when situations get real',
      accentColor: Color(0xFFEF4444), // Hot red
      animationType: EmojiAnimationType.urgent,
      urgencyLevel: 5,
    ),

    // Flamingo stance - standing on business
    PremiumEmojiExpression(
      id: 'flamingo_stance',
      unicode: '🦩',
      title: 'Flamingo Stance',
      description: 'Standing on business - elegant but firm',
      accentColor: Color(0xFFF472B6), // Hot pink
      animationType: EmojiAnimationType.pulse,
      urgencyLevel: 4,
    ),

    // Shaved ice chill - ultimate relaxation
    PremiumEmojiExpression(
      id: 'shaved_ice_chill',
      unicode: '🍧',
      title: 'Shaved Ice Chill',
      description: 'Ultimate chill vibes - maximum relaxation',
      accentColor: Color(0xFF7DD3FC), // Sky blue
      animationType: EmojiAnimationType.gentle,
      urgencyLevel: 1,
    ),
  ];

  /// Get expressions filtered by urgency level
  static List<PremiumEmojiExpression> getByUrgency(int maxUrgency) {
    return expressions.where((expr) => expr.urgencyLevel <= maxUrgency).toList();
  }

  /// Get expression by ID
  static PremiumEmojiExpression? getById(String id) {
    try {
      return expressions.firstWhere((expr) => expr.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get default expression for urgency level with Gen Z island vibes
  static PremiumEmojiExpression getDefaultForUrgency(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'low':
        return expressions[0]; // Coconut Chill
      case 'medium':
        return expressions[1]; // Wave Check
      case 'high':
        return expressions[10]; // Flamingo Stance
      default:
        return expressions[0];
    }
  }
}

/// Classic Premium Emoji Pack - Original curated expressions
class PremiumEmojiPack {
  static const List<PremiumEmojiExpression> expressions = [
    // Calm / polite alert
    PremiumEmojiExpression(
      id: 'calm_wave',
      unicode: '👋',
      title: 'Polite Wave',
      description: 'Calm, respectful notification',
      accentColor: Color(0xFF34D399), // Emerald
      animationType: EmojiAnimationType.gentle,
      urgencyLevel: 1,
    ),

    // Friendly / playful nudge
    PremiumEmojiExpression(
      id: 'friendly_smile',
      unicode: '😊',
      title: 'Friendly Smile',
      description: 'Playful, warm approach',
      accentColor: Color(0xFFFBBF24), // Amber
      animationType: EmojiAnimationType.playful,
      urgencyLevel: 2,
    ),

    // Slight urgency
    PremiumEmojiExpression(
      id: 'gentle_point',
      unicode: '👆',
      title: 'Gentle Point',
      description: 'Mild urgency, still friendly',
      accentColor: Color(0xFF3B82F6), // Blue
      animationType: EmojiAnimationType.pulse,
      urgencyLevel: 3,
    ),

    // Serious urgency
    PremiumEmojiExpression(
      id: 'urgent_attention',
      unicode: '⚠️',
      title: 'Urgent Alert',
      description: 'Immediate attention needed',
      accentColor: Color(0xFFF59E0B), // Orange
      animationType: EmojiAnimationType.urgent,
      urgencyLevel: 4,
    ),

    // Emergency urgency
    PremiumEmojiExpression(
      id: 'emergency_stop',
      unicode: '🚨',
      title: 'Emergency',
      description: 'Critical blocking situation',
      accentColor: Color(0xFFEF4444), // Red
      animationType: EmojiAnimationType.urgent,
      urgencyLevel: 5,
    ),

    // Apology / "on my way"
    PremiumEmojiExpression(
      id: 'apologetic_sorry',
      unicode: '🙏',
      title: 'Apologetic',
      description: 'Sorry for the inconvenience',
      accentColor: Color(0xFF8B5CF6), // Purple
      animationType: EmojiAnimationType.apologetic,
      urgencyLevel: 1,
    ),

    // Resolution / celebration
    PremiumEmojiExpression(
      id: 'celebration_party',
      unicode: '🎉',
      title: 'Celebration',
      description: 'Problem resolved, thank you!',
      accentColor: Color(0xFF10B981), // Green
      animationType: EmojiAnimationType.celebration,
      urgencyLevel: 1,
    ),

    // Professional acknowledgment
    PremiumEmojiExpression(
      id: 'professional_check',
      unicode: '✅',
      title: 'Acknowledged',
      description: 'Professional confirmation',
      accentColor: Color(0xFF059669), // Emerald-600
      animationType: EmojiAnimationType.gentle,
      urgencyLevel: 2,
    ),

    // Time-sensitive
    PremiumEmojiExpression(
      id: 'time_clock',
      unicode: '⏰',
      title: 'Time Sensitive',
      description: 'Respectful time reminder',
      accentColor: Color(0xFF7C3AED), // Violet
      animationType: EmojiAnimationType.pulse,
      urgencyLevel: 3,
    ),
  ];

  /// Get expressions filtered by urgency level
  static List<PremiumEmojiExpression> getByUrgency(int maxUrgency) {
    return expressions.where((expr) => expr.urgencyLevel <= maxUrgency).toList();
  }

  /// Get expression by ID
  static PremiumEmojiExpression? getById(String id) {
    try {
      return expressions.firstWhere((expr) => expr.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get default expression for urgency level
  static PremiumEmojiExpression getDefaultForUrgency(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'low':
        return expressions[0]; // Polite Wave
      case 'medium':
        return expressions[1]; // Friendly Smile
      case 'high':
        return expressions[3]; // Urgent Alert
      default:
        return expressions[0];
    }
  }
}

/// Premium animated emoji widget with Manim-quality animations
class AnimatedEmojiWidget extends StatefulWidget {
  final PremiumEmojiExpression expression;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback? onTap;
  final double size;

  const AnimatedEmojiWidget({
    super.key,
    required this.expression,
    this.isSelected = false,
    this.isPlaying = false,
    this.onTap,
    this.size = 60,
  });

  @override
  State<AnimatedEmojiWidget> createState() => _AnimatedEmojiWidgetState();
}

class _AnimatedEmojiWidgetState extends State<AnimatedEmojiWidget>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _selectionController;
  late AnimationController _playController;

  late Animation<double> _primaryAnimation;
  late Animation<double> _selectionAnimation;
  late Animation<double> _playAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startPrimaryAnimation();
  }

  void _initializeAnimations() {
    // Primary continuous animation based on type
    final duration = _getDurationForType(widget.expression.animationType);
    _primaryController = AnimationController(duration: duration, vsync: this);

    // Selection state animation
    _selectionController = AnimationController(
      duration: PremiumTheme.fastDuration,
      vsync: this,
    );

    // Play animation for preview
    _playController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _primaryAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _primaryController, curve: Curves.easeInOut),
    );

    _selectionAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _selectionController, curve: Curves.elasticOut),
    );

    _playAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _playController, curve: Curves.elasticInOut),
    );
  }

  Duration _getDurationForType(EmojiAnimationType type) {
    switch (type) {
      case EmojiAnimationType.gentle:
        return const Duration(seconds: 3);
      case EmojiAnimationType.playful:
        return const Duration(milliseconds: 1200);
      case EmojiAnimationType.pulse:
        return const Duration(milliseconds: 1000);
      case EmojiAnimationType.urgent:
        return const Duration(milliseconds: 600);
      case EmojiAnimationType.apologetic:
        return const Duration(seconds: 2);
      case EmojiAnimationType.celebration:
        return const Duration(milliseconds: 800);
    }
  }

  void _startPrimaryAnimation() {
    if (widget.expression.animationType == EmojiAnimationType.urgent ||
        widget.expression.animationType == EmojiAnimationType.pulse) {
      _primaryController.repeat(reverse: true);
    } else {
      _primaryController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedEmojiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Safety check to prevent animation errors
    if (!mounted) return;

    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _selectionController.forward();
      } else {
        _selectionController.reverse();
      }
    }

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _playController.forward();
      } else {
        _playController.reverse();
      }
    }

    // Restart primary animation if expression changed
    if (widget.expression.id != oldWidget.expression.id) {
      _primaryController.reset();
      _startPrimaryAnimation();
    }
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _selectionController.dispose();
    _playController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _primaryAnimation,
          _selectionAnimation,
          _playAnimation,
        ]),
        builder: (context, child) {
          return Container(
            width: widget.size + 20,
            height: widget.size + 20,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.expression.accentColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular((widget.size + 20) / 2),
              border: widget.isSelected
                  ? Border.all(
                      color: widget.expression.accentColor.withValues(alpha: 0.3),
                      width: 2,
                    )
                  : null,
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.expression.accentColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Transform.translate(
                offset: _getAnimatedOffset(),
                child: Transform.rotate(
                  angle: _getAnimatedRotation(),
                  child: Text(
                    widget.expression.unicode,
                    style: TextStyle(
                      fontSize: widget.size,
                      
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Offset _getAnimatedOffset() {
    switch (widget.expression.animationType) {
      case EmojiAnimationType.gentle:
        return Offset(0, math.sin(_primaryAnimation.value * 2 * math.pi) * 2);
      case EmojiAnimationType.playful:
        return Offset(
          math.sin(_primaryAnimation.value * 4 * math.pi) * 2,
          math.cos(_primaryAnimation.value * 4 * math.pi) * 2,
        );
      case EmojiAnimationType.pulse:
        return Offset.zero;
      case EmojiAnimationType.urgent:
        return Offset(
          math.sin(_primaryAnimation.value * 8 * math.pi) * 1,
          0,
        );
      case EmojiAnimationType.apologetic:
        return Offset(0, math.sin(_primaryAnimation.value * math.pi) * 1);
      case EmojiAnimationType.celebration:
        return Offset(
          math.sin(_primaryAnimation.value * 6 * math.pi) * 3,
          math.cos(_primaryAnimation.value * 6 * math.pi) * 3,
        );
    }
  }

  double _getAnimatedRotation() {
    switch (widget.expression.animationType) {
      case EmojiAnimationType.gentle:
        return math.sin(_primaryAnimation.value * 2 * math.pi) * 0.05;
      case EmojiAnimationType.playful:
        return math.sin(_primaryAnimation.value * 4 * math.pi) * 0.1;
      case EmojiAnimationType.pulse:
        return 0;
      case EmojiAnimationType.urgent:
        return math.sin(_primaryAnimation.value * 8 * math.pi) * 0.02;
      case EmojiAnimationType.apologetic:
        return math.sin(_primaryAnimation.value * math.pi) * 0.03;
      case EmojiAnimationType.celebration:
        return _primaryAnimation.value * 2 * math.pi;
    }
  }
}

/// Emoji pack types for selection
enum EmojiPackType { classic, genZIsland }

/// Premium emoji selection modal with pack switcher
class EmojiSelectionModal extends StatefulWidget {
  final String urgencyLevel;
  final Function(PremiumEmojiExpression) onEmojiSelected;

  const EmojiSelectionModal({
    super.key,
    required this.urgencyLevel,
    required this.onEmojiSelected,
  });

  @override
  State<EmojiSelectionModal> createState() => _EmojiSelectionModalState();
}

class _EmojiSelectionModalState extends State<EmojiSelectionModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  PremiumEmojiExpression? _selectedEmoji;
  bool _isPreviewPlaying = false;
  EmojiPackType _currentPack = EmojiPackType.genZIsland;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: PremiumTheme.mediumDuration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _slideController.forward();

    // Set default emoji based on urgency and current pack
    _selectedEmoji = _getCurrentPack().getDefaultForUrgency(widget.urgencyLevel);
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  // Get current emoji pack
  dynamic _getCurrentPack() {
    switch (_currentPack) {
      case EmojiPackType.classic:
        return PremiumEmojiPack;
      case EmojiPackType.genZIsland:
        return GenZIslandEmojiPack;
    }
  }

  List<PremiumEmojiExpression> _getCurrentExpressions() {
    return _getCurrentPack().expressions;
  }

  void _switchPack(EmojiPackType newPack) {
    setState(() {
      _currentPack = newPack;
      _selectedEmoji = _getCurrentPack().getDefaultForUrgency(widget.urgencyLevel);
      _isPreviewPlaying = false;
    });
  }

  void _selectEmoji(PremiumEmojiExpression emoji) {
    setState(() {
      _selectedEmoji = emoji;
      _isPreviewPlaying = true;
    });

    // Stop preview after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isPreviewPlaying = false;
        });
      }
    });
  }

  void _confirmSelection() {
    if (_selectedEmoji != null) {
      widget.onEmojiSelected(_selectedEmoji!);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableEmojis = _getCurrentExpressions();

    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          margin: const EdgeInsets.only(top: 120),
          decoration: BoxDecoration(
            color: PremiumTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle indicator
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PremiumTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with pack switcher
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    Text(
                      'Choose Your Expression',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: PremiumTheme.primaryTextColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select an animated emoji to express your tone',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: PremiumTheme.secondaryTextColor,
                        
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // Pack switcher
                    _buildPackSwitcher(),
                  ],
                ),
              ),

              // Emoji grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: availableEmojis.length,
                    itemBuilder: (context, index) {
                      final emoji = availableEmojis[index];
                      final isSelected = _selectedEmoji?.id == emoji.id;

                      return Column(
                        children: [
                          Expanded(
                            child: AnimatedEmojiWidget(
                              expression: emoji,
                              isSelected: isSelected,
                              isPlaying: isSelected && _isPreviewPlaying,
                              onTap: () => _selectEmoji(emoji),
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            emoji.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? emoji.accentColor
                                  : PremiumTheme.secondaryTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Preview and confirm section
              if (_selectedEmoji != null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PremiumTheme.surfaceColor,
                    border: Border(
                      top: BorderSide(
                        color: PremiumTheme.dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Preview - Premium formatted alert display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _selectedEmoji!.accentColor.withValues(alpha: 0.08),
                              _selectedEmoji!.accentColor.withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedEmoji!.accentColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Alert preview label
                            Text(
                              'Alert Preview',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedEmoji!.accentColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Emoji and text in premium layout
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Fixed size container for emoji to prevent layout shifts
                                Container(
                                  width: 50,
                                  height: 50,
                                  alignment: Alignment.center,
                                  child: AnimatedEmojiWidget(
                                    expression: _selectedEmoji!,
                                    isSelected: true,
                                    isPlaying: _isPreviewPlaying,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Premium text styling
                                Flexible(
                                  child: Text(
                                    'Yuh Blockin!',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: PremiumTheme.primaryTextColor,
                                      letterSpacing: 0.5,
                                      
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Text(
                        _selectedEmoji!.description,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: PremiumTheme.secondaryTextColor,
                          
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _confirmSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PremiumTheme.accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Send Alert',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PremiumTheme.dividerColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPackOption(
            title: 'Island',
            subtitle: 'Gen Z trends',
            icon: '🏝️',
            packType: EmojiPackType.genZIsland,
            isSelected: _currentPack == EmojiPackType.genZIsland,
          ),
          Container(
            width: 1,
            height: 40,
            color: PremiumTheme.dividerColor.withValues(alpha: 0.3),
          ),
          _buildPackOption(
            title: 'Classic',
            subtitle: 'Timeless vibes',
            icon: '✨',
            packType: EmojiPackType.classic,
            isSelected: _currentPack == EmojiPackType.classic,
          ),
        ],
      ),
    );
  }

  Widget _buildPackOption({
    required String title,
    required String subtitle,
    required String icon,
    required EmojiPackType packType,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _switchPack(packType),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? PremiumTheme.accentColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? PremiumTheme.accentColor
                        : PremiumTheme.primaryTextColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: isSelected
                        ? PremiumTheme.accentColor.withValues(alpha: 0.8)
                        : PremiumTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}