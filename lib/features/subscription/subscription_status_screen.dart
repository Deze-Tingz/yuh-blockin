import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/premium_theme.dart';
import '../../core/services/subscription_service.dart';
import '../../config/payment_config.dart';
import 'upgrade_screen.dart';

/// Subscription status and management screen
class SubscriptionStatusScreen extends StatefulWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  State<SubscriptionStatusScreen> createState() => _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isRestoring = false;

  @override
  Widget build(BuildContext context) {
    final isPremium = _subscriptionService.isPremium;
    final status = _subscriptionService.subscriptionStatus;
    final remaining = _subscriptionService.remainingAlerts;
    final used = _subscriptionService.dailyAlertsUsed;

    return CupertinoPageScaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Subscription'),
        backgroundColor: PremiumTheme.backgroundColor,
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              _buildStatusCard(isPremium, status),

              const SizedBox(height: 20),

              // Usage Card (for free users)
              if (!isPremium) _buildUsageCard(used, remaining),

              if (!isPremium) const SizedBox(height: 20),

              // Actions
              _buildActionsCard(isPremium),

              const SizedBox(height: 20),

              // Help Section
              _buildHelpCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isPremium, String status) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isPremium
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PremiumTheme.accentColor,
                  PremiumTheme.accentColor.withAlpha(204),
                ],
              )
            : null,
        color: isPremium ? null : PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: isPremium
            ? null
            : Border.all(color: PremiumTheme.dividerColor),
      ),
      child: Column(
        children: [
          // Status Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isPremium
                  ? Colors.white.withAlpha(51)
                  : PremiumTheme.accentColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? CupertinoIcons.star_fill : CupertinoIcons.person,
              size: 32,
              color: isPremium ? Colors.white : PremiumTheme.accentColor,
            ),
          ),

          const SizedBox(height: 16),

          // Status Title
          Text(
            isPremium ? 'Premium Member' : 'Free Plan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isPremium ? Colors.white : PremiumTheme.primaryTextColor,
            ),
          ),

          const SizedBox(height: 8),

          // Status Description
          Text(
            _getStatusDescription(status),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isPremium
                  ? Colors.white.withAlpha(230)
                  : PremiumTheme.secondaryTextColor,
            ),
          ),

          // Plan Badge
          if (isPremium) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'LIFETIME',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,

                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageCard(int used, int remaining) {
    final limit = SubscriptionService.freeDailyAlertLimit;
    final progress = used / limit;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PremiumTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.bell_fill,
                color: PremiumTheme.accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Daily Alerts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: PremiumTheme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                remaining > 0 ? PremiumTheme.accentColor : CupertinoColors.systemRed,
              ),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$used of $limit used today',
                style: TextStyle(
                  fontSize: 14,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
              Text(
                '$remaining remaining',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: remaining > 0 ? PremiumTheme.accentColor : CupertinoColors.systemRed,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Upgrade prompt
          GestureDetector(
            onTap: _openUpgradeScreen,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PremiumTheme.accentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.rocket_fill,
                    color: PremiumTheme.accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upgrade for unlimited alerts',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: PremiumTheme.accentColor,
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.right_chevron,
                    color: PremiumTheme.accentColor,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(bool isPremium) {
    return Container(
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PremiumTheme.dividerColor),
      ),
      child: Column(
        children: [
          if (!isPremium)
            _buildActionTile(
              icon: CupertinoIcons.star_fill,
              title: 'Upgrade to Premium',
              subtitle: 'Unlock unlimited alerts',
              iconColor: CupertinoColors.systemYellow,
              onTap: _openUpgradeScreen,
            ),

          _buildActionTile(
            icon: CupertinoIcons.arrow_3_trianglepath,
            title: 'Restore Purchases',
            subtitle: 'Restore previous purchases',
            iconColor: CupertinoColors.systemBlue,
            isLoading: _isRestoring,
            onTap: _restorePurchases,
          ),

          if (isPremium)
            _buildActionTile(
              icon: CupertinoIcons.gear_alt_fill,
              title: 'Manage Subscription',
              subtitle: 'View or cancel in App Store',
              iconColor: CupertinoColors.systemGreen,
              onTap: _openAppStoreSubscriptions,
              showDivider: false,
            ),

          if (!isPremium)
            _buildActionTile(
              icon: CupertinoIcons.gear_alt_fill,
              title: 'Manage Subscription',
              subtitle: 'View in App Store',
              iconColor: CupertinoColors.systemGreen,
              onTap: _openAppStoreSubscriptions,
              showDivider: false,
            ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool isLoading = false,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: isLoading ? null : () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CupertinoActivityIndicator(),
                        )
                      : Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: PremiumTheme.primaryTextColor,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: PremiumTheme.tertiaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.right_chevron,
                  size: 16,
                  color: PremiumTheme.tertiaryTextColor,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 64,
            color: PremiumTheme.dividerColor,
          ),
      ],
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PremiumTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need Help?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildHelpLink(
            icon: CupertinoIcons.mail_solid,
            label: 'Contact Support',
            onTap: _contactSupport,
          ),
          const SizedBox(height: 8),
          _buildHelpLink(
            icon: CupertinoIcons.doc_text_fill,
            label: 'Terms of Service',
            onTap: _openTerms,
          ),
          const SizedBox(height: 8),
          _buildHelpLink(
            icon: CupertinoIcons.shield_fill,
            label: 'Privacy Policy',
            onTap: _openPrivacy,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpLink({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: PremiumTheme.secondaryTextColor,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: PremiumTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'lifetime':
        return 'You have lifetime access to all premium features. Thank you for your support!';
      case 'premium':
        return 'You have access to all premium features including unlimited alerts.';
      default:
        return 'You\'re on the free plan with ${SubscriptionService.freeDailyAlertLimit} alerts per day.';
    }
  }

  void _openUpgradeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
    );
  }

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);

    try {
      final result = await _subscriptionService.restorePurchases();

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(result.success ? 'Purchases Restored' : 'Restore Failed'),
            content: Text(result.message ?? (result.success ? 'Your purchases have been restored.' : 'No purchases found.')),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );

        if (result.success) {
          setState(() {}); // Refresh UI
        }
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Restore Failed'),
            content: const Text('Failed to restore purchases. Please try again.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  Future<void> _openAppStoreSubscriptions() async {
    // Deep link to App Store subscriptions
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Could Not Open App Store'),
            content: const Text('Please open the App Store and navigate to your subscriptions.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri.parse('mailto:${PaymentConfig.supportEmail}?subject=Yuh Blockin Support');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email: ${PaymentConfig.supportEmail}')),
        );
      }
    }
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse(PaymentConfig.termsOfServiceUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _openPrivacy() async {
    final uri = Uri.parse(PaymentConfig.privacyPolicyUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Ignore
    }
  }
}
