import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../core/theme/premium_theme.dart';

/// Manim Animation Integration for Yuh Blockin'
///
/// Creates comedic sequences with mathematical precision
/// "Humor through timing, not childish imagery"
/// "Pixar-level composition meets minimal, tasteful visual humor"
/// "Mathematical precision with comedic flair"
class ManImAnimationController {
  late AnimationController _primaryController;
  late AnimationController _secondaryController;
  late AnimationController _comedyTimingController;

  Timer? _sequenceTimer;
  List<Timer> _activeTimers = [];

  bool _isDisposed = false;

  /// Play comedic reveal animation when someone receives an alert
  /// Features sophisticated timing and mathematical elegance
  void playComedyReveal({
    required BuildContext context,
    required String plateNumber,
    required VoidCallback onComplete,
  }) {
    if (_isDisposed) return;

    // Show overlay with Manim-style mathematical comedy
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => _ComedyRevealOverlay(
        plateNumber: plateNumber,
        onAnimationComplete: () {
          Navigator.of(context).pop();
          onComplete();
        },
      ),
    );
  }

  /// Play acknowledgment scene with witty mathematical humor
  void playAcknowledgmentScene({
    required BuildContext context,
    required VoidCallback onComplete,
  }) {
    if (_isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _AcknowledgmentOverlay(
        onAnimationComplete: () {
          Navigator.of(context).pop();
          onComplete();
        },
      ),
    );
  }

  /// Play beautiful resolution animation with mathematical precision
  void playResolutionAnimation({
    required BuildContext context,
    required VoidCallback onComplete,
  }) {
    if (_isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => _ResolutionOverlay(
        onAnimationComplete: () {
          Navigator.of(context).pop();
          onComplete();
        },
      ),
    );
  }

  void dispose() {
    _isDisposed = true;
    _sequenceTimer?.cancel();
    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
  }
}

/// Comedic reveal overlay with mathematical precision and tasteful humor
class _ComedyRevealOverlay extends StatefulWidget {
  final String plateNumber;
  final VoidCallback onAnimationComplete;

  const _ComedyRevealOverlay({
    required this.plateNumber,
    required this.onAnimationComplete,
  });

  @override
  State<_ComedyRevealOverlay> createState() => _ComedyRevealOverlayState();
}

class _ComedyRevealOverlayState extends State<_ComedyRevealOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  late AnimationController _mathController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _mathAnimation;

  String _currentText = '';
  int _textPhase = 0;

  final List<String> _comedySequence = [
    '📱 *Phone buzzes with mathematical precision*',
    '🚗 Someone needs to solve for X...',
    'Where X = "moving my car"',
    '📨 Alert delivered with comedic timing!',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startComedySequence();
  }

  void _initializeAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _mathController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _mathAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mathController, curve: Curves.easeOutBack),
    );
  }

  void _startComedySequence() {
    // Mathematical precision timing for maximum comedic effect
    Timer(const Duration(milliseconds: 200), () {
      HapticFeedback.lightImpact();
      _scaleController.forward();
    });

    Timer(const Duration(milliseconds: 800), () {
      _fadeController.forward();
      _progressTextSequence();
    });
  }

  void _progressTextSequence() {
    if (_textPhase < _comedySequence.length) {
      setState(() {
        _currentText = _comedySequence[_textPhase];
      });

      HapticFeedback.selectionClick();

      // Mathematical timing progression (Fibonacci-like)
      final delays = [1000, 1200, 1000, 1500];
      Timer(Duration(milliseconds: delays[_textPhase]), () {
        _textPhase++;
        if (_textPhase < _comedySequence.length) {
          _progressTextSequence();
        } else {
          _completeSequence();
        }
      });
    }
  }

  void _completeSequence() {
    _mathController.forward();
    HapticFeedback.mediumImpact();

    Timer(const Duration(milliseconds: 1000), () {
      widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    _mathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _scaleAnimation,
            _fadeAnimation,
            _mathAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value * (1.0 + (_mathAnimation.value * 0.1)),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: PremiumTheme.surfaceColor,
                    borderRadius: PremiumTheme.largeRadius,
                    boxShadow: [
                      BoxShadow(
                        color: PremiumTheme.accentColor.withOpacity(0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mathematical icon with Manim-style precision
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: PremiumTheme.accentColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.functions,
                          size: 40,
                          color: PremiumTheme.accentColor,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Plate number with mathematical styling
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: PremiumTheme.backgroundColor,
                          borderRadius: PremiumTheme.mediumRadius,
                          border: Border.all(
                            color: PremiumTheme.accentColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.plateNumber,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: PremiumTheme.primaryTextColor,
                            letterSpacing: 3.0,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Comedy text with mathematical precision
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _currentText,
                          key: ValueKey(_currentText),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: PremiumTheme.primaryTextColor,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Mathematical progress indicator
                      if (_mathAnimation.value > 0)
                        Transform.scale(
                          scale: _mathAnimation.value,
                          child: Container(
                            width: 200,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  PremiumTheme.accentColor.withOpacity(0.3),
                                  PremiumTheme.accentColor,
                                  PremiumTheme.accentColor.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Acknowledgment overlay with witty mathematical humor
class _AcknowledgmentOverlay extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const _AcknowledgmentOverlay({
    required this.onAnimationComplete,
  });

  @override
  State<_AcknowledgmentOverlay> createState() => _AcknowledgmentOverlayState();
}

class _AcknowledgmentOverlayState extends State<_AcknowledgmentOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();

    Timer(const Duration(seconds: 2), () {
      HapticFeedback.mediumImpact();
      widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_slideAnimation.value * 100, 0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: PremiumTheme.surfaceColor,
                  borderRadius: PremiumTheme.largeRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated checkmark
                    Transform.scale(
                      scale: _checkAnimation.value,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 30,
                          color: Colors.green,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      '✓ Acknowledged!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: PremiumTheme.primaryTextColor,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Mathematical precision meets\nhuman courtesy',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: PremiumTheme.secondaryTextColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Resolution overlay with beautiful mathematical celebration
class _ResolutionOverlay extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const _ResolutionOverlay({
    required this.onAnimationComplete,
  });

  @override
  State<_ResolutionOverlay> createState() => _ResolutionOverlayState();
}

class _ResolutionOverlayState extends State<_ResolutionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _celebrationController;
  late AnimationController _fadeController;

  late Animation<double> _celebrationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _celebrationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    Timer(const Duration(milliseconds: 300), () {
      HapticFeedback.heavyImpact();
      _celebrationController.forward();
    });

    Timer(const Duration(seconds: 2), () {
      widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: AnimatedBuilder(
            animation: _celebrationAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.8 + (_celebrationAnimation.value * 0.2),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PremiumTheme.surfaceColor,
                        PremiumTheme.surfaceColor.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: PremiumTheme.extraLargeRadius,
                    boxShadow: [
                      BoxShadow(
                        color: PremiumTheme.accentColor.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mathematical celebration icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withOpacity(0.2),
                              Colors.blue.withOpacity(0.2),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          size: 50,
                          color: PremiumTheme.accentColor,
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Problem Solved!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: PremiumTheme.primaryTextColor,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Mathematical precision + human respect\n= Beautiful solution',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: PremiumTheme.secondaryTextColor,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // Success indicator with Manim-style precision
                      Container(
                        width: 150,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green,
                              Colors.blue,
                              Colors.green,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}