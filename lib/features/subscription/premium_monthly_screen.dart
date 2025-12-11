import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/services/subscription_service.dart';

/// iOS-ONLY App Store-compliant Premium Monthly subscription screen.
/// Designed for App Store Connect screenshot submission.
///
/// This screen is specifically for iOS and uses Cupertino styling.
/// On Android, this screen should not be shown - use the regular
/// UpgradeScreen instead which handles Google Play billing.
class PremiumMonthlyScreen extends StatefulWidget {
  const PremiumMonthlyScreen({super.key});

  /// Check if running on iOS
  static bool get isIOS => Platform.isIOS;

  @override
  State<PremiumMonthlyScreen> createState() => _PremiumMonthlyScreenState();
}

class _PremiumMonthlyScreenState extends State<PremiumMonthlyScreen> {
  // Brand colors - teal + coral palette
  static const Color _teal = Color(0xFF0B6E7D);
  static const Color _tealLight = Color(0xFF0D8A9C);
  static const Color _coral = Color(0xFFFF6B6B);
  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _background = CupertinoColors.systemBackground;

  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = false;

  Future<void> _onSubscribePressed(BuildContext context) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final result = await _subscriptionService.purchaseMonthly();

      if (!mounted) return;

      if (result.success) {
        _showAlert(
          context,
          title: 'Success!',
          message: result.message ?? 'You are now a Premium member!',
          onDismiss: () => Navigator.of(context).pop(true),
        );
      } else {
        _showAlert(
          context,
          title: 'Purchase Failed',
          message: result.error ?? 'Unable to complete purchase. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onRestorePressed(BuildContext context) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final result = await _subscriptionService.restorePurchases();

      if (!mounted) return;

      if (result.success) {
        _showAlert(
          context,
          title: 'Restored!',
          message: result.message ?? 'Your purchases have been restored.',
          onDismiss: () => Navigator.of(context).pop(true),
        );
      } else {
        _showAlert(
          context,
          title: 'No Purchases Found',
          message: result.error ?? 'No previous purchases were found for this account.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAlert(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        color: _isLoading ? _coral.withValues(alpha: 0.6) : _coral,
        borderRadius: BorderRadius.circular(14),
        onPressed: _isLoading ? null : () => _onSubscribePressed(context),
        child: _isLoading
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : const Text(
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
      onPressed: _isLoading ? null : () => _onRestorePressed(context),
      child: _isLoading
          ? const CupertinoActivityIndicator()
          : const Text(
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
