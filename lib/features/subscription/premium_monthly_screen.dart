import 'package:flutter/material.dart';

/// App Store-compliant Premium Monthly subscription screen.
/// Designed for App Store Connect screenshot submission.
class PremiumMonthlyScreen extends StatelessWidget {
  const PremiumMonthlyScreen({super.key});

  // Brand colors - teal + coral palette
  static const Color _teal = Color(0xFF0B6E7D);
  static const Color _tealLight = Color(0xFF0D8A9C);
  static const Color _coral = Color(0xFFFF6B6B);
  static const Color _coralDark = Color(0xFFE85555);
  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _background = Colors.white;

  void _onSubscribePressed() {
    print('Subscribe button pressed - wire up RevenueCat purchase here');
  }

  void _onRestorePressed() {
    print('Restore purchases pressed - wire up RevenueCat restore here');
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: _textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPadding + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo placeholder area
              _buildLogoArea(),
              const SizedBox(height: 32),

              // Title
              Text(
                'Premium Monthly',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _teal,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Unlock all Yuh Blockin\' premium features.',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: _textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Benefits list
              _buildBenefitsList(),
              const SizedBox(height: 48),

              // Subscribe button
              _buildSubscribeButton(),
              const SizedBox(height: 16),

              // Restore purchases
              _buildRestoreButton(),
              const SizedBox(height: 24),

              // Legal disclaimer
              _buildDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoArea() {
    // Placeholder for logo overlay - shows app name as text
    return Column(
      children: [
        // Space for logo (you can overlay your actual logo here)
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              'YB',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: _teal,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Yuh Blockin\'',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: _teal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Move with respect.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      (Icons.directions_car_rounded, 'Multi-vehicle plate management'),
      (Icons.notifications_active_rounded, 'Priority notifications and alerts'),
      (Icons.shield_rounded, 'Enhanced privacy and control'),
      (Icons.auto_awesome_rounded, 'Early access to new features'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _teal.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: benefits.map((benefit) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    benefit.$1,
                    color: _teal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    benefit.$2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.check_circle_rounded,
                  color: _tealLight,
                  size: 22,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubscribeButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _onSubscribePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _coral,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Subscribe – Premium Monthly',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: _onRestorePressed,
      style: TextButton.styleFrom(
        foregroundColor: _teal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: const Text(
        'Restore Purchases',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Subscription will be charged to your Apple ID account and will automatically renew unless cancelled at least 24 hours before the end of the current period.',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: _textSecondary,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// =============================================================
// HOW TO NAVIGATE TO THIS SCREEN
// =============================================================
//
// From any widget, use:
//
// Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (context) => const PremiumMonthlyScreen(),
//   ),
// );
//
// Or as a modal (recommended for paywalls):
//
// Navigator.push(
//   context,
//   MaterialPageRoute(
//     fullscreenDialog: true,
//     builder: (context) => const PremiumMonthlyScreen(),
//   ),
// );
// =============================================================
