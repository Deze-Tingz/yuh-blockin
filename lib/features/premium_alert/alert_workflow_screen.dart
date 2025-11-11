import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;

import '../../core/theme/premium_theme.dart';
import '../../config/premium_config.dart';
import '../../core/services/plate_storage_service.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _plateController = TextEditingController();
  final FocusNode _plateFocusNode = FocusNode();
  final PlateStorageService _plateStorageService = PlateStorageService();

  String _urgencyLevel = 'Normal';
  PremiumEmojiExpression? _selectedEmoji;
  bool _isValidPlate = false;
  bool _isLoading = false;
  String? _primaryPlate;

  // Emoji pack selection
  String _selectedEmojiPack = 'GenZ'; // 'GenZ' or 'Classic'

  // Enhanced emoji selection state
  bool _showingCinematicConfirmation = false;
  late AnimationController _cinematicController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _backgroundFadeAnimation;
  late Animation<double> _buttonSlideAnimation;

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

    // Cinematic emoji confirmation animation
    _cinematicController = AnimationController(
      duration: const Duration(seconds: 2),
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

    // Cinematic animations with enhanced curves
    _zoomAnimation = Tween<double>(
      begin: 1.0,
      end: 3.5,
    ).animate(CurvedAnimation(
      parent: _cinematicController,
      // Custom curve: easeOutCubic on expansion, easeInElastic on compression
      curve: _EnhancedPulseCurve(),
    ));

    _backgroundFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _cinematicController,
      curve: Curves.easeOut,
    ));

    _buttonSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cinematicController,
      curve: Interval(0.6, 1.0, curve: Curves.elasticOut),
    ));

    // Start entrance animation
    _slideController.forward();

    // Load primary license plate
    _loadPrimaryPlate();

    // Auto-focus plate input after animation
    Future.delayed(PremiumTheme.mediumDuration, () {
      if (mounted) {
        _plateFocusNode.requestFocus();
      }
    });
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

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _cinematicController.dispose();
    _plateController.dispose();
    _plateFocusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor.withOpacity(0.95),
      body: Stack(
        children: [
          // Main content
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedBuilder(
                animation: _backgroundFadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _backgroundFadeAnimation.value,
                    child: SafeArea(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 80.0 : 32.0,
                vertical: 40.0,
              ),
              child: Column(
                children: [
                  // Header with back action
                  _buildHeader(context),

                  const SizedBox(height: 40),

                  // Main scrollable content for mobile
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // User vehicle context badge
                          if (_primaryPlate != null) _buildVehicleContextBadge(),

                          // Title and description
                          _buildTitle(),

                          const SizedBox(height: 24),

                          // License plate input
                          _buildPlateInput(),

                          const SizedBox(height: 20),

                          // Urgency selection
                          _buildUrgencySelection(),

                          const SizedBox(height: 20),

                          // Emoji expression selection
                          _buildEmojiSelector(),

                          const SizedBox(height: 20),

                          // Send alert button
                          _buildSendButton(),

                          const SizedBox(height: 40),
                        ],
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
          ),

          // Cinematic emoji confirmation overlay
          if (_showingCinematicConfirmation)
            _buildCinematicConfirmation(),
        ],
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumTheme.accentColor.withOpacity(0.08),
              PremiumTheme.accentColor.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PremiumTheme.accentColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_rounded,
              size: 14,
              color: PremiumTheme.accentColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Your Vehicle: $_primaryPlate',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PremiumTheme.accentColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        // Enhanced title with premium styling
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PremiumTheme.surfaceColor,
                PremiumTheme.surfaceColor.withOpacity(0.9),
              ],
            ),
            borderRadius: PremiumTheme.largeRadius,
            boxShadow: [
              BoxShadow(
                color: PremiumTheme.accentColor.withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, 6),
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
                    fontSize: 30,
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
                        shadows: [
                          Shadow(
                            color: PremiumTheme.accentColor.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    TextSpan(text: ' Alert'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Subtle accent line
              Container(
                width: 60,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      PremiumTheme.accentColor.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Enhanced description with subtle container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PremiumTheme.accentColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Let someone know their car needs to be moved.\nYour message will be polite and respectful.',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: PremiumTheme.secondaryTextColor,
              height: 1.6,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPlateInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'License Plate Number',
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
                horizontal: 24,
                vertical: 20,
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

        if (_isValidPlate)
          Padding(
            padding: const EdgeInsets.only(top: 12),
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

        const SizedBox(height: 12),

        // Alert preview with emoji and signature message
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
            borderRadius: PremiumTheme.largeRadius,
            border: Border.all(
              color: _selectedEmoji?.accentColor.withOpacity(0.2) ??
                PremiumTheme.accentColor.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _selectedEmoji?.accentColor.withOpacity(0.1) ??
                  PremiumTheme.accentColor.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Preview label
              Text(
                'Your Alert Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _selectedEmoji?.accentColor ?? PremiumTheme.accentColor,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 16),

              // Alert content - centered layout
              Column(
                children: [
                  if (_selectedEmoji != null) ...[
                    AnimatedEmojiWidget(
                      expression: _selectedEmoji!,
                      isSelected: true,
                      isPlaying: true,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Yuh Blockin!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.primaryTextColor,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Expression description
              if (_selectedEmoji != null)
                Text(
                  _selectedEmoji!.description,
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

        const SizedBox(height: 20),

        // Enhanced emoji grid selector
        _buildEnhancedEmojiGrid(),
      ],
    );
  }

  /// Enhanced emoji grid with tabs - choose between Gen Z and Classic emoji packs
  Widget _buildEnhancedEmojiGrid() {
    final availableEmojis = _selectedEmojiPack == 'GenZ'
        ? GenZIslandEmojiPack.expressions
        : PremiumEmojiPack.expressions;

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
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
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
                    size: 42, // Optimized size for compact layout
                  ),
                  const SizedBox(height: 6),
                  // Emoji title
                  Text(
                    emoji.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                        ? emoji.accentColor
                        : PremiumTheme.secondaryTextColor,
                      letterSpacing: 0.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton('GenZ', '🏝️ Gen Z'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTabButton('Classic', '✨ Classic'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String packId, String label) {
    final isSelected = _selectedEmojiPack == packId;

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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? PremiumTheme.accentColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
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
      _showingCinematicConfirmation = true;
    });

    HapticFeedback.mediumImpact();

    // Play appropriate sound effect
    await _playEmojiSound(emoji);

    // Start cinematic zoom animation
    _cinematicController.forward();
  }

  /// Play sound effect appropriate to the emoji
  Future<void> _playEmojiSound(PremiumEmojiExpression emoji) async {
    try {
      // Map emoji types to sound effects (you'll need to add these assets)
      String soundAsset;

      switch (emoji.animationType) {
        case EmojiAnimationType.gentle:
          soundAsset = 'sounds/gentle_chime.mp3';
          break;
        case EmojiAnimationType.playful:
          soundAsset = 'sounds/playful_pop.mp3';
          break;
        case EmojiAnimationType.pulse:
          soundAsset = 'sounds/pulse_beep.mp3';
          break;
        case EmojiAnimationType.urgent:
          soundAsset = 'sounds/urgent_alert.mp3';
          break;
        case EmojiAnimationType.apologetic:
          soundAsset = 'sounds/soft_bell.mp3';
          break;
        case EmojiAnimationType.celebration:
          soundAsset = 'sounds/celebration_chime.mp3';
          break;
      }

      await _audioPlayer.play(AssetSource(soundAsset));
    } catch (e) {
      // Gracefully handle missing sound files
      print('Sound effect not available: $e');
    }
  }

  /// Cinematic emoji confirmation overlay
  Widget _buildCinematicConfirmation() {
    if (_selectedEmoji == null) return const SizedBox();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _zoomAnimation,
        _buttonSlideAnimation,
      ]),
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Enhanced emoji with unified pulse/glow system
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Trailing glow halo (lags 120-200ms behind pulse)
                    AnimatedBuilder(
                      animation: _zoomAnimation,
                      builder: (context, child) {
                        // Calculate lagging glow scale
                        double glowScale = 0.8 + (_zoomAnimation.value - 1) * 0.7;
                        glowScale = glowScale.clamp(0.8, 2.0);

                        return Transform.scale(
                          scale: glowScale,
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _selectedEmoji!.accentColor.withOpacity(0.15),
                                  _selectedEmoji!.accentColor.withOpacity(0.08),
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Main circular pulse with enhanced shadow + rim light
                    AnimatedBuilder(
                      animation: _zoomAnimation,
                      builder: (context, child) {
                        // easeOutCubic on expansion, easeInElastic on compression
                        double pulseScale = _zoomAnimation.value;
                        double shadowBlur = 20 + (pulseScale - 1) * 15; // +30-45% increase
                        double shadowOpacity = 0.3 - (pulseScale - 1) * 0.1; // Reduce slightly

                        return Transform.scale(
                          scale: pulseScale,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _selectedEmoji!.accentColor.withOpacity(0.25),
                                  _selectedEmoji!.accentColor.withOpacity(0.15),
                                  _selectedEmoji!.accentColor.withOpacity(0.05),
                                ],
                                stops: [0.0, 0.7, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _selectedEmoji!.accentColor.withOpacity(shadowOpacity),
                                  blurRadius: shadowBlur,
                                  offset: const Offset(0, 8),
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: 2,
                                  // Blue-to-warm rim light gradient effect
                                  color: _selectedEmoji!.accentColor.withOpacity(0.4),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.withOpacity(0.1),
                                    Colors.transparent,
                                    Colors.orange.withOpacity(0.1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Emoji with gel stretch + enhanced motion
                    AnimatedBuilder(
                      animation: _zoomAnimation,
                      builder: (context, child) {
                        // 2-4% vertical gel stretch before pulse expansion
                        double verticalStretch = 1.0;
                        if (_zoomAnimation.value > 1.0 && _zoomAnimation.value < 1.2) {
                          verticalStretch = 1.0 + ((_zoomAnimation.value - 1.0) * 0.03);
                        }

                        return Transform.scale(
                          scaleY: verticalStretch,
                          scaleX: 1.0,
                          child: Transform.scale(
                            scale: _zoomAnimation.value,
                            child: AnimatedEmojiWidget(
                              expression: _selectedEmoji!,
                              isSelected: true,
                              isPlaying: true,
                              size: 120,
                            ),
                          ),
                        );
                      },
                    ),

                    // "Yuh Blockin!" text inside circular zone with glass capsule
                    AnimatedBuilder(
                      animation: _zoomAnimation,
                      builder: (context, child) {
                        // Text follows pulse by 150-220ms and scales +3% to +5%
                        double textScale = 1.0 + ((_zoomAnimation.value - 1.0) * 0.04);
                        double textOpacity = _zoomAnimation.value > 1.1 ? 1.0 : 0.0;
                        double slideOffset = textOpacity < 1.0 ? 20.0 : 0.0;

                        return Positioned(
                          bottom: 20,
                          child: Transform.translate(
                            offset: Offset(0, slideOffset),
                            child: Opacity(
                              opacity: textOpacity,
                              child: Transform.scale(
                                scale: textScale,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    // Translucent glass capsule
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20), // Organically curved
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                    // Blur effect simulation
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.1),
                                        blurRadius: 15,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Text(
                                      'Yuh Blockin!',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro', // SF Rounded/Inter SemiBold
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: -0.5, // -1% to -3% negative spacing
                                        shadows: [
                                          Shadow(
                                            color: _selectedEmoji!.accentColor.withOpacity(0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Slide-up Send button
                Transform.translate(
                  offset: Offset(0, (1 - _buttonSlideAnimation.value) * 100),
                  child: Opacity(
                    opacity: _buttonSlideAnimation.value,
                    child: Column(
                      children: [
                        const SizedBox(height: 120),

                        // Send button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Cancel button
                            GestureDetector(
                              onTap: _cancelCinematicConfirmation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.8),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 20),

                            // Send button
                            GestureDetector(
                              onTap: _confirmAndSendAlert,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      _selectedEmoji!.accentColor,
                                      _selectedEmoji!.accentColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _selectedEmoji!.accentColor.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.send,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Send',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Cancel cinematic confirmation and return to selection
  void _cancelCinematicConfirmation() {
    _cinematicController.reverse().then((_) {
      setState(() {
        _showingCinematicConfirmation = false;
      });
    });
    HapticFeedback.lightImpact();
  }

  /// Confirm emoji selection and proceed to send alert
  void _confirmAndSendAlert() {
    if (_selectedEmoji == null || !_isValidPlate || _isLoading) return;

    HapticFeedback.heavyImpact();

    // Close cinematic confirmation
    setState(() {
      _showingCinematicConfirmation = false;
    });
    _cinematicController.reset();

    // Proceed with sending alert
    _sendAlert();
  }

  Widget _buildSendButton() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: double.infinity,
        height: 56,
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
            padding: EdgeInsets.zero,
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

    // Check spam protection first
    final spamMessage = _checkSpamProtection();
    if (spamMessage != null) {
      _showErrorDialog(spamMessage);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      // Record this alert for spam protection
      _recordAlert();

      // Simulate alert sending with delay for UX
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // Navigate to alert confirmation with Manim animation
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                FadeTransition(
              opacity: animation,
              child: AlertConfirmationScreen(
                plateNumber: _plateController.text.trim(),
                urgencyLevel: _urgencyLevel,
                selectedEmoji: _selectedEmoji!,
              ),
            ),
            transitionDuration: PremiumTheme.mediumDuration,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog(e.toString());
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

