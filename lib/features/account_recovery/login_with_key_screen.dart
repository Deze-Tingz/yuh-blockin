import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/premium_theme.dart';
import '../../core/services/account_recovery_service.dart';
import '../../main.dart';

/// Screen for recovering account using secret ownership key
/// Used when user changes device and needs to regain access
class LoginWithKeyScreen extends StatefulWidget {
  final bool showBackButton;

  const LoginWithKeyScreen({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<LoginWithKeyScreen> createState() => _LoginWithKeyScreenState();
}

class _LoginWithKeyScreenState extends State<LoginWithKeyScreen> {
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final FocusNode _plateFocusNode = FocusNode();
  final FocusNode _keyFocusNode = FocusNode();

  final AccountRecoveryService _recoveryService = AccountRecoveryService();

  bool _isRecovering = false;
  String? _errorMessage;
  bool _isPlateValid = false;
  bool _isKeyValid = false;

  @override
  void initState() {
    super.initState();
    _plateController.addListener(_validatePlate);
    _keyController.addListener(_validateKey);
  }

  @override
  void dispose() {
    _plateController.dispose();
    _keyController.dispose();
    _plateFocusNode.dispose();
    _keyFocusNode.dispose();
    super.dispose();
  }

  void _validatePlate() {
    final plate = _plateController.text.trim();
    setState(() {
      _isPlateValid = plate.length >= 2 && plate.length <= 12;
      _errorMessage = null;
    });
  }

  void _validateKey() {
    final key = _keyController.text.trim().toUpperCase();
    // Format: YB-XXXX-XXXX-XXXX-XXXX
    final pattern = RegExp(r'^YB-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    setState(() {
      _isKeyValid = pattern.hasMatch(key);
      _errorMessage = null;
    });
  }

  String _formatKeyInput(String input) {
    // Auto-format the key as user types
    String clean = input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    if (clean.isEmpty) return '';

    // Add YB prefix if not present
    if (!clean.startsWith('YB')) {
      if (clean.length <= 2) {
        return clean;
      }
    }

    // Format: YB-XXXX-XXXX-XXXX-XXXX
    final buffer = StringBuffer();

    // Handle YB prefix
    if (clean.startsWith('YB')) {
      buffer.write('YB');
      clean = clean.substring(2);
    } else {
      buffer.write('YB');
    }

    // Add the rest in groups of 4
    for (int i = 0; i < clean.length && i < 16; i++) {
      if (i % 4 == 0) {
        buffer.write('-');
      }
      buffer.write(clean[i]);
    }

    return buffer.toString();
  }

  Future<void> _recoverAccount() async {
    if (!_isPlateValid || !_isKeyValid || _isRecovering) return;

    setState(() {
      _isRecovering = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    try {
      final result = await _recoveryService.recoverWithSecretKey(
        plateNumber: _plateController.text.trim(),
        secretKey: _keyController.text.trim(),
      );

      if (result.success) {
        if (mounted) {
          HapticFeedback.heavyImpact();

          // Show success and navigate to home
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Account recovered successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigate to home screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PremiumHomeScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Recovery failed. Please check your details.';
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isRecovering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.height < 700;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: isCompact ? 16 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenSize.height -
                  MediaQuery.of(context).padding.top -
                  bottomPadding -
                  (isCompact ? 32 : 48),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(isCompact),

                SizedBox(height: isCompact ? 24 : 40),

                // Hero section
                _buildHeroSection(isCompact),

                SizedBox(height: isCompact ? 24 : 32),

                // Input fields
                _buildInputFields(isCompact),

                SizedBox(height: isCompact ? 20 : 28),

                // Error message
                if (_errorMessage != null) ...[
                  _buildErrorMessage(),
                  SizedBox(height: isCompact ? 16 : 20),
                ],

                // Recover button
                _buildRecoverButton(isCompact),

                SizedBox(height: isCompact ? 20 : 32),

                // Help text
                _buildHelpSection(isCompact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Row(
      children: [
        if (widget.showBackButton)
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
                size: 18,
              ),
            ),
          ),
        const Spacer(),
      ],
    );
  }

  Widget _buildHeroSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          width: isCompact ? 56 : 64,
          height: isCompact ? 56 : 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PremiumTheme.accentColor,
                PremiumTheme.accentColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: PremiumTheme.accentColor.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.key_rounded,
            color: Colors.white,
            size: isCompact ? 28 : 32,
          ),
        ),

        SizedBox(height: isCompact ? 16 : 20),

        // Title
        Text(
          'Recover Your Account',
          style: TextStyle(
            fontSize: isCompact ? 26 : 30,
            fontWeight: FontWeight.w600,
            color: PremiumTheme.primaryTextColor,
          ),
        ),

        SizedBox(height: isCompact ? 8 : 12),

        // Subtitle
        Text(
          'Enter your license plate and the secret ownership key you saved when registering.',
          style: TextStyle(
            fontSize: isCompact ? 14 : 15,
            color: PremiumTheme.secondaryTextColor,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInputFields(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Container(
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isPlateValid
                  ? PremiumTheme.accentColor.withValues(alpha: 0.5)
                  : PremiumTheme.dividerColor.withValues(alpha: 0.3),
              width: _isPlateValid ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _plateController,
            focusNode: _plateFocusNode,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., ABC-1234',
              hintStyle: TextStyle(
                color: PremiumTheme.tertiaryTextColor,
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(
                Icons.directions_car_outlined,
                color: _isPlateValid
                    ? PremiumTheme.accentColor
                    : PremiumTheme.tertiaryTextColor,
              ),
              suffixIcon: _isPlateValid
                  ? Icon(
                      Icons.check_circle,
                      color: Colors.green.shade500,
                      size: 20,
                    )
                  : null,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-\s]')),
              LengthLimitingTextInputFormatter(12),
            ],
            onSubmitted: (_) => _keyFocusNode.requestFocus(),
          ),
        ),

        SizedBox(height: isCompact ? 16 : 20),

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
        Container(
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isKeyValid
                  ? PremiumTheme.accentColor.withValues(alpha: 0.5)
                  : PremiumTheme.dividerColor.withValues(alpha: 0.3),
              width: _isKeyValid ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _keyController,
            focusNode: _keyFocusNode,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              hintText: 'YB-XXXX-XXXX-XXXX-XXXX',
              hintStyle: TextStyle(
                color: PremiumTheme.tertiaryTextColor,
                fontWeight: FontWeight.w400,
                letterSpacing: 1,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(
                Icons.key_outlined,
                color: _isKeyValid
                    ? PremiumTheme.accentColor
                    : PremiumTheme.tertiaryTextColor,
              ),
              suffixIcon: _isKeyValid
                  ? Icon(
                      Icons.check_circle,
                      color: Colors.green.shade500,
                      size: 20,
                    )
                  : null,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
              LengthLimitingTextInputFormatter(22),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final formatted = _formatKeyInput(newValue.text);
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
            ],
            onSubmitted: (_) => _recoverAccount(),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
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
            Icons.error_outline,
            color: Colors.red.shade400,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoverButton(bool isCompact) {
    final isValid = _isPlateValid && _isKeyValid;

    return SizedBox(
      width: double.infinity,
      height: isCompact ? 52 : 56,
      child: ElevatedButton(
        onPressed: isValid && !_isRecovering ? _recoverAccount : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isValid
              ? PremiumTheme.accentColor
              : PremiumTheme.surfaceColor,
          foregroundColor: isValid
              ? Colors.white
              : PremiumTheme.tertiaryTextColor,
          elevation: isValid ? 4 : 0,
          shadowColor: isValid
              ? PremiumTheme.accentColor.withValues(alpha: 0.4)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isValid
                  ? Colors.transparent
                  : PremiumTheme.dividerColor.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: _isRecovering
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'Recover Account',
                style: TextStyle(
                  fontSize: isCompact ? 15 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildHelpSection(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PremiumTheme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: PremiumTheme.accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Where\'s my secret key?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 12),
          Text(
            'Your secret key was shown when you first registered your license plate. '
            'It looks like: YB-XXXX-XXXX-XXXX-XXXX\n\n'
            'If you saved it to your clipboard, notes app, or password manager, '
            'you can find it there.',
            style: TextStyle(
              fontSize: 13,
              color: PremiumTheme.secondaryTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
