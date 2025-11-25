import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../core/theme/premium_theme.dart';
import '../../config/premium_config.dart';
import '../../core/services/plate_storage_service.dart';
import '../../core/services/simple_alert_service.dart';
import '../../core/services/user_stats_service.dart';
import '../../core/services/unacknowledged_alert_service.dart';
import 'alert_confirmation_screen.dart';
import 'premium_emoji_system.dart';

/// Advanced license plate formatter with automatic dash insertion
/// Supports multiple international formats: ABC-123, 123-ABC, AB-123-CD, etc.
class LicensePlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.toUpperCase();

    // Remove all existing dashes and spaces
    text = text.replaceAll(RegExp(r'[\s-]'), '');

    // Only allow alphanumeric characters
    text = text.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Limit to 15 characters (supports longest international plates including Germany)
    if (text.length > 15) {
      text = text.substring(0, 15);
    }

    String formatted = _applyDashFormatting(text);

    // Calculate cursor position
    int cursorPosition = _calculateCursorPosition(
      oldValue.text,
      newValue.text,
      formatted,
      newValue.selection.baseOffset,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }

  String _applyDashFormatting(String text) {
    if (text.isEmpty) return text;

    // Auto-detect format based on pattern and apply appropriate dashing

    // Format 1: ABC123 -> ABC-123 (3 letters + 3 numbers)
    if (text.length >= 6 && RegExp(r'^[A-Z]{3}[0-9]{3,4}$').hasMatch(text)) {
      return '${text.substring(0, 3)}-${text.substring(3)}';
    }

    // Format 2: 123ABC -> 123-ABC (3 numbers + 3 letters)
    if (text.length >= 6 && RegExp(r'^[0-9]{3}[A-Z]{3,4}$').hasMatch(text)) {
      return '${text.substring(0, 3)}-${text.substring(3)}';
    }

    // Format 3: AB123CD -> AB-123-CD (2 letters + 3 numbers + 2 letters)
    if (text.length >= 7 && RegExp(r'^[A-Z]{2}[0-9]{3}[A-Z]{2}$').hasMatch(text)) {
      return '${text.substring(0, 2)}-${text.substring(2, 5)}-${text.substring(5)}';
    }

    // Format 4: German style long plates ABC1234DE -> ABC-1234-DE
    if (text.length >= 9 && RegExp(r'^[A-Z]{3}[0-9]{4}[A-Z]{2}$').hasMatch(text)) {
      return '${text.substring(0, 3)}-${text.substring(3, 7)}-${text.substring(7)}';
    }

    // Format 5: Extra long plates ABCD1234EF -> ABCD-1234-EF
    if (text.length >= 10 && RegExp(r'^[A-Z]{4}[0-9]{4}[A-Z]{2}$').hasMatch(text)) {
      return '${text.substring(0, 4)}-${text.substring(4, 8)}-${text.substring(8)}';
    }

    // Format 6: Smart auto-formatting for mixed content
    if (text.length >= 4) {
      List<String> segments = [];
      String currentSegment = '';
      String lastType = '';

      for (int i = 0; i < text.length; i++) {
        String char = text[i];
        String currentType = RegExp(r'[A-Z]').hasMatch(char) ? 'letter' : 'number';

        if (lastType.isEmpty || currentType == lastType) {
          currentSegment += char;
        } else {
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
            currentSegment = char;
          }
        }
        lastType = currentType;
      }

      if (currentSegment.isNotEmpty) {
        segments.add(currentSegment);
      }

      // Join segments with dashes, but only if we have multiple segments
      if (segments.length > 1 && text.length >= 4) {
        return segments.join('-');
      }
    }

    return text;
  }

  int _calculateCursorPosition(
    String oldText,
    String newText,
    String formattedText,
    int oldCursorPosition,
  ) {
    // If user is typing at the end, place cursor at the end of formatted text
    if (oldCursorPosition >= oldText.length) {
      return formattedText.length;
    }

    // Count non-dash characters before cursor position
    int nonDashCount = 0;
    for (int i = 0; i < math.min(oldCursorPosition, newText.length); i++) {
      if (newText[i] != '-' && newText[i] != ' ') {
        nonDashCount++;
      }
    }

    // Find position in formatted text with same non-dash character count
    int formattedPosition = 0;
    int charCount = 0;

    for (int i = 0; i < formattedText.length; i++) {
      if (formattedText[i] != '-') {
        charCount++;
      }
      formattedPosition = i + 1;

      if (charCount >= nonDashCount) {
        break;
      }
    }

    return math.min(formattedPosition, formattedText.length);
  }
}

/// Premium alert workflow screen - launched from hero button
/// Handles license plate input and alert creation with Manim integration
class AlertWorkflowScreen extends StatefulWidget {
  const AlertWorkflowScreen({super.key});

  @override
  State<AlertWorkflowScreen> createState() => _AlertWorkflowScreenState();
}

class _AlertWorkflowScreenState extends State<AlertWorkflowScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _plateController = TextEditingController();
  final FocusNode _plateFocusNode = FocusNode();
  final PlateStorageService _plateStorageService = PlateStorageService();
  final SimpleAlertService _alertService = SimpleAlertService();
  final UserStatsService _statsService = UserStatsService();
  final UnacknowledgedAlertService _unacknowledgedAlertService = UnacknowledgedAlertService();

  String _urgencyLevel = 'Normal';
  PremiumEmojiExpression? _selectedEmoji;
  bool _isValidPlate = false;
  bool _isLoading = false;
  String? _primaryPlate;
  bool _hasLoadedDependencies = false;
  Timer? _primaryPlateRefreshTimer;
  List<DateTime> _paymentTierAlertTimes = []; // Track alert timing for payment tier limits

  // Emoji pack selection
  String _selectedEmojiPack = 'Classic'; // 'Classic' or 'GenZ'

  // Enhanced emoji selection state

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Spam protection system
  static final Map<String, DateTime> _lastAlertTimes = {};
  static final Set<String> _recentAlerts = {};
  static DateTime? _lastAnyAlert;
  static const int _minTimeBetweenAlerts = 30; // seconds
  static const int _maxAlertsPerHour = 10;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _initializeServices();

    // Initialize with default emoji based on urgency and selected pack
    _selectedEmoji = _getDefaultEmoji();

    // Smooth slide-in animation
    _slideController = AnimationController(
      duration: PremiumTheme.mediumDuration,
      vsync: this,
    );

    // Gentle scale animation for interactions
    _scaleController = AnimationController(
      duration: PremiumTheme.fastDuration,
      vsync: this,
    );


    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: PremiumTheme.standardCurve,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: PremiumTheme.standardCurve,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    ));


    // Add lifecycle observer for app state changes
    WidgetsBinding.instance.addObserver(this);

    // Start entrance animation
    _slideController.forward();

    // Load primary license plate immediately and after short delay to ensure services are ready
    _loadPrimaryPlate();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadPrimaryPlate(); // Reload to ensure we have the latest primary plate
      }
    });

    // Start periodic refresh of primary plate (every 3 seconds while screen is visible)
    _startPrimaryPlateRefresh();

    // Auto-focus plate input after animation
    Future.delayed(PremiumTheme.mediumDuration, () {
      if (mounted) {
        _plateFocusNode.requestFocus();
      }
    });
  }

  Future<void> _initializeServices() async {
    try {
      await _alertService.initialize();
      print('✅ Simple alert service initialized');
    } catch (e) {
      print('⚠️ Failed to initialize secure service: $e');
    }
  }

  // Load user's primary license plate
  Future<void> _loadPrimaryPlate() async {
    try {
      final primaryPlate = await _plateStorageService.getPrimaryPlate();

      if (mounted) {
        setState(() {
          _primaryPlate = primaryPlate;
        });
      }
    } catch (e) {
      // Handle error silently - primary plate is optional for this feature
    }
  }

  /// Start periodic refresh of primary plate while screen is visible
  void _startPrimaryPlateRefresh() {
    _primaryPlateRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _loadPrimaryPlate();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only refresh on first load or when returning to screen
    if (!_hasLoadedDependencies) {
      _hasLoadedDependencies = true;
      print('🔄 AlertWorkflow: Initial dependencies loaded');
    } else {
      // User returned to screen, refresh primary plate
      print('🔄 AlertWorkflow: Dependencies changed, likely returned to screen - refreshing primary plate...');
      _loadPrimaryPlate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Refresh primary plate when app becomes active
    if (state == AppLifecycleState.resumed) {
      print('🔄 AlertWorkflow: App resumed, refreshing primary plate...');
      _loadPrimaryPlate();
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _primaryPlateRefreshTimer?.cancel();
    _slideController.dispose();
    _scaleController.dispose();
    _plateController.dispose();
    _plateFocusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return PopScope(
      canPop: !_isLoading,
      onPopInvoked: (didPop) {
        if (!didPop && _isLoading) {
          // Show a message that operation is in progress
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait, sending alert...'),
              backgroundColor: PremiumTheme.accentColor,
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      },
      child: Scaffold(
      backgroundColor: PremiumTheme.backgroundColor.withOpacity(0.95),
      body: Stack(
        children: [
          // Main content
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Check if we need to use responsive layout for very small screens
                final isVerySmallScreen = constraints.maxHeight < 600;
                final isExtremelySmallScreen = constraints.maxHeight < 550;

                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: isVerySmallScreen ? 20.0 : 24.0,
                    vertical: isVerySmallScreen ? 12.0 : 20.0,
                  ),
                  child: Column(
                    children: [
                  // Header with back action
                  _buildHeader(context),

                  SizedBox(height: isVerySmallScreen ? 12.0 : 20.0),

                  // Main scrollable content for mobile
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // User vehicle context badge (more compact)
                          if (_primaryPlate != null) _buildVehicleContextBadge(),

                          // Title and description (more compact)
                          _buildTitle(),

                          SizedBox(height: isVerySmallScreen ? 8.0 : 12.0),

                          // License plate input
                          _buildPlateInput(),

                          SizedBox(height: isVerySmallScreen ? 8.0 : 12.0),

                          // Urgency selection
                          _buildUrgencySelection(),

                          SizedBox(height: isVerySmallScreen ? 8.0 : 12.0),

                          // Emoji expression selection
                          _buildEmojiSelector(),

                          SizedBox(height: isVerySmallScreen ? 10.0 : 14.0),

                          // Send alert button
                          _buildSendButton(),

                          SizedBox(height: isVerySmallScreen ? 8.0 : 12.0),
                        ],
                      ),
                    ),
                  ),
                    ],
                  ),
                );
              },
            ),
          ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Back button
        GestureDetector(
          onTap: _handleBack,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: PremiumTheme.subtleShadow,
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
        ),

        const Spacer(),

        // Progress indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: PremiumTheme.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Step 1 of 2',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: PremiumTheme.accentColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleContextBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumTheme.accentColor.withOpacity(0.12),
              PremiumTheme.accentColor.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PremiumTheme.accentColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: PremiumTheme.accentColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: PremiumTheme.accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car_rounded,
                size: 16,
                color: PremiumTheme.accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From your vehicle:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: PremiumTheme.accentColor.withOpacity(0.8),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _primaryPlate!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PremiumTheme.accentColor,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PremiumTheme.surfaceColor,
            PremiumTheme.surfaceColor.withOpacity(0.9),
          ],
        ),
        borderRadius: PremiumTheme.mediumRadius,
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.accentColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Premium title with rich text styling
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w300,
                color: PremiumTheme.primaryTextColor,
                letterSpacing: 0.5,
                height: 1.1,
              ),
              children: [
                TextSpan(text: 'Send '),
                TextSpan(
                  text: 'Respectful',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.accentColor,
                  ),
                ),
                TextSpan(text: ' Alert'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Compact description inline
          Text(
            'Let someone know their car needs to be moved',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: PremiumTheme.secondaryTextColor,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlateInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'License Plate Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PremiumTheme.primaryTextColor,
            letterSpacing: 0.1,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor,
            borderRadius: PremiumTheme.mediumRadius,
            boxShadow: PremiumTheme.subtleShadow,
            border: Border.all(
              color: _isValidPlate
                  ? PremiumTheme.accentColor.withOpacity(0.3)
                  : PremiumTheme.dividerColor,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _plateController,
            focusNode: _plateFocusNode,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 2.0,
            ),
            decoration: InputDecoration(
              hintText: 'ABC-123',
              hintStyle: TextStyle(
                color: PremiumTheme.tertiaryTextColor,
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: InputBorder.none,
            ),
            onChanged: _validatePlate,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LicensePlateFormatter(), // Custom auto-dash formatter
              LengthLimitingTextInputFormatter(18), // Support longest international plates with dashes
            ],
          ),
        ),

        // Always-present validation indicator (no layout shift)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AnimatedOpacity(
            opacity: _isValidPlate ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: PremiumTheme.accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Valid plate format',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PremiumTheme.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgencySelection() {
    final urgencyLevels = ['Low', 'Normal', 'High'];

    // Color mapping for urgency levels
    final urgencyColors = {
      'Low': Color(0xFF34D399),    // Light green
      'Normal': PremiumTheme.accentColor,  // Standard blue
      'High': Color(0xFFEF4444),   // Red
    };

    final urgencyIntensities = {
      'Low': 0.6,      // Lighter
      'Normal': 0.8,   // Normal
      'High': 1.0,     // Darker/full intensity
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Urgency Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: PremiumTheme.primaryTextColor,
            letterSpacing: 0.1,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor,
            borderRadius: PremiumTheme.mediumRadius,
            boxShadow: PremiumTheme.subtleShadow,
          ),
          child: Row(
            children: urgencyLevels.map((level) {
              final isSelected = _urgencyLevel == level;
              final urgencyColor = urgencyColors[level] ?? PremiumTheme.accentColor;
              final intensity = urgencyIntensities[level] ?? 0.8;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _urgencyLevel = level;
                    _selectedEmoji = _getDefaultEmojiForLevel(level);
                  }),
                  child: AnimatedContainer(
                    duration: PremiumTheme.fastDuration,
                    curve: PremiumTheme.standardCurve,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              urgencyColor.withOpacity(intensity),
                              urgencyColor.withOpacity(intensity * 0.8),
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              urgencyColor.withOpacity(0.1),
                              urgencyColor.withOpacity(0.05),
                            ],
                          ),
                      borderRadius: PremiumTheme.mediumRadius,
                      border: isSelected
                        ? Border.all(
                            color: urgencyColor.withOpacity(0.3),
                            width: 1,
                          )
                        : Border.all(
                            color: urgencyColor.withOpacity(0.1),
                            width: 1,
                          ),
                      boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: urgencyColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                    ),
                    child: Text(
                      level,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : urgencyColor.withOpacity(0.8),
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmallScreen = MediaQuery.of(context).size.height < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Expression',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PremiumTheme.primaryTextColor,
                letterSpacing: 0.1,
              ),
            ),

            SizedBox(height: isVerySmallScreen ? 6.0 : 10.0),

            // Compact alert preview
            Container(
          width: double.infinity,
          padding: EdgeInsets.all(isVerySmallScreen ? 12.0 : 14.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _selectedEmoji?.accentColor.withOpacity(0.08) ??
                  PremiumTheme.accentColor.withOpacity(0.08),
                _selectedEmoji?.accentColor.withOpacity(0.05) ??
                  PremiumTheme.accentColor.withOpacity(0.05),
              ],
            ),
            borderRadius: PremiumTheme.mediumRadius,
            border: Border.all(
              color: _selectedEmoji?.accentColor.withOpacity(0.2) ??
                PremiumTheme.accentColor.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _selectedEmoji?.accentColor.withOpacity(0.1) ??
                  PremiumTheme.accentColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Preview label
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _selectedEmoji?.accentColor ?? PremiumTheme.accentColor,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 10),

              // Alert content - centered layout
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_selectedEmoji != null) ...[
                    AnimatedEmojiWidget(
                      expression: _selectedEmoji!,
                      isSelected: true,
                      isPlaying: true,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    'Yuh Blockin!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.primaryTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Expression description
              if (_selectedEmoji != null)
                Text(
                  _selectedEmoji!.description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: PremiumTheme.secondaryTextColor,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        SizedBox(height: isVerySmallScreen ? 10.0 : 14.0),

        // Enhanced emoji grid selector
        _buildEnhancedEmojiGrid(),
          ],
        );
      },
    );
  }

  /// Enhanced emoji grid with tabs - choose between Gen Z and Classic emoji packs
  Widget _buildEnhancedEmojiGrid() {
    final availableEmojis = _selectedEmojiPack == 'GenZ'
        ? GenZIslandEmojiPack.expressions
        : PremiumEmojiPack.expressions;

    final isVerySmallScreen = MediaQuery.of(context).size.height < 600;

    return Container(
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: PremiumTheme.largeRadius,
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.accentColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Emoji Pack Tabs
          _buildEmojiTabs(),

          // Emoji Grid
          Padding(
            padding: EdgeInsets.all(isVerySmallScreen ? 12.0 : 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate optimal height for the grid
                final itemCount = availableEmojis.length;
                final crossAxisCount = 3;
                final rowCount = (itemCount / crossAxisCount).ceil();
                final itemHeight = constraints.maxWidth / crossAxisCount * (1 / 1.1);
                final totalHeight = rowCount * itemHeight + (rowCount - 1) * 12;

                return SizedBox(
                  height: totalHeight,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: isVerySmallScreen ? 8.0 : 12.0,
                      mainAxisSpacing: isVerySmallScreen ? 8.0 : 12.0,
                    ),
                    itemCount: availableEmojis.length,
                    itemBuilder: (context, index) {
                      final emoji = availableEmojis[index];
                      final isSelected = _selectedEmoji?.id == emoji.id;

                      return GestureDetector(
                        onTap: () => _selectEmojiWithAnimation(emoji),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? emoji.accentColor.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? Border.all(
                                    color: emoji.accentColor.withOpacity(0.5),
                                    width: 2,
                                  )
                                : Border.all(
                                    color: PremiumTheme.dividerColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: emoji.accentColor.withOpacity(0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Optimized animated emoji
                              AnimatedEmojiWidget(
                                expression: emoji,
                                isSelected: isSelected,
                                isPlaying: isSelected,
                                size: 38, // Reduced size to fit better
                              ),
                              const SizedBox(height: 4), // Reduced spacing
                              // Emoji title - flexible to fit available space
                              Flexible(
                                child: Text(
                                  emoji.title,
                                  style: TextStyle(
                                    fontSize: 10, // Slightly smaller to ensure fit
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? emoji.accentColor
                                        : PremiumTheme.secondaryTextColor,
                                    letterSpacing: 0.1,
                                    height: 1.2, // Tighter line height
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build emoji pack tabs (Gen Z and Classic)
  Widget _buildEmojiTabs() {
    final isVerySmallScreen = MediaQuery.of(context).size.height < 600;

    return Container(
      padding: EdgeInsets.all(isVerySmallScreen ? 8.0 : 12.0),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton('Classic', '✨ Classic'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabButton('GenZ', '🏝️ Gen Z'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String packId, String label) {
    final isSelected = _selectedEmojiPack == packId;
    final isVerySmallScreen = MediaQuery.of(context).size.height < 600;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEmojiPack = packId;
          _selectedEmoji = _getDefaultEmoji();
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: PremiumTheme.fastDuration,
        padding: EdgeInsets.symmetric(
          vertical: isVerySmallScreen ? 8.0 : 10.0,
          horizontal: isVerySmallScreen ? 10.0 : 12.0
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? PremiumTheme.accentColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? PremiumTheme.accentColor
                : PremiumTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? PremiumTheme.accentColor
                : PremiumTheme.secondaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Helper methods for emoji pack selection
  PremiumEmojiExpression _getDefaultEmoji() {
    return _getDefaultEmojiForLevel(_urgencyLevel);
  }

  PremiumEmojiExpression _getDefaultEmojiForLevel(String level) {
    if (_selectedEmojiPack == 'GenZ') {
      return GenZIslandEmojiPack.getDefaultForUrgency(level);
    } else {
      return PremiumEmojiPack.getDefaultForUrgency(level);
    }
  }

  /// Select emoji and trigger cinematic confirmation
  void _selectEmojiWithAnimation(PremiumEmojiExpression emoji) async {
    setState(() {
      _selectedEmoji = emoji;
    });

    HapticFeedback.mediumImpact();

    // Do NOT auto-send - user must explicitly press Send button
    // This gives users control over when the alert is actually sent
  }

  /// Play sound effect appropriate to the emoji
  Future<void> _playEmojiSound(PremiumEmojiExpression emoji) async {
    // Sound effects disabled - no sound files in project
    // Haptic feedback is used instead for user feedback
  }



  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
          onPressed: _isValidPlate && !_isLoading && _selectedEmoji != null ? _sendAlert : null,
          onLongPress: _isValidPlate ? _onButtonPress : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: PremiumTheme.accentColor,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: PremiumTheme.accentColor.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: PremiumTheme.mediumRadius,
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            minimumSize: const Size(double.infinity, 56),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Send Respectful Alert',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
    );
  }

  void _validatePlate(String value) {
    final trimmed = value.trim();

    // Remove dashes and spaces to count actual alphanumeric characters
    final cleanValue = trimmed.replaceAll(RegExp(r'[\s-]'), '');

    // Enhanced validation for international plates (supports world's longest plates)
    // - Must have at least 3 alphanumeric characters (excluding dashes/spaces)
    // - Must contain valid characters (letters, numbers, dashes, spaces)
    // - Support various formats from 3 to 15 characters (Germany, Malaysia, etc.)
    final isValid = cleanValue.length >= 3 &&
        cleanValue.length <= 15 &&
        RegExp(r'^[A-Z0-9]+$').hasMatch(cleanValue) &&
        trimmed.isNotEmpty;

    if (isValid != _isValidPlate) {
      setState(() => _isValidPlate = isValid);

      if (isValid) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _onButtonPress() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    HapticFeedback.mediumImpact();
  }

  void _handleBack() {
    HapticFeedback.lightImpact();
    _slideController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  /// Enhanced spam protection system
  /// Prevents abuse while allowing legitimate usage
  String? _checkSpamProtection() {
    final now = DateTime.now();
    final plateNumber = _plateController.text.trim().toUpperCase();

    // Clean up old entries (older than 1 hour)
    _recentAlerts.removeWhere((alert) {
      final parts = alert.split('|');
      if (parts.length >= 2) {
        final timestamp = DateTime.tryParse(parts[1]);
        return timestamp == null || now.difference(timestamp).inHours >= 1;
      }
      return true;
    });

    _lastAlertTimes.removeWhere((plate, time) =>
        now.difference(time).inHours >= 1);

    // Check global rate limit (max alerts per minute)
    if (_lastAnyAlert != null &&
        now.difference(_lastAnyAlert!).inSeconds < 10) {
      return 'Please wait before sending another alert. Rate limit: 10 seconds between alerts.';
    }

    // Check per-plate rate limit
    if (_lastAlertTimes.containsKey(plateNumber)) {
      final timeSinceLastAlert = now.difference(_lastAlertTimes[plateNumber]!).inSeconds;
      if (timeSinceLastAlert < _minTimeBetweenAlerts) {
        final remainingTime = _minTimeBetweenAlerts - timeSinceLastAlert;
        return 'Alert for this plate was recently sent. Please wait ${remainingTime}s before sending again.';
      }
    }

    // Check hourly limit
    final recentCount = _recentAlerts.length;
    if (recentCount >= _maxAlertsPerHour) {
      return 'You\'ve reached the hourly limit of $_maxAlertsPerHour alerts. Please try again later.';
    }

    // Check for duplicate alerts in the last 5 minutes
    final duplicateFound = _recentAlerts.any((alert) {
      final parts = alert.split('|');
      if (parts.length >= 3) {
        final alertPlate = parts[0];
        final alertUrgency = parts[2];
        final timestamp = DateTime.tryParse(parts[1]);
        return alertPlate == plateNumber &&
               alertUrgency == _urgencyLevel &&
               timestamp != null &&
               now.difference(timestamp).inMinutes < 5;
      }
      return false;
    });

    if (duplicateFound) {
      return 'Duplicate alert detected. This exact alert was recently sent for this plate.';
    }

    return null; // No spam detected
  }

  void _recordAlert() {
    final now = DateTime.now();
    final plateNumber = _plateController.text.trim().toUpperCase();

    _lastAnyAlert = now;
    _lastAlertTimes[plateNumber] = now;
    _recentAlerts.add('$plateNumber|${now.toIso8601String()}|$_urgencyLevel');
  }

  Future<void> _sendAlert() async {
    if (!_isValidPlate || _isLoading) return;

    // CRITICAL: Check if user has at least one registered license plate
    if (_primaryPlate == null || _primaryPlate!.isEmpty) {
      _showErrorDialog(
        'Please register at least one license plate before sending alerts.\n\n'
        'Go to "My Vehicles" from the home screen to add your license plate.'
      );
      return;
    }

    // Check spam protection first
    final spamMessage = _checkSpamProtection();
    if (spamMessage != null) {
      _showErrorDialog(spamMessage);
      return;
    }

    // Check payment tier limits
    if (_hasExceededTierLimits()) {
      _showErrorDialog(_getTierCooldownMessage());
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      // Record this alert for spam protection
      _recordAlert();

      final plateNumber = _plateController.text.trim();

      // Send real alert through secure service to live database
      print('📢 Sending real alert to: $plateNumber');

      // Get or create sender user ID
      final prefs = await SharedPreferences.getInstance();
      String? senderUserId = prefs.getString('user_id');

      if (senderUserId == null) {
        senderUserId = await _alertService.getOrCreateUser();
        await prefs.setString('user_id', senderUserId);
      }

      // Send simple alert
      final result = await _alertService.sendAlert(
        targetPlateNumber: plateNumber,
        senderUserId: senderUserId,
        message: '${_urgencyLevel} alert: ${_selectedEmoji?.description ?? 'Vehicle alert'}',
      );

      if (mounted) {
        if (result.success) {
          print('✅ Alert sent successfully to ${result.recipients} users');

          // Record alert timing for payment tier limits
          _paymentTierAlertTimes.add(DateTime.now());
          // Keep only recent alerts (last hour for cleanup)
          _paymentTierAlertTimes.removeWhere((time) => DateTime.now().difference(time).inHours > 1);

          // Increment alerts sent counter in user stats
          await _statsService.incrementAlertsSent();

          // Track alert for unacknowledged monitoring
          if (result.alertId != null) {
            await _unacknowledgedAlertService.trackSentAlert(
              alertId: result.alertId!,
              targetPlateNumber: plateNumber,
              urgencyLevel: _urgencyLevel,
              message: '${_urgencyLevel} alert: ${_selectedEmoji?.description ?? 'Vehicle alert'}',
            );
          }

          // Navigate to alert confirmation
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  FadeTransition(
                opacity: animation,
                child: AlertConfirmationScreen(
                  plateNumber: plateNumber,
                  urgencyLevel: _urgencyLevel,
                  selectedEmoji: _selectedEmoji!,
                ),
              ),
              transitionDuration: PremiumTheme.mediumDuration,
            ),
          );
        } else {
          // Show detailed error message based on failure reason
          final errorMessage = _getDetailedErrorMessage(result.error);
          _showErrorDialog(errorMessage);
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Show detailed network/connection error
        final errorMessage = _getDetailedErrorMessage(e.toString(), isNetworkError: true);
        _showErrorDialog(errorMessage);
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => AlertDialog(
        backgroundColor: PremiumTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: PremiumTheme.largeRadius,
        ),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: PremiumTheme.accentColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Alert Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: PremiumTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to send alert. Please check your connection and try again.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: PremiumTheme.secondaryTextColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: PremiumTheme.accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: PremiumTheme.smallRadius,
                ),
              ),
              child: Text(
                'Understood',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get detailed error message based on the failure reason
  String _getDetailedErrorMessage(String? error, {bool isNetworkError = false}) {
    if (isNetworkError) {
      return 'Connection failed. Please check your internet connection and try again.';
    }

    if (error == null) {
      return 'Alert failed to send. Please try again in a moment.';
    }

    final lowerError = error.toLowerCase();

    // Check for specific error types
    if (lowerError.contains('license plate not registered') || lowerError.contains('not registered')) {
      return 'No users have registered this license plate. The owner needs to install Yuh Blockin to receive alerts.';
    }

    if (lowerError.contains('rate limit') || lowerError.contains('too many') || lowerError.contains('spam')) {
      final isFreeTier = _getUserTier() == 'free';
      if (isFreeTier) {
        return 'Alert rate limit reached. Free users can send 1 alert per minute. Upgrade to Premium for faster alerts!';
      } else {
        return 'Alert rate limit reached. Premium users can send 1 alert every 10 seconds. Please wait before sending another alert.';
      }
    }

    if (lowerError.contains('network') || lowerError.contains('connection') || lowerError.contains('timeout')) {
      return 'Network connection failed. Please check your internet and try again.';
    }

    if (lowerError.contains('invalid') || lowerError.contains('format')) {
      return 'Invalid license plate format. Please check the plate number and try again.';
    }

    if (lowerError.contains('user not found') || lowerError.contains('authentication')) {
      return 'Account verification failed. Please restart the app and try again.';
    }

    if (lowerError.contains('server') || lowerError.contains('database')) {
      return 'Service temporarily unavailable. Our team is working on it. Please try again shortly.';
    }

    // Default error with the original message for debugging
    return 'Alert failed: $error';
  }

  /// Get user's payment tier (free or premium)
  String _getUserTier() {
    // TODO: Implement actual payment tier checking
    // For now, everyone is on free tier
    return 'free';
  }

  /// Check if user has exceeded payment tier limits
  bool _hasExceededTierLimits() {
    final userTier = _getUserTier();
    final now = DateTime.now();

    if (userTier == 'free') {
      // Free tier: 1 alert per minute
      for (final alertTime in _paymentTierAlertTimes) {
        if (now.difference(alertTime).inMinutes < 1) {
          return true;
        }
      }
    } else {
      // Premium tier: 1 alert per 10 seconds
      for (final alertTime in _paymentTierAlertTimes) {
        if (now.difference(alertTime).inSeconds < 10) {
          return true;
        }
      }
    }

    return false;
  }

  /// Get payment tier specific cooldown message
  String _getTierCooldownMessage() {
    final userTier = _getUserTier();

    if (userTier == 'free') {
      return 'Free users can send 1 alert per minute to prevent spam. Upgrade to Premium for faster alerts (1 every 10 seconds)!';
    } else {
      return 'Premium users can send 1 alert every 10 seconds. Please wait before sending another alert.';
    }
  }
}

/// Custom elastic ease-in curve implementation (simulates Curves.easeInElastic)
double _customElasticEaseIn(double t) {
  if (t == 0) return 0;
  if (t == 1) return 1;

  const double c4 = (2 * math.pi) / 3;
  return -(math.pow(2, 10 * (t - 1))) * math.sin((t - 1.1) * c4);
}

/// Enhanced pulse curve combining easeOutCubic expansion with easeInElastic compression
class _EnhancedPulseCurve extends Curve {
  @override
  double transform(double t) {
    // For the first half (0.0 to 0.5): easeOutCubic expansion
    if (t < 0.5) {
      // Map t from [0, 0.5] to [0, 1] for easeOutCubic
      double normalizedT = t * 2.0;
      // easeOutCubic formula: 1 - (1 - x)^3
      return Curves.easeOutCubic.transform(normalizedT);
    }
    // For the second half (0.5 to 1.0): easeInElastic compression (subtle)
    else {
      // Map t from [0.5, 1] to [1, 0] for reverse effect
      double normalizedT = (t - 0.5) * 2.0;
      // Custom elastic compression return (simulate easeInElastic)
      double elasticValue = _customElasticEaseIn(normalizedT);
      // Invert the elastic value and blend it back to 1.0
      return 1.0 - (elasticValue * 0.3); // 30% elastic intensity for subtlety
    }
  }
}

