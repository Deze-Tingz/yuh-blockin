import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

import '../../core/theme/premium_theme.dart';
import '../../config/premium_config.dart';
import '../../core/services/premium_backend_service.dart';
import '../../core/services/plate_storage_service.dart';
import '../../main_premium.dart';

/// License Plate Registration Screen
///
/// Secure registration with HMAC-SHA256 hashing for privacy
/// Includes subtle playful elements while maintaining premium aesthetic
class PlateRegistrationScreen extends StatefulWidget {
  final bool isOnboarding;

  const PlateRegistrationScreen({
    super.key,
    this.isOnboarding = false,
  });

  @override
  State<PlateRegistrationScreen> createState() => _PlateRegistrationScreenState();
}

class _PlateRegistrationScreenState extends State<PlateRegistrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _plateController;
  late AnimationController _sparkleController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _plateAnimation;
  late Animation<double> _sparkleAnimation;

  final TextEditingController _plateInputController = TextEditingController();
  final FocusNode _plateFocusNode = FocusNode();

  final PlateStorageService _storageService = PlateStorageService();
  final PremiumBackendService _backendService = PremiumBackendService();

  List<String> _registeredPlates = [];
  bool _isValidPlate = false;
  bool _isRegistering = false;
  String _platePreview = '';
  int _sparkleIndex = 0;

  final List<String> _playfulMessages = [
    '🚗 Your digital parking passport',
    '🔒 Secured with mathematical precision',
    '✨ Adding some premium magic...',
    '🎯 Almost there, parking champion!',
    '🌟 Welcome to respectful parking!',
  ];

  final List<Color> _playfulColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF10B981), // Emerald
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadExistingPlates();
    _startSparkleRotation();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: PremiumTheme.mediumDuration,
      vsync: this,
    );

    _plateController = AnimationController(
      duration: PremiumTheme.fastDuration,
      vsync: this,
    );

    _sparkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _plateAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _plateController,
      curve: Curves.elasticOut,
    ));

    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _plateController.forward();
    _sparkleController.repeat();
  }

  void _startSparkleRotation() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _sparkleIndex = (_sparkleIndex + 1) % _playfulMessages.length;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadExistingPlates() async {
    try {
      final plates = await _storageService.getRegisteredPlates();
      setState(() {
        _registeredPlates = plates;
      });
    } catch (e) {
      print('Failed to load existing plates: $e');
    }
  }

  void _validatePlate(String value) {
    String normalizedPlate = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

    // Auto-format with dash between letters and numbers
    normalizedPlate = _formatPlateWithDash(normalizedPlate);

    final isValid = normalizedPlate.length >= 3 &&
                   normalizedPlate.length <= 12 && // Allow for dash
                   RegExp(r'^[A-Z0-9\s\-]+$').hasMatch(normalizedPlate) &&
                   !_registeredPlates.contains(normalizedPlate);

    setState(() {
      _isValidPlate = isValid;
      _platePreview = normalizedPlate;
    });

    if (normalizedPlate != value) {
      _plateInputController.value = TextEditingValue(
        text: normalizedPlate,
        selection: TextSelection.collapsed(offset: normalizedPlate.length),
      );
    }

    if (isValid) {
      HapticFeedback.lightImpact();
      _plateController.reset();
      _plateController.forward();
    }
  }

  String _formatPlateWithDash(String input) {
    // Remove any existing dashes and spaces for clean processing
    String clean = input.replaceAll(RegExp(r'[\s\-]'), '');

    if (clean.isEmpty) return clean;

    // Find transition from letters to numbers or numbers to letters
    String formatted = '';
    for (int i = 0; i < clean.length; i++) {
      if (i > 0) {
        final currentIsDigit = RegExp(r'\d').hasMatch(clean[i]);
        final previousIsDigit = RegExp(r'\d').hasMatch(clean[i - 1]);

        // Add dash when transitioning between letters and numbers
        if (currentIsDigit != previousIsDigit) {
          formatted += '-';
        }
      }
      formatted += clean[i];
    }

    return formatted;
  }

  Future<void> _registerPlate() async {
    if (!_isValidPlate || _isRegistering) return;

    setState(() => _isRegistering = true);
    HapticFeedback.mediumImpact();

    try {
      final plateNumber = _plateInputController.text.trim();

      // Save to secure storage
      await _storageService.addPlate(plateNumber);

      // Update backend (in real app, this would sync with server)
      // For now, we'll simulate the backend registration
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _registeredPlates.add(plateNumber);
        _plateInputController.clear();
        _platePreview = '';
        _isValidPlate = false;
      });

      _showSuccessAnimation();

    } catch (e) {
      _showErrorMessage(e.toString());
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  void _showSuccessAnimation() {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _SuccessAnimation(
        onComplete: () {
          Navigator.of(context).pop();
          if (widget.isOnboarding && _registeredPlates.isNotEmpty) {
            // Complete onboarding and go to main app
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const PremiumHomeScreen(),
              ),
            );
          }
        },
      ),
    );
  }

  void _showErrorMessage(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Registration failed: $error'),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _plateController.dispose();
    _sparkleController.dispose();
    _plateInputController.dispose();
    _plateFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 80.0 : 32.0,
              vertical: 40.0,
            ),
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Flexible space
                const Expanded(flex: 1, child: SizedBox()),

                // Main content
                _buildMainContent(isTablet),

                // Flexible space
                const Expanded(flex: 1, child: SizedBox()),

                // Registered plates list
                if (_registeredPlates.isNotEmpty) _buildRegisteredPlates(),

                const SizedBox(height: 40),
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
        if (!widget.isOnboarding)
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PremiumTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: PremiumTheme.subtleShadow,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: PremiumTheme.primaryTextColor,
                size: 20,
              ),
            ),
          )
        else
          const SizedBox(width: 40),

        // Clean minimalist navigation
        Container(
          width: 32,
          height: 2,
          decoration: BoxDecoration(
            color: PremiumTheme.accentColor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(1),
          ),
        ),

        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildMainContent(bool isTablet) {
    return Column(
      children: [
        // Ultra-minimalist hero section
        Container(
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 56 : 40,
            horizontal: isTablet ? 48 : 32,
          ),
          child: Column(
            children: [
              // Breathing logo
              AnimatedBuilder(
                animation: _sparkleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (sin(_sparkleAnimation.value * 2 * pi) * 0.05),
                    child: Container(
                      width: isTablet ? 72 : 60,
                      height: isTablet ? 72 : 60,
                      margin: const EdgeInsets.only(bottom: 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            PremiumTheme.accentColor,
                            PremiumTheme.accentColor.withOpacity(0.8),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: PremiumTheme.accentColor.withOpacity(0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_car_rounded,
                        size: isTablet ? 36 : 30,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              // Dynamic header based on context
              Column(
                children: [
                  Text(
                    widget.isOnboarding ? 'Vehicle Registry' : 'Enter the plate of',
                    style: TextStyle(
                      fontSize: isTablet ? 48 : 40,
                      fontWeight: FontWeight.w100,
                      color: PremiumTheme.primaryTextColor,
                      letterSpacing: -1.0,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!widget.isOnboarding) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            PremiumTheme.accentColor.withOpacity(0.15),
                            PremiumTheme.accentColor.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: PremiumTheme.accentColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'the car blocking you',
                        style: TextStyle(
                          fontSize: isTablet ? 32 : 28,
                          fontWeight: FontWeight.w300,
                          color: PremiumTheme.accentColor,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Subtle status indicator
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

        const SizedBox(height: 32),

        // Clean status message
        Container(
          height: 40,
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Text(
              key: ValueKey(_sparkleIndex),
              _playfulMessages[_sparkleIndex].replaceAll('🚗', '').replaceAll('🔒', '').replaceAll('✨', '').replaceAll('🎯', '').replaceAll('🌟', '').trim(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: PremiumTheme.secondaryTextColor.withOpacity(0.8),
                letterSpacing: 0.2,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        const SizedBox(height: 48),

        // Premium plate input
        ScaleTransition(
          scale: _plateAnimation,
          child: _buildUltraPremiumPlateInput(isTablet),
        ),

        const SizedBox(height: 48),

        // Minimalist register button
        _buildMinimalistRegisterButton(isTablet),
      ],
    );
  }

  Widget _buildPremiumPlateInput(bool isTablet) {
    return Column(
      children: [
        // Elite license plate preview
        if (_platePreview.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.blue.shade50,
                  Colors.white,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: PremiumTheme.accentColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: PremiumTheme.accentColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PremiumTheme.accentColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car_rounded,
                        color: PremiumTheme.accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      _platePreview,
                      style: TextStyle(
                        fontSize: isTablet ? 32 : 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade800,
                        letterSpacing: 3.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified_rounded,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'License plate secured with enterprise-grade encryption',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

        // Premium input field with enhanced design
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PremiumTheme.surfaceColor,
                PremiumTheme.surfaceColor.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _isValidPlate
                    ? PremiumTheme.accentColor.withOpacity(0.2)
                    : Colors.black.withOpacity(0.08),
                blurRadius: _isValidPlate ? 20 : 12,
                offset: const Offset(0, 6),
                spreadRadius: _isValidPlate ? 2 : 0,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 1,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: _isValidPlate
                  ? PremiumTheme.accentColor.withOpacity(0.4)
                  : PremiumTheme.dividerColor.withOpacity(0.3),
              width: _isValidPlate ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: _plateInputController,
            focusNode: _plateFocusNode,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 32 : 28,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 3.0,
            ),
            decoration: InputDecoration(
              hintText: 'ABC 123',
              hintStyle: TextStyle(
                color: PremiumTheme.tertiaryTextColor.withOpacity(0.6),
                fontWeight: FontWeight.w400,
                letterSpacing: 2.0,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              border: InputBorder.none,
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 16, right: 8),
                child: Icon(
                  Icons.edit_rounded,
                  color: _isValidPlate
                      ? PremiumTheme.accentColor
                      : PremiumTheme.tertiaryTextColor,
                  size: 24,
                ),
              ),
              suffixIcon: _isValidPlate
                  ? Container(
                      margin: const EdgeInsets.only(right: 16, left: 8),
                      child: Icon(
                        Icons.verified_rounded,
                        color: Colors.green,
                        size: 28,
                      ),
                    )
                  : null,
            ),
            onChanged: _validatePlate,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s]')),
              LengthLimitingTextInputFormatter(10),
            ],
          ),
        ),

        if (_isValidPlate) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.05),
                  Colors.green.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.enhanced_encryption_rounded,
                  size: 20,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 12),
                Text(
                  'Secured with HMAC-SHA256 encryption',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUltraPremiumPlateInput(bool isTablet) {
    return Column(
      children: [
        // Ultra-clean license plate preview
        if (_platePreview.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 40),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 32 : 24,
              vertical: isTablet ? 20 : 16,
            ),
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: PremiumTheme.accentColor.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: PremiumTheme.accentColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              _platePreview,
              style: TextStyle(
                fontSize: isTablet ? 32 : 28,
                fontWeight: FontWeight.w300,
                color: PremiumTheme.primaryTextColor,
                letterSpacing: 4.0,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Ultra-minimalist input field
        Container(
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isValidPlate
                  ? PremiumTheme.accentColor.withOpacity(0.3)
                  : PremiumTheme.dividerColor.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isValidPlate
                    ? PremiumTheme.accentColor.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04),
                blurRadius: _isValidPlate ? 16 : 8,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextField(
            controller: _plateInputController,
            focusNode: _plateFocusNode,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.w400,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 3.0,
            ),
            decoration: InputDecoration(
              hintText: 'ABC-123',
              hintStyle: TextStyle(
                color: PremiumTheme.tertiaryTextColor.withOpacity(0.5),
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 32 : 24,
                vertical: isTablet ? 24 : 20,
              ),
              border: InputBorder.none,
            ),
            onChanged: _validatePlate,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s\-]')),
              LengthLimitingTextInputFormatter(12),
            ],
          ),
        ),

        if (_isValidPlate) ...[
          const SizedBox(height: 24),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMinimalistRegisterButton(bool isTablet) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: isTablet ? 320 : 280,
      ),
      height: 56,
      child: ElevatedButton(
        onPressed: _isValidPlate && !_isRegistering ? _registerPlate : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isValidPlate
              ? PremiumTheme.accentColor
              : PremiumTheme.surfaceColor,
          foregroundColor: _isValidPlate
              ? Colors.white
              : PremiumTheme.tertiaryTextColor.withOpacity(0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: _isValidPlate
                  ? Colors.transparent
                  : PremiumTheme.dividerColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        child: _isRegistering
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isValidPlate ? 'Register' : 'Enter plate number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildRegisteredPlates() {
    return Container(
      child: Column(
        children: [
          // Minimalist section header
          Container(
            width: 24,
            height: 2,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: PremiumTheme.accentColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          Text(
            'Registered Vehicles',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w200,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 24),

          ..._registeredPlates.map((plate) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PremiumTheme.dividerColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    plate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: PremiumTheme.primaryTextColor,
                      letterSpacing: 2.0,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}

/// Success animation overlay with playful celebration
class _SuccessAnimation extends StatefulWidget {
  final VoidCallback onComplete;

  const _SuccessAnimation({required this.onComplete});

  @override
  State<_SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<_SuccessAnimation>
    with TickerProviderStateMixin {
  late AnimationController _celebrationController;
  late Animation<double> _celebrationAnimation;

  @override
  void initState() {
    super.initState();

    _celebrationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );

    _celebrationController.forward();

    Timer(const Duration(seconds: 2), () {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: _celebrationAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _celebrationAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(40),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: PremiumTheme.surfaceColor,
                  borderRadius: PremiumTheme.extraLargeRadius,
                  boxShadow: [
                    BoxShadow(
                      color: PremiumTheme.accentColor.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🎉',
                      style: TextStyle(fontSize: 60),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Plate Registered!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: PremiumTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your vehicle is now protected with\nmilitary-grade security',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: PremiumTheme.secondaryTextColor,
                        height: 1.5,
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