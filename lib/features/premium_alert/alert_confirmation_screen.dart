import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../core/theme/premium_theme.dart';
import '../../core/services/simple_alert_service.dart';
import '../../core/services/unacknowledged_alert_service.dart';
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
  late AnimationController _manimController;

  late Animation<double> _fadeAnimation;

  final ManImAnimationController _manimAnimations = ManImAnimationController();
  final SimpleAlertService _alertService = SimpleAlertService();
  final UnacknowledgedAlertService _unacknowledgedAlertService = UnacknowledgedAlertService();

  String _currentPhase = 'sending';  // sending -> delivered -> acknowledged -> resolved
  String _statusMessage = 'Sending respectful alert...';
  double _progressValue = 0.0;
  Timer? _progressTimer;
  Timer? _phaseTimer;

  // Real alert system integration
  String? _currentUserId;
  StreamSubscription<List<Alert>>? _alertResponseSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAndSendAlert();
  }

  void _initializeAnimations() {
    // Main fade animation
    _fadeController = AnimationController(
      duration: PremiumTheme.mediumDuration,
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

    // Start animations
    _fadeController.forward();
  }

  /// Initialize alert service and send real alert
  Future<void> _initializeAndSendAlert() async {
    try {
      // Initialize alert service
      await _alertService.initialize();

      // Get user ID
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      if (userId == null) {
        userId = await _alertService.getOrCreateUser();
        await prefs.setString('user_id', userId);
      }

      setState(() {
        _currentUserId = userId;
      });

      // Start progress animation
      _startProgressAnimation();

      // Send simple emoji alert
      final result = await _alertService.sendAlert(
        targetPlateNumber: widget.plateNumber,
        senderUserId: userId,
        message: widget.selectedEmoji.unicode, // Just send the emoji character
      );

      if (result.success && result.recipients > 0) {
        _transitionToDelivered();
        _startListeningForResponses();
      } else {
        _handleAlertFailure(result.error ?? 'No recipients found');
      }

    } catch (e) {
      _handleAlertFailure(e.toString());
    }
  }

  /// Start progress bar animation
  void _startProgressAnimation() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progressValue += 0.02;
        if (_progressValue >= 1.0) {
          _progressValue = 1.0;
          timer.cancel();
        }
      });
    });
  }

  /// Listen for real-time responses with enhanced synchronization
  void _startListeningForResponses() {
    if (_currentUserId == null) return;

    debugPrint('🔄 Starting to listen for real-time responses...');

    _alertResponseSubscription = _alertService
        .getSentAlertsStream(_currentUserId!)
        .listen(
          (alerts) {
            debugPrint('📡 Received alerts update: ${alerts.length} alerts');

            if (alerts.isNotEmpty) {
              final latestAlert = alerts.first;

              // Debug logging
              debugPrint('🎯 Latest alert: ID=${latestAlert.id}, Response=${latestAlert.response}, Phase=$_currentPhase');

              // Only handle response if we haven't already processed it and aren't resolved
              if (latestAlert.hasResponse && _currentPhase != 'resolved' && _currentPhase != 'acknowledged') {
                debugPrint('✅ Processing real response: ${latestAlert.response}');
                _handleRealResponse(latestAlert);
              } else if (latestAlert.hasResponse) {
                debugPrint('ℹ️  Response already processed or alert resolved');
              }
            }
          },
          onError: (error) {
            debugPrint('❌ Alert stream error: $error');
            // Attempt to reconnect after delay
            Timer(const Duration(seconds: 5), () {
              if (mounted) {
                debugPrint('🔄 Attempting to reconnect alert stream...');
                _startListeningForResponses();
              }
            });
          }
        );

    // Add timeout mechanism for unanswered alerts
    _startAlertTimeout();
  }

  /// Add timeout mechanism for alerts that never receive a response
  void _startAlertTimeout() {
    // Set a reasonable timeout (10 minutes) for alerts
    Timer(const Duration(minutes: 10), () {
      if (mounted && _currentPhase == 'delivered') {
        debugPrint('⏰ Alert timeout reached - no response received');
        setState(() {
          _currentPhase = 'timeout';
          _statusMessage = 'No response received. The recipient may not have seen the alert.';
        });

        // Auto-return to home after timeout notification
        Timer(const Duration(seconds: 5), () {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    });
  }

  /// Handle actual response from receiver
  void _handleRealResponse(Alert alert) {
    debugPrint('✅ Real response received: ${alert.response} - ${alert.responseText}');

    setState(() {
      _currentPhase = 'acknowledged';
      _statusMessage = 'Response: ${alert.responseText}';
    });

    HapticFeedback.mediumImpact();

    // Mark alert as acknowledged in unacknowledged alerts service
    _unacknowledgedAlertService.markAlertAcknowledged(alert.id).then((_) {
      debugPrint('✅ Marked alert ${alert.id} as acknowledged in tracking service');
    }).catchError((error) {
      debugPrint('⚠️ Failed to mark alert as acknowledged: $error');
    });

    // Handle different response types appropriately
    _processResponseType(alert.response ?? 'unknown', alert);
  }

  /// Process different response types with appropriate actions
  void _processResponseType(String responseType, Alert alert) {
    switch (responseType) {
      case 'moving_now':
        _handleMovingNowResponse(alert);
        break;
      case '5_minutes':
        _handleDelayedResponse(alert, '5 minutes');
        break;
      case 'cant_move':
        _handleCantMoveResponse(alert);
        break;
      case 'wrong_car':
        _handleWrongCarResponse(alert);
        break;
      default:
        _handleGenericResponse(alert);
    }
  }

  /// Handle "moving now" response - transition to resolved
  void _handleMovingNowResponse(Alert alert) {
    // For "moving now", transition to resolved
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _transitionToResolved();
      }
    });
  }

  /// Handle delayed response - stay acknowledged, show countdown
  void _handleDelayedResponse(Alert alert, String timeframe) {
    setState(() {
      _statusMessage = 'Owner will move in $timeframe. Thank you for your patience!';
    });

    // Stay in acknowledged state - don't auto-resolve for delayed responses
    debugPrint('🕐 Waiting for actual movement...');
  }

  /// Handle "can't move" response
  void _handleCantMoveResponse(Alert alert) {
    setState(() {
      _statusMessage = 'Owner cannot move right now. ${alert.responseMessage ?? "Consider alternative parking."}';
    });

    // Don't auto-resolve - user may need to take other action
    debugPrint('🚫 Cannot move - alert remains active');
  }

  /// Handle "wrong car" response - transition to resolved
  void _handleWrongCarResponse(Alert alert) {
    setState(() {
      _statusMessage = 'Wrong car identified. Sorry for the confusion!';
    });

    // Auto-resolve for wrong car
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _transitionToResolved();
      }
    });
  }

  /// Handle generic/unknown response
  void _handleGenericResponse(Alert alert) {
    // Don't auto-resolve for unknown responses
    debugPrint('❓ Unknown response type - staying in acknowledged state');
  }

  /// Handle alert sending failure
  void _handleAlertFailure(String error) {
    setState(() {
      _currentPhase = 'failed';
      _statusMessage = 'Alert failed: $error';
    });

    HapticFeedback.heavyImpact();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _transitionToDelivered() {
    setState(() {
      _currentPhase = 'delivered';
      _statusMessage = 'Alert delivered! Waiting for response...';
    });

    HapticFeedback.lightImpact();

    // Simple confirmation - alert delivered
    debugPrint('🎯 Alert delivered. Waiting for genuine user response...');
  }

  // Removed fake auto-confirmation timers - now waits for real user responses only

  void _transitionToResolved() {
    setState(() {
      _currentPhase = 'resolved';
      _statusMessage = 'Resolved! Thank you for being respectful.';
    });

    HapticFeedback.heavyImpact();

    // Simple completion
    _showCompletionAndReturn();
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
    _manimController.dispose();
    _progressTimer?.cancel();
    _phaseTimer?.cancel();
    _alertResponseSubscription?.cancel();
    _manimAnimations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return CupertinoPageScaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Alert Status'),
        backgroundColor: Colors.transparent,
        border: null,
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 80.0 : 32.0,
              vertical: isTablet ? 60.0 : 40.0,
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

                SizedBox(height: isTablet ? 60 : 40),
              ],
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
        // Simple progress ring without zoom effects - centered
        Center(
          child: SizedBox(
            width: isTablet ? 170 : 130,
            height: isTablet ? 170 : 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress ring
                SizedBox(
                  width: isTablet ? 170 : 130,
                  height: isTablet ? 170 : 130,
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
      case 'timeout':
        iconData = Icons.schedule;
        iconColor = Colors.orange;
        break;
      case 'failed':
        iconData = Icons.error_outline;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.send;
    }

    // Show emoji for main phases, icons for status phases
    if (_currentPhase == 'delivered' || _currentPhase == 'acknowledged' || _currentPhase == 'sending') {
      return Text(
        widget.selectedEmoji.unicode,
        style: TextStyle(
          fontSize: isTablet ? 50 : 40,
        ),
      );
    } else {
      return Icon(
        iconData,
        size: isTablet ? 50 : 40,
        color: iconColor,
      );
    }
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

          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 16),

        // Phase indicators
        _buildPhaseIndicators(),

        // Simple alert content: Just the animated emoji
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor.withAlpha(178),
            borderRadius: PremiumTheme.mediumRadius,
            border: Border.all(
              color: widget.selectedEmoji.accentColor.withAlpha(51),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedEmojiWidget(
                expression: widget.selectedEmoji,
                isSelected: true,
                isPlaying: true,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                'Alert sent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: PremiumTheme.primaryTextColor,
                ),
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

    return SizedBox(
      width: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: phases.asMap().entries.map((entry) {
              final index = entry.key;
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
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? PremiumTheme.accentColor
                              : PremiumTheme.tertiaryTextColor,

                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (index < phases.length - 1) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 16,
                      height: 1,
                      color: isActive && phases.indexOf(_currentPhase) > index
                          ? PremiumTheme.accentColor
                          : PremiumTheme.dividerColor,
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}