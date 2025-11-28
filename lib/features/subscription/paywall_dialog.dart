import 'package:flutter/material.dart';
import '../../core/theme/premium_theme.dart';
import 'upgrade_screen.dart';

/// Paywall dialog shown when free user hits daily alert limit
class PaywallDialog extends StatelessWidget {
  final int remainingAlerts;
  final VoidCallback? onDismiss;

  const PaywallDialog({
    super.key,
    this.remainingAlerts = 0,
    this.onDismiss,
  });

  /// Show the paywall dialog
  static Future<void> show(BuildContext context, {int remainingAlerts = 0}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => PaywallDialog(remainingAlerts: remainingAlerts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: PremiumTheme.surfaceColor,
          borderRadius: PremiumTheme.extraLargeRadius,
          boxShadow: PremiumTheme.strongShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PremiumTheme.accentColor.withValues(alpha: 0.1),
                    PremiumTheme.accentColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Crown icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: PremiumTheme.heroGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: PremiumTheme.accentColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    'Daily Limit Reached',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                children: [
                  Text(
                    "You've used all 3 free alerts for today.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: PremiumTheme.secondaryTextColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Benefits list
                  _buildBenefitItem(
                    Icons.all_inclusive_rounded,
                    'Unlimited alerts',
                  ),
                  _buildBenefitItem(
                    Icons.flash_on_rounded,
                    'No daily limits',
                  ),
                  _buildBenefitItem(
                    Icons.favorite_rounded,
                    'Support the app',
                  ),
                ],
              ),
            ),
            // Pricing hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Starting at \$2.99/month or \$19.99 lifetime',
                style: TextStyle(
                  fontSize: 13,
                  color: PremiumTheme.accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  // Upgrade button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UpgradeScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PremiumTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Maybe later button
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss?.call();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: PremiumTheme.secondaryTextColor,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                    ),
                    child: const Text(
                      'Maybe Later',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: PremiumTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: PremiumTheme.accentColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: PremiumTheme.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
