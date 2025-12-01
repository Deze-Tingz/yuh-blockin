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

    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: PremiumTheme.backgroundColor,
        foregroundColor: PremiumTheme.primaryTextColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
                  PremiumTheme.accentColor.withValues(alpha: 0.8),
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
                  ? Colors.white.withValues(alpha: 0.2)
                  : PremiumTheme.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.workspace_premium : Icons.person_outline,
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
                  ? Colors.white.withValues(alpha: 0.9)
                  : PremiumTheme.secondaryTextColor,
            ),
          ),

          // Plan Badge
          if (isPremium) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status == 'lifetime' ? 'LIFETIME' : 'MONTHLY',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
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
                Icons.notifications_active_outlined,
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
                remaining > 0 ? PremiumTheme.accentColor : Colors.red,
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
                  color: remaining > 0 ? PremiumTheme.accentColor : Colors.red,
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
                color: PremiumTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rocket_launch,
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
                    Icons.arrow_forward_ios,
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
              icon: Icons.workspace_premium,
              title: 'Upgrade to Premium',
              subtitle: 'Unlock unlimited alerts',
              iconColor: Colors.amber,
              onTap: _openUpgradeScreen,
            ),

          _buildActionTile(
            icon: Icons.restore,
            title: 'Restore Purchases',
            subtitle: 'Restore previous purchases',
            iconColor: Colors.blue,
            isLoading: _isRestoring,
            onTap: _restorePurchases,
          ),

          if (isPremium)
            _buildActionTile(
              icon: Icons.manage_accounts,
              title: 'Manage Subscription',
              subtitle: 'View or cancel in Play Store',
              iconColor: Colors.green,
              onTap: _openPlayStoreSubscriptions,
              showDivider: false,
            ),

          if (!isPremium)
            _buildActionTile(
              icon: Icons.manage_accounts,
              title: 'Manage Subscription',
              subtitle: 'View in Play Store',
              iconColor: Colors.green,
              onTap: _openPlayStoreSubscriptions,
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
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: PremiumTheme.tertiaryTextColor,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: PremiumTheme.tertiaryTextColor,
          ),
          onTap: isLoading ? null : () {
            HapticFeedback.lightImpact();
            onTap();
          },
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
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
            icon: Icons.email_outlined,
            label: 'Contact Support',
            onTap: _contactSupport,
          ),
          const SizedBox(height: 8),
          _buildHelpLink(
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            onTap: _openTerms,
          ),
          const SizedBox(height: 8),
          _buildHelpLink(
            icon: Icons.privacy_tip_outlined,
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
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? result.message ?? 'Purchases restored!'
                  : result.error ?? 'No purchases found',
            ),
            backgroundColor: result.success ? Colors.green : Colors.orange,
          ),
        );

        if (result.success) {
          setState(() {}); // Refresh UI
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to restore purchases'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  Future<void> _openPlayStoreSubscriptions() async {
    // Deep link to Play Store subscriptions
    final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Play Store')),
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
