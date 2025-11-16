import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../core/theme/premium_theme.dart';
import '../../config/premium_config.dart';
import '../manim_animations/manim_integration.dart';
import 'premium_emoji_system.dart';

/// Premium alert confirmation screen with Manim comedic animations
/// Features "humor through timing, not childish imagery"
/// "Pixar-level composition meets minimal, tasteful visual humor"
class AlertConfirmationScreen extends StatefulWidget {
  final String plateNumber;
  final String urgencyLevel;
  final PremiumEmojiExpression selectedEmoji;

  const AlertConfirmationScreen({
    super.key,
    required this.plateNumber,
    required this.urgencyLevel,
    required this.selectedEmoji,
  });

  @override
  State<AlertConfirmationScreen> createState() => _AlertConfirmationScreenState();
}

class _AlertConfirmationScreenState extends State<AlertConfirmationScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _manimController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _breathingAnimation;

  final ManImAnimationController _manimAnimations = ManImAnimationController();

  String _currentPhase = 'sending';  // sending -> delivered -> acknowledged -> resolved
  String _statusMessage = 'Sending respectful alert...';
  double _progressValue = 0.0;
  Timer? _progressTimer;
  Timer? _phaseTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAlertSequence();
  }

  void _initializeAnimations() {
    // Main fade animation
    _fadeController = AnimationController(
      duration: PremiumTheme.mediumDuration,
      vsync: this,
    );

    // Scale animation for interactions
    _scaleController = AnimationController(
      duration: PremiumTheme.fastDuration,
      vsync: this,
    );

    // Manim animation controller
    _manimController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));

    _breathingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _manimController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _manimController.repeat(reverse: true);
  }

  void _startAlertSequence() {
    // Progress simulation
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progressValue += 0.02;
        if (_progressValue >= 1.0) {
          _progressValue = 1.0;
          timer.cancel();
        }
      });
    });

    // Phase progression with Manim integration
    _phaseTimer = Timer(const Duration(seconds: 2), () {
      _transitionToDelivered();
    });
  }

  void _transitionToDelivered() {
    setState(() {
      _currentPhase = 'delivered';
      _statusMessage = 'Alert delivered! Waiting for response...';
    });

    HapticFeedback.lightImpact();

    // Start Manim comedic reveal animation
    _manimAnimations.playComedyReveal(
      context: context,
      plateNumber: widget.plateNumber,
      onComplete: () {
        _scheduleAcknowledgment();
      },
    );
  }

  void _scheduleAcknowledgment() {
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _transitionToAcknowledged();
      }
    });
  }

  void _transitionToAcknowledged() {
    setState(() {
      _currentPhase = 'acknowledged';
      _statusMessage = 'Owner acknowledged! Moving car now...';
    });

    HapticFeedback.mediumImpact();

    // Manim acknowledgment animation
    _manimAnimations.playAcknowledgmentScene(
      context: context,
      onComplete: () {
        _scheduleResolution();
      },
    );
  }

  void _scheduleResolution() {
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _transitionToResolved();
      }
    });
  }

  void _transitionToResolved() {
    setState(() {
      _currentPhase = 'resolved';
      _statusMessage = 'Resolved! Thank you for being respectful.';
    });

    HapticFeedback.heavyImpact();

    // Beautiful resolution animation
    _manimAnimations.playResolutionAnimation(
      context: context,
      onComplete: () {
        _showCompletionAndReturn();
      },
    );
  }

  void _showCompletionAndReturn() {
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _manimController.dispose();
    _progressTimer?.cancel();
    _phaseTimer?.cancel();
    _manimAnimations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 80.0 : 32.0,
                vertical: 60.0,
              ),
              child: Column(
                children: [
                  // Header with close button
                  _buildHeader(),

                  // Flexible space
                  const Expanded(flex: 1, child: SizedBox()),

                  // Main content area
                  _buildMainContent(isTablet),

                  // Flexible space
                  const Expanded(flex: 2, child: SizedBox()),

                  // Status information - wrapped to prevent overflow
                  Flexible(
                    child: SingleChildScrollView(
                      child: _buildStatusInfo(),
                    ),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 40), // Balance the close button

        Text(
          'Alert Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: PremiumTheme.primaryTextColor,
            letterSpacing: 0.1,
          ),
        ),

        GestureDetector(
          onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: PremiumTheme.subtleShadow,
            ),
            child: Icon(
              Icons.close,
              color: PremiumTheme.primaryTextColor,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(bool isTablet) {
    return Column(
      children: [
        // Animated progress ring with Manim breathing effect
        AnimatedBuilder(
          animation: _breathingAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _breathingAnimation.value,
              child: Container(
                width: isTablet ? 200 : 160,
                height: isTablet ? 200 : 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress ring
                    SizedBox(
                      width: isTablet ? 200 : 160,
                      height: isTablet ? 200 : 160,
                      child: CircularProgressIndicator(
                        value: _progressValue,
                        strokeWidth: 8,
                        backgroundColor: PremiumTheme.dividerColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          PremiumTheme.accentColor,
                        ),
                      ),
                    ),

                    // Center icon with phase-specific animation
                    _buildCenterIcon(isTablet),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 40),

        // Plate number display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor,
            borderRadius: PremiumTheme.mediumRadius,
            boxShadow: PremiumTheme.subtleShadow,
          ),
          child: Text(
            widget.plateNumber,
            style: TextStyle(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 2.0,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Urgency level
        Text(
          '${widget.urgencyLevel} Priority',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: PremiumTheme.secondaryTextColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCenterIcon(bool isTablet) {
    IconData iconData;
    Color iconColor = PremiumTheme.accentColor;

    switch (_currentPhase) {
      case 'sending':
        iconData = Icons.send;
        break;
      case 'delivered':
        iconData = Icons.notifications_active;
        break;
      case 'acknowledged':
        iconData = Icons.check_circle;
        break;
      case 'resolved':
        iconData = Icons.celebration;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.send;
    }

    return Icon(
      iconData,
      size: isTablet ? 60 : 48,
      color: iconColor,
    );
  }

  Widget _buildStatusInfo() {
    return Column(
      children: [
        // Status message
        Text(
          _statusMessage,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: PremiumTheme.primaryTextColor,
            letterSpacing: 0.1,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 16),

        // Phase indicators
        _buildPhaseIndicators(),

        // Selected emoji + signature message display
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.selectedEmoji.accentColor.withOpacity(0.1),
                widget.selectedEmoji.accentColor.withOpacity(0.05),
              ],
            ),
            borderRadius: PremiumTheme.largeRadius,
            border: Border.all(
              color: widget.selectedEmoji.accentColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.selectedEmoji.accentColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.send,
                    size: 18,
                    color: widget.selectedEmoji.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sending Alert',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.selectedEmoji.accentColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Alert content: Emoji + "Yuh Blockin'!"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedEmojiWidget(
                    expression: widget.selectedEmoji,
                    isSelected: true,
                    isPlaying: true,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Yuh Blockin!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.primaryTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Expression description
              Text(
                widget.selectedEmoji.description,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.secondaryTextColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseIndicators() {
    final phases = ['sending', 'delivered', 'acknowledged', 'resolved'];
    final phaseLabels = ['Sending', 'Delivered', 'Acknowledged', 'Resolved'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: phases.asMap().entries.map((entry) {
        final index = entry.key;
        final phase = entry.value;
        final label = phaseLabels[index];
        final isActive = phases.indexOf(_currentPhase) >= index;

        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isActive
                        ? PremiumTheme.accentColor
                        : PremiumTheme.dividerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isActive
                        ? PremiumTheme.accentColor
                        : PremiumTheme.tertiaryTextColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            if (index < phases.length - 1) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 1,
                color: isActive && phases.indexOf(_currentPhase) > index
                    ? PremiumTheme.accentColor
                    : PremiumTheme.dividerColor,
              ),
              const SizedBox(width: 8),
            ],
          ],
        );
      }).toList(),
      ),
    );
  }
}