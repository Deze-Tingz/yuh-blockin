import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/premium_theme.dart';
import '../../core/services/plate_storage_service.dart';
import '../../core/services/simple_alert_service.dart';
import '../../core/services/plate_verification_service.dart';
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

class _PlateRegistrationScreenState extends State<PlateRegistrationScreen> {
  final TextEditingController _plateInputController = TextEditingController();
  final FocusNode _plateFocusNode = FocusNode();

  final PlateStorageService _storageService = PlateStorageService();
  final SimpleAlertService _alertService = SimpleAlertService();
  final PlateVerificationService _verificationService = PlateVerificationService();

  List<String> _registeredPlates = [];
  String? _primaryPlate;
  bool _isValidPlate = false;
  bool _isRegistering = false;

  bool get _isAtMaxCapacity => _registeredPlates.length >= PlateStorageService.maxVehicles;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadExistingPlates();
  }

  Future<void> _initializeServices() async {
    try {
      await _alertService.initialize();
      if (kDebugMode) {
        debugPrint('✅ Simple alert service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to initialize secure service: $e');
      }
    }
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
        debugPrint('✅ Loaded ${plates.length} registered plates from local storage');
        debugPrint('✅ Primary plate: ${primaryPlate ?? "none set"}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to load existing plates: $e');
      }
    }
  }

  Future<void> _setPrimaryPlate(String plate) async {
    try {
      await _storageService.setPrimaryPlate(plate);
      setState(() {
        _primaryPlate = plate;
      });

      debugPrint('✅ Set $plate as primary vehicle');

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
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error setting primary plate: $e');
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

    debugPrint('Validating plate "$value" -> "$normalizedPlate"');
    debugPrint('Length valid: $lengthValid (${normalizedPlate.length})');
    debugPrint('Format valid: $formatValid');
    debugPrint('Has alphanumeric: $hasAlphaNumeric');
    debugPrint('Not duplicate: $notDuplicate');
    debugPrint('Overall valid: $isValid');

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
        debugPrint('🔐 Registering plate with multi-user privacy protection: $plateNumber');
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
          debugPrint('🔍 Found existing userId in prefs: $userId');
          debugPrint('🔍 Verifying user exists in database...');
        }

        bool userExistsInDB = await _alertService.userExists(userId);
        if (!userExistsInDB) {
          if (kDebugMode) {
            debugPrint('⚠️ User ID exists in prefs but NOT in database! Need to create user.');
          }
          needsNewUser = true;
        } else {
          if (kDebugMode) {
            debugPrint('✅ User verified to exist in database: $userId');
          }
        }
      }

      if (needsNewUser) {
        try {
          // Create new user profile
          if (kDebugMode) {
            debugPrint('🔍 Creating new user...');
          }
          userId = await _alertService.getOrCreateUser();
          await prefs.setString('user_id', userId);
          if (kDebugMode) {
            debugPrint('🆕 Created new user: $userId');
          }

          // Small delay to ensure user creation is fully committed before plate registration
          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Failed to create user: $e');
          }
          setState(() => _isRegistering = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create user profile. Please check your internet connection and try again.'),
              backgroundColor: Colors.red,
              duration: const Duration(milliseconds: 800),
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

      // Generate ownership key for security
      final ownershipKey = _verificationService.generateOwnershipKey();

      // Save key locally
      await _verificationService.saveKeyLocally(
        plateNumber: plateNumber,
        ownershipKey: ownershipKey,
      );

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
          debugPrint('🔧 ONBOARDING FIX: Added plate $plateNumber to list');
        }
      }

      // Auto-set as primary if it's the first vehicle
      if (_primaryPlate == null || _registeredPlates.length == 1) {
        await _setPrimaryPlate(plateNumber);
        if (kDebugMode) {
          debugPrint('✅ Auto-set $plateNumber as primary (first vehicle)');
        }
      }

      setState(() {
        _plateInputController.clear();
        _isValidPlate = false;
      });

      // Show ownership key dialog - user must acknowledge before continuing
      if (mounted) {
        await _showOwnershipKeyDialog(plateNumber, ownershipKey);
      }

    } on PlateAlreadyRegisteredException catch (e) {
      // Plate belongs to another user
      if (kDebugMode) {
        debugPrint('❌ Plate already registered: $e');
      }
      _showDuplicatePlateError();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Multi-user registration failed: $e');
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

  /// Show ownership key dialog - CRITICAL for security
  /// User must save this key to prove ownership if disputed
  Future<void> _showOwnershipKeyDialog(String plateNumber, String ownershipKey) async {
    bool hasCopied = false;

    await showDialog(
      context: context,
      barrierDismissible: false, // Must acknowledge
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: PremiumTheme.accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: PremiumTheme.accentColor.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon
                  Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade600,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  'Plate Registered!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: PremiumTheme.primaryTextColor,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  plateNumber,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.accentColor,

                  ),
                ),

                const SizedBox(height: 20),

                // Security key section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PremiumTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.key_rounded,
                            color: Colors.amber.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Ownership Key',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // The key itself
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: PremiumTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: PremiumTheme.dividerColor,
                          ),
                        ),
                        child: SelectableText(
                          ownershipKey,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: PremiumTheme.primaryTextColor,

                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Copy button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _verificationService.copyKeyToClipboard(ownershipKey);
                            HapticFeedback.mediumImpact();
                            setDialogState(() => hasCopied = true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Key copied to clipboard!'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            hasCopied ? Icons.check : Icons.copy_rounded,
                            size: 18,
                          ),
                          label: Text(hasCopied ? 'Copied!' : 'Copy Key'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasCopied
                                ? Colors.green
                                : PremiumTheme.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Warning text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade400,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Save this key securely! It\'s the only way to prove you own this plate. Like a crypto key - if you lose it, you lose ownership.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade300,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Dismiss keyboard first
                      FocusScope.of(context).unfocus();
                      Navigator.of(context).pop();
                      _showSuccessAnimation();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'I\'ve Saved My Key',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    // Dismiss keyboard before showing animation
    FocusScope.of(context).unfocus();
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismiss during animation
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => _SuccessAnimation(
        onComplete: () {
          Navigator.of(dialogContext).pop(); // Close the dialog
          if (widget.isOnboarding && _registeredPlates.isNotEmpty) {
            // Complete onboarding and go to main app
            _completeOnboarding();
          } else if (!widget.isOnboarding && mounted) {
            // For non-onboarding mode, go back to previous screen
            Navigator.of(context).pop();
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
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show dialog to recover a plate using secret ownership key
  Future<void> _showRecoverPlateDialog(bool isTablet) async {
    final plateController = TextEditingController();
    final keyController = TextEditingController();
    bool isRecovering = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: PremiumTheme.surfaceColor,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PremiumTheme.accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.key_rounded,
                      color: PremiumTheme.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recover Plate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.primaryTextColor,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your plate number and the secret ownership key you saved when registering.',
                      style: TextStyle(
                        fontSize: 14,
                        color: PremiumTheme.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Plate number input
                    Text(
                      'License Plate',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PremiumTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: plateController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PremiumTheme.primaryTextColor,

                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g., ABC-1234',
                        hintStyle: TextStyle(
                          color: PremiumTheme.tertiaryTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                        filled: true,
                        fillColor: PremiumTheme.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Secret key input
                    Text(
                      'Secret Ownership Key',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PremiumTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: keyController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        color: PremiumTheme.primaryTextColor,

                      ),
                      decoration: InputDecoration(
                        hintText: 'YB-XXXX-XXXX-XXXX',
                        hintStyle: TextStyle(
                          color: PremiumTheme.tertiaryTextColor,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'monospace',
                        ),
                        filled: true,
                        fillColor: PremiumTheme.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isRecovering ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: PremiumTheme.tertiaryTextColor,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isRecovering ? null : () async {
                    final plateNumber = plateController.text.trim();
                    final ownershipKey = keyController.text.trim();

                    if (plateNumber.isEmpty || ownershipKey.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter both plate number and key'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Get current user ID
                    final prefs = await SharedPreferences.getInstance();
                    final userId = prefs.getString('user_id');
                    if (userId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User not found. Please restart the app.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setDialogState(() => isRecovering = true);

                    try {
                      final result = await _verificationService.verifyOwnership(
                        plateNumber: plateNumber,
                        ownershipKey: ownershipKey,
                        userId: userId,
                      );

                      if (result.success) {
                        // Save to local storage
                        await _storageService.addPlate(plateNumber);
                        await _verificationService.saveKeyLocally(
                          plateNumber: plateNumber,
                          ownershipKey: ownershipKey,
                        );

                        // Reload plates
                        await _loadExistingPlates();

                        if (mounted) {
                          Navigator.of(dialogContext).pop();
                          HapticFeedback.mediumImpact();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.message ?? 'Plate recovered successfully!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        setDialogState(() => isRecovering = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.error ?? 'Recovery failed'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      setDialogState(() => isRecovering = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isRecovering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Recover',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show error dialog when plate is already registered by another user
  void _showDuplicatePlateError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: PremiumTheme.surfaceColor,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade400,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Already Registered',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This license plate is already registered by another user.',
                style: TextStyle(
                  fontSize: 15,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'If this is your vehicle, please contact support.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: PremiumTheme.accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
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
                    color: PremiumTheme.dividerColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  plate,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.primaryTextColor,

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
            debugPrint('✅ Deleted plate from database: $plate');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Failed to delete plate from database: $e');
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
            duration: const Duration(milliseconds: 800),
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
    _plateInputController.dispose();
    _plateFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;
    final isCompact = screenSize.height < 700;

    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 64.0 : 24.0,
                vertical: isCompact ? 12 : 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (isCompact ? 24 : 32),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    _buildHeader(),

                    // Compact spacing
                    SizedBox(height: isCompact ? 10 : 16),

                    // Main content
                    _buildMainContent(isTablet, isCompact),

                    // Compact spacing
                    SizedBox(height: isCompact ? 14 : 20),

                    // Registered plates list
                    if (_registeredPlates.isNotEmpty) _buildRegisteredPlates(isCompact),
                  ],
                ),
              ),
            );
          },
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
            color: PremiumTheme.accentColor.withValues(alpha: 0.4),
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
        debugPrint('✅ Onboarding marked as completed');
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
        debugPrint('❌ Failed to complete onboarding: $e');
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

  Widget _buildMainContent(bool isTablet, bool isCompact) {
    return Column(
      children: [
        // Premium hero section - static, no animations
        Container(
          padding: EdgeInsets.symmetric(
            vertical: isCompact ? 16 : 24,
            horizontal: isTablet ? 32 : 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                PremiumTheme.accentColor.withValues(alpha: 0.03),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // Static logo icon
              Container(
                width: isCompact ? 48 : 56,
                height: isCompact ? 48 : 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PremiumTheme.accentColor,
                      PremiumTheme.accentColor.withValues(alpha: 0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PremiumTheme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  size: isCompact ? 24 : 28,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: isCompact ? 12 : 16),

              // Title
              Text(
                widget.isOnboarding ? 'Vehicle Registry' : 'My Vehicles',
                style: TextStyle(
                  fontSize: isCompact ? 22 : 26,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,

                ),
              ),

              SizedBox(height: isCompact ? 6 : 10),

              // Subtle accent line
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  gradient: PremiumTheme.heroGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isCompact ? 12 : 20),

        // Static subtitle
        Text(
          'Register your license plate to receive alerts',
          style: TextStyle(
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.w400,
            color: PremiumTheme.secondaryTextColor,

          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: isCompact ? 8 : 12),

        // Recover plate link
        GestureDetector(
          onTap: () => _showRecoverPlateDialog(isTablet),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.key_rounded,
                size: 14,
                color: PremiumTheme.accentColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Recover plate with secret key',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: PremiumTheme.accentColor,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isCompact ? 16 : 20),

        // Show input or max capacity message
        if (_isAtMaxCapacity)
          _buildMaxCapacityMessage(isTablet, isCompact)
        else ...[
          // Premium plate input
          _buildUltraPremiumPlateInput(isTablet, isCompact),

          SizedBox(height: isCompact ? 20 : 28),

          // Register button
          _buildMinimalistRegisterButton(isTablet, isCompact),
        ],
      ],
    );
  }

  Widget _buildMaxCapacityMessage(bool isTablet, bool isCompact) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: isTablet ? 380 : 300,
      ),
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.garage_outlined,
            size: isCompact ? 36 : 44,
            color: Colors.amber.shade600,
          ),
          SizedBox(height: isCompact ? 10 : 14),
          Text(
            'Garage Full',
            style: TextStyle(
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: isCompact ? 6 : 8),
          Text(
            'Maximum ${PlateStorageService.maxVehicles} vehicles. Remove one to add another.',
            style: TextStyle(
              fontSize: isCompact ? 13 : 14,
              color: PremiumTheme.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUltraPremiumPlateInput(bool isTablet, bool isCompact) {
    return Column(
      children: [
        // Premium input field with enhanced styling
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: isTablet ? 380 : 300,
          ),
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isValidPlate
                  ? PremiumTheme.accentColor.withValues(alpha: 0.5)
                  : PremiumTheme.dividerColor.withValues(alpha: 0.3),
              width: _isValidPlate ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isValidPlate
                    ? PremiumTheme.accentColor.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: _isValidPlate ? 20 : 10,
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
              fontSize: isCompact ? 20 : 24,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,

            ),
            decoration: InputDecoration(
              hintText: 'ABC-1234',
              hintStyle: TextStyle(
                color: PremiumTheme.tertiaryTextColor.withValues(alpha: 0.4),
                fontWeight: FontWeight.w400,

              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isCompact ? 20 : 24,
                vertical: isCompact ? 16 : 18,
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

        // Valid indicator
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _isValidPlate
              ? Padding(
                  padding: EdgeInsets.only(top: isCompact ? 10 : 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Valid format',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMinimalistRegisterButton(bool isTablet, bool isCompact) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: isTablet ? 300 : 260,
      ),
      height: isCompact ? 48 : 52,
      child: ElevatedButton(
        onPressed: _isValidPlate && !_isRegistering ? _registerPlate : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isValidPlate
              ? PremiumTheme.accentColor
              : PremiumTheme.surfaceColor,
          foregroundColor: _isValidPlate
              ? Colors.white
              : PremiumTheme.tertiaryTextColor,
          elevation: _isValidPlate ? 4 : 0,
          shadowColor: _isValidPlate
              ? PremiumTheme.accentColor.withValues(alpha: 0.4)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
            side: BorderSide(
              color: _isValidPlate
                  ? Colors.transparent
                  : PremiumTheme.dividerColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: isCompact ? 12 : 14),
        ),
        child: _isRegistering
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isValidPlate ? 'Register Vehicle' : 'Enter plate number',
                style: TextStyle(
                  fontSize: isCompact ? 14 : 15,
                  fontWeight: FontWeight.w600,

                ),
              ),
      ),
    );
  }

  Widget _buildRegisteredPlates(bool isCompact) {
    return Column(
      children: [
        // Section header with premium styling
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    PremiumTheme.accentColor.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Your Vehicles',
                style: TextStyle(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,

                ),
              ),
            ),
            Container(
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PremiumTheme.accentColor.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),

        SizedBox(height: isCompact ? 12 : 16),

        // Vehicle list - more compact
        ..._registeredPlates.map((plate) {
          final isPrimary = _primaryPlate == plate;
          return GestureDetector(
            onTap: () => _setPrimaryPlate(plate),
            child: Container(
              margin: EdgeInsets.only(bottom: isCompact ? 8 : 10),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 14 : 16,
                vertical: isCompact ? 12 : 14,
              ),
              decoration: BoxDecoration(
                gradient: isPrimary
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PremiumTheme.accentColor.withValues(alpha: 0.12),
                          PremiumTheme.accentColor.withValues(alpha: 0.06),
                        ],
                      )
                    : null,
                color: !isPrimary ? PremiumTheme.surfaceColor : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPrimary
                      ? PremiumTheme.accentColor.withValues(alpha: 0.4)
                      : PremiumTheme.dividerColor.withValues(alpha: 0.3),
                  width: isPrimary ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPrimary
                        ? PremiumTheme.accentColor.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: isPrimary ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Star indicator
                  Icon(
                    isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isPrimary
                        ? PremiumTheme.accentColor
                        : PremiumTheme.tertiaryTextColor,
                    size: isCompact ? 18 : 20,
                  ),
                  SizedBox(width: isCompact ? 10 : 12),
                  // Plate number
                  Expanded(
                    child: Text(
                      plate,
                      style: TextStyle(
                        fontSize: isCompact ? 15 : 16,
                        fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                        color: PremiumTheme.primaryTextColor,

                      ),
                    ),
                  ),
                  // Primary badge or hint
                  if (isPrimary)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: PremiumTheme.accentColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PRIMARY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,

                        ),
                      ),
                    ),
                  SizedBox(width: isCompact ? 8 : 10),
                  // Delete button
                  GestureDetector(
                    onTap: () => _confirmDeletePlate(plate),
                    child: Container(
                      padding: EdgeInsets.all(isCompact ? 6 : 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
                        size: isCompact ? 16 : 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Premium success animation with playful sparkles and smooth checkmark
class _SuccessAnimation extends StatefulWidget {
  final VoidCallback onComplete;

  const _SuccessAnimation({required this.onComplete});

  @override
  State<_SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<_SuccessAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkController;
  late AnimationController _sparkleController;
  late AnimationController _glowController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _sparkleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Fast bouncy scale animation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Snappy checkmark draw animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOutBack),
    );

    // Sparkle burst animation
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeOut),
    );

    // Pulsing glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Sequence the animations for premium feel
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      _checkController.forward();
      _sparkleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _glowController.repeat(reverse: true);
    });

    // Complete after 1.2 seconds total
    Timer(const Duration(milliseconds: 1200), () {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    _sparkleController.dispose();
    _glowController.dispose();
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
            _checkAnimation,
            _sparkleAnimation,
            _glowAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Sparkle particles
                  ..._buildSparkles(),

                  // Main card
                  Container(
                    margin: const EdgeInsets.all(40),
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                    decoration: BoxDecoration(
                      color: PremiumTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: PremiumTheme.accentColor.withValues(alpha: 0.2 * _glowAnimation.value),
                          blurRadius: 40 * _glowAnimation.value,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated checkmark circle
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                PremiumTheme.accentColor,
                                PremiumTheme.accentColor.withValues(alpha: 0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: PremiumTheme.accentColor.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Transform.scale(
                              scale: _checkAnimation.value,
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Registered!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: PremiumTheme.primaryTextColor,

                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your vehicle is secured',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: PremiumTheme.secondaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildSparkles() {
    final sparkles = <Widget>[];
    final sparkleCount = 8;

    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i * 2 * pi / sparkleCount) - pi / 2;
      final distance = 80.0 + (i % 2 == 0 ? 20 : 0);

      sparkles.add(
        Transform.translate(
          offset: Offset(
            cos(angle) * distance * _sparkleAnimation.value,
            sin(angle) * distance * _sparkleAnimation.value,
          ),
          child: Opacity(
            opacity: (1 - _sparkleAnimation.value).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.5 + (_sparkleAnimation.value * 0.5),
              child: Container(
                width: i % 2 == 0 ? 8 : 6,
                height: i % 2 == 0 ? 8 : 6,
                decoration: BoxDecoration(
                  color: i % 3 == 0
                      ? PremiumTheme.accentColor
                      : i % 3 == 1
                          ? Colors.amber
                          : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (i % 3 == 0
                          ? PremiumTheme.accentColor
                          : i % 3 == 1
                              ? Colors.amber
                              : Colors.white).withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return sparkles;
  }
}
