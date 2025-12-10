import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS-ONLY App Store-compliant Premium Monthly subscription screen.
/// Designed for App Store Connect screenshot submission.
///
/// This screen is specifically for iOS and uses Cupertino styling.
/// On Android, this screen should not be shown - use the regular
/// UpgradeScreen instead which handles Google Play billing.
class PremiumMonthlyScreen extends StatelessWidget {
  const PremiumMonthlyScreen({super.key});

  // Brand colors - teal + coral palette
  static const Color _teal = Color(0xFF0B6E7D);
  static const Color _tealLight = Color(0xFF0D8A9C);
  static const Color _coral = Color(0xFFFF6B6B);
  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _background = CupertinoColors.systemBackground;

  /// Check if running on iOS
  static bool get isIOS => Platform.isIOS;

  void _onSubscribePressed(BuildContext context) {
    debugPrint('Subscribe button pressed - wire up RevenueCat iOS purchase here');
    // TODO: Wire up to SubscriptionService.purchaseMonthly()
  }

  void _onRestorePressed(BuildContext context) {
    debugPrint('Restore purchases pressed - wire up RevenueCat iOS restore here');
    // TODO: Wire up to SubscriptionService.restorePurchases()
  }

  @override
  Widget build(BuildContext context) {
    // Guard: Only show on iOS
    if (!Platform.isIOS) {
      return const Scaffold(
        body: Center(
          child: Text('This screen is only available on iOS'),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: _background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: _background,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.xmark,
            color: _textSecondary,
            size: 22,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo placeholder area
              _buildLogoArea(),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Premium Monthly',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _teal,
                  letterSpacing: -0.5,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              const Text(
                'Unlock all Yuh Blockin\' premium features.',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: _textSecondary,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Benefits list
              _buildBenefitsList(),
              const SizedBox(height: 48),

              // Subscribe button (iOS style)
              _buildSubscribeButton(context),
              const SizedBox(height: 16),

              // Restore purchases
              _buildRestoreButton(context),
              const SizedBox(height: 24),

              // Legal disclaimer (required by Apple)
              _buildDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoArea() {
    return Column(
      children: [
        // Placeholder for app icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              'YB',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: _teal,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Yuh Blockin\'',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: _teal,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Move with respect.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
            fontStyle: FontStyle.italic,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      (CupertinoIcons.car_detailed, 'Multi-vehicle plate management'),
      (CupertinoIcons.bell_fill, 'Priority notifications and alerts'),
      (CupertinoIcons.shield_fill, 'Enhanced privacy and control'),
      (CupertinoIcons.sparkles, 'Early access to new features'),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
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

  Widget _buildSubscribeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: _coral,
        borderRadius: BorderRadius.circular(14),
        onPressed: () => _onSubscribePressed(context),
        child: const Text(
          'Subscribe – Premium Monthly',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: CupertinoColors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      onPressed: () => _onRestorePressed(context),
      child: const Text(
        'Restore Purchases',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _teal,
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Subscription will be charged to your Apple ID account and will automatically renew unless cancelled at least 24 hours before the end of the current period.',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: _textSecondary,
          height: 1.5,
          decoration: TextDecoration.none,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// =============================================================
// iOS-ONLY SCREEN - HOW TO NAVIGATE
// =============================================================
//
// This screen should ONLY be shown on iOS devices.
// For Android, use UpgradeScreen instead.
//
// Example usage:
//
// import 'dart:io';
//
// if (Platform.isIOS) {
//   Navigator.push(
//     context,
//     CupertinoPageRoute(
//       fullscreenDialog: true,
//       builder: (context) => const PremiumMonthlyScreen(),
//     ),
//   );
// } else {
//   // Android - use regular UpgradeScreen
//   Navigator.push(
//     context,
//     MaterialPageRoute(builder: (context) => const UpgradeScreen()),
//   );
// }
// =============================================================
