import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

import '../../core/theme/premium_theme.dart';
import '../../config/premium_config.dart';
import '../../core/services/premium_backend_service.dart';
import '../../core/services/plate_storage_service.dart';
import '../../core/services/simple_alert_service.dart';
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
  final SimpleAlertService _alertService = SimpleAlertService();

  List<String> _registeredPlates = [];
  String? _primaryPlate;
  bool _isValidPlate = false;
  bool _isRegistering = false;
  int _sparkleIndex = 0;

  bool get _isAtMaxCapacity => _registeredPlates.length >= PlateStorageService.maxVehicles;

  // Timer reference for proper cleanup
  Timer? _sparkleTimer;

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
    _initializeServices();
    _loadExistingPlates();
    _startSparkleRotation();
  }

  Future<void> _initializeServices() async {
    try {
      await _alertService.initialize();
      if (kDebugMode) {
        print('✅ Simple alert service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to initialize secure service: $e');
      }
    }
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
    _sparkleTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
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
      final primaryPlate = await _storageService.getPrimaryPlate();
      setState(() {
        _registeredPlates = plates;
        _primaryPlate = primaryPlate;
      });
      if (kDebugMode) {
        print('✅ Loaded ${plates.length} registered plates from local storage');
        print('✅ Primary plate: ${primaryPlate ?? "none set"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load existing plates: $e');
      }
    }
  }

  Future<void> _setPrimaryPlate(String plate) async {
    try {
      await _storageService.setPrimaryPlate(plate);
      setState(() {
        _primaryPlate = plate;
      });

      print('✅ Set $plate as primary vehicle');

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$plate set as primary vehicle'),
            backgroundColor: PremiumTheme.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting primary plate: $e');
      }
    }
  }

  void _validatePlate(String value) {
    if (value.isEmpty) {
      setState(() {
        _isValidPlate = false;
      });
      return;
    }

    String normalizedPlate = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

    // Auto-format with dash between letters and numbers
    normalizedPlate = _formatPlateWithDash(normalizedPlate);

    final lengthValid = normalizedPlate.length >= 2 && normalizedPlate.length <= 12;
    final formatValid = RegExp(r'^[A-Z0-9\s\-]+$').hasMatch(normalizedPlate);
    final hasAlphaNumeric = RegExp(r'[A-Z0-9]').hasMatch(normalizedPlate);
    final notDuplicate = !_registeredPlates.contains(normalizedPlate);

    final isValid = lengthValid && formatValid && hasAlphaNumeric && notDuplicate;

    print('Validating plate "$value" -> "$normalizedPlate"');
    print('Length valid: $lengthValid (${normalizedPlate.length})');
    print('Format valid: $formatValid');
    print('Has alphanumeric: $hasAlphaNumeric');
    print('Not duplicate: $notDuplicate');
    print('Overall valid: $isValid');

    setState(() {
      _isValidPlate = isValid;
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

      if (kDebugMode) {
        print('🔐 Registering plate with multi-user privacy protection: $plateNumber');
      }

      // Initialize simple alert service
      await _alertService.initialize();

      // Generate or retrieve user ID
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      // Check if user ID exists AND if the user actually exists in the database
      bool needsNewUser = userId == null;
      if (userId != null) {
        if (kDebugMode) {
          print('🔍 Found existing userId in prefs: $userId');
          print('🔍 Verifying user exists in database...');
        }

        bool userExistsInDB = await _alertService.userExists(userId);
        if (!userExistsInDB) {
          if (kDebugMode) {
            print('⚠️ User ID exists in prefs but NOT in database! Need to create user.');
          }
          needsNewUser = true;
        } else {
          if (kDebugMode) {
            print('✅ User verified to exist in database: $userId');
          }
        }
      }

      if (needsNewUser) {
        try {
          // Create new user profile
          if (kDebugMode) {
            print('🔍 Creating new user...');
          }
          userId = await _alertService.getOrCreateUser();
          await prefs.setString('user_id', userId);
          if (kDebugMode) {
            print('🆕 Created new user: $userId');
          }

          // Small delay to ensure user creation is fully committed before plate registration
          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to create user: $e');
          }
          setState(() => _isRegistering = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create user profile. Please check your internet connection and try again.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
          return; // Don't continue if user creation failed
        }
      }

      // Register plate with simple service
      if (userId != null) {
        await _alertService.registerPlate(
          plateNumber: plateNumber,
          userId: userId,
        );
      } else {
        throw Exception('User ID is null after creation attempts');
      }

      // Save to local storage as well
      await _storageService.addPlate(plateNumber);

      // Registration successful - refresh the plates list
      await _loadExistingPlates();

      // CRITICAL FIX for onboarding: Ensure plate is in the list
      if (!_registeredPlates.contains(plateNumber)) {
        setState(() {
          _registeredPlates.add(plateNumber);
        });
        if (kDebugMode) {
          print('🔧 ONBOARDING FIX: Added plate $plateNumber to list');
        }
      }

      // Auto-set as primary if it's the first vehicle
      if (_primaryPlate == null || _registeredPlates.length == 1) {
        await _setPrimaryPlate(plateNumber);
        if (kDebugMode) {
          print('✅ Auto-set $plateNumber as primary (first vehicle)');
        }
      }

      setState(() {
        _plateInputController.clear();
        _isValidPlate = false;
      });

      _showSuccessMessage('Plate registered successfully! Multiple users can now register this same plate.');
      _showSuccessAnimation();

    } catch (e) {
      if (kDebugMode) {
        print('❌ Multi-user registration failed: $e');
      }

      // Handle specific error cases
      String errorMessage = e.toString();
      if (errorMessage.contains('USER_DUPLICATE')) {
        errorMessage = 'You have already registered this license plate.';
      } else if (errorMessage.contains('INIT_ERROR')) {
        errorMessage = 'Failed to connect to registration system. Please check your internet connection.';
      } else {
        errorMessage = 'Registration failed. Please try again.';
      }

      _showErrorMessage(errorMessage);
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessAnimation() {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissing dialog
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _SuccessAnimation(
        onComplete: () {
          Navigator.of(context).pop(); // Close the dialog
          if (widget.isOnboarding && _registeredPlates.isNotEmpty) {
            // Complete onboarding and go to main app
            _completeOnboarding();
          } else if (!widget.isOnboarding) {
            // For non-onboarding mode, go back to previous screen
            Navigator.of(context).pop();
          }
        },
      ),
    );

    // Fallback timeout to ensure navigation works
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close dialog if still open
        if (!widget.isOnboarding) {
          Navigator.of(context).pop(); // Go back to home
        }
      }
    });
  }

  void _showErrorMessage(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Registration failed: $error'),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show confirmation dialog before deleting a plate
  void _confirmDeletePlate(String plate) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Vehicle',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to remove this vehicle from your registry?',
                style: TextStyle(
                  fontSize: 16,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: PremiumTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: PremiumTheme.dividerColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  plate,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.primaryTextColor,
                    letterSpacing: 2.0,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: PremiumTheme.secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePlate(plate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Delete a plate from storage and update the UI
  Future<void> _deletePlate(String plate) async {
    try {
      // Get user ID for database operations
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      // Remove from database first
      if (userId != null) {
        try {
          await _alertService.deletePlate(
            plateNumber: plate,
            userId: userId,
          );
          if (kDebugMode) {
            print('✅ Deleted plate from database: $plate');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to delete plate from database: $e');
          }
          // Continue with local deletion even if database deletion fails
        }
      }

      // Remove from local storage
      await _storageService.removePlate(plate);

      // Refresh the plates list
      await _loadExistingPlates();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vehicle deleted successfully'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1500),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete vehicle: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Cancel timer to prevent memory leak
    _sparkleTimer?.cancel();

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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Header
                    _buildHeader(),

                    // Fixed spacing to replace flexible space
                    SizedBox(height: isTablet ? 60 : 40),

                    // Main content
                    _buildMainContent(isTablet),

                    // Fixed spacing to replace flexible space
                    SizedBox(height: isTablet ? 60 : 40),

                    // Registered plates list
                    if (_registeredPlates.isNotEmpty) _buildRegisteredPlates(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ), // closes SafeArea & body
    ); // closes Scaffold
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

  /// Complete onboarding and navigate to main app
  Future<void> _completeOnboarding() async {
    try {
      // Mark onboarding as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (kDebugMode) {
        print('✅ Onboarding marked as completed');
      }

      // Navigate to main app
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PremiumHomeScreen(),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to complete onboarding: $e');
      }
      // Fallback navigation even if prefs fails
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PremiumHomeScreen(),
          ),
        );
      }
    }
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

              // Clear header that reflects vehicle management focus
              Container(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 600 : 340,
                ),
                child: Text(
                  widget.isOnboarding
                      ? 'Vehicle Registry'
                      : 'My Vehicles',
                  style: TextStyle(
                    fontSize: isTablet ? 32 : 24, // Match onboarding welcome text size
                    fontWeight: FontWeight.w300,
                    color: PremiumTheme.primaryTextColor,
                    letterSpacing: 0.5,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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

        // Show input or max capacity message
        if (_isAtMaxCapacity)
          _buildMaxCapacityMessage(isTablet)
        else ...[
          // Premium plate input
          ScaleTransition(
            scale: _plateAnimation,
            child: _buildUltraPremiumPlateInput(isTablet),
          ),

          const SizedBox(height: 48),

          // Minimalist register button
          _buildMinimalistRegisterButton(isTablet),
        ],
      ],
    );
  }

  Widget _buildMaxCapacityMessage(bool isTablet) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: isTablet ? 400 : 320,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.garage_outlined,
            size: 48,
            color: Colors.amber.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'Garage Full',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve registered the maximum of ${PlateStorageService.maxVehicles} vehicles. Remove a vehicle to add a new one.',
            style: TextStyle(
              fontSize: 14,
              color: PremiumTheme.secondaryTextColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPlateInput(bool isTablet) {
    return Column(
      children: [

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
              hintText: 'YOURPLATE',
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

        // Ultra-minimalist input field
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: isTablet ? 400 : 320,
          ),
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
              hintText: 'YOURPLATE',
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

          Column(
            children: [
              Text(
                'Registered Vehicles',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w200,
                  color: PremiumTheme.primaryTextColor,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tap any vehicle to set it as your primary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.secondaryTextColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          ..._registeredPlates.map((plate) => GestureDetector(
            onTap: () => _setPrimaryPlate(plate),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: _primaryPlate == plate
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PremiumTheme.accentColor.withOpacity(0.1),
                          PremiumTheme.accentColor.withOpacity(0.05),
                        ],
                      )
                    : null,
                color: _primaryPlate != plate ? PremiumTheme.surfaceColor : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _primaryPlate == plate
                      ? PremiumTheme.accentColor.withOpacity(0.3)
                      : PremiumTheme.dividerColor.withOpacity(0.2),
                  width: _primaryPlate == plate ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryPlate == plate
                        ? PremiumTheme.accentColor.withOpacity(0.08)
                        : Colors.black.withOpacity(0.02),
                    blurRadius: _primaryPlate == plate ? 12 : 8,
                    offset: Offset(0, _primaryPlate == plate ? 4 : 2),
                    spreadRadius: 0,
                ),
              ],
            ),
              child: Row(
                children: [
                  // Primary indicator
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryPlate == plate
                          ? PremiumTheme.accentColor.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: _primaryPlate == plate
                          ? Border.all(
                              color: PremiumTheme.accentColor.withOpacity(0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _primaryPlate == plate ? Icons.star : Icons.star_border,
                          color: _primaryPlate == plate
                              ? PremiumTheme.accentColor
                              : PremiumTheme.tertiaryTextColor,
                          size: 16,
                        ),
                        if (_primaryPlate == plate) ...[
                          SizedBox(width: 4),
                          Text(
                            'PRIMARY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: PremiumTheme.accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plate,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _primaryPlate == plate ? FontWeight.w600 : FontWeight.w400,
                            color: PremiumTheme.primaryTextColor,
                            letterSpacing: 2.0,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (_primaryPlate != plate)
                          Text(
                            'Tap to set as primary',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: PremiumTheme.tertiaryTextColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                // Delete button
                GestureDetector(
                  onTap: () => _confirmDeletePlate(plate),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
                ],
              ),
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
