import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/premium_theme.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/ath_movil_service.dart';
import '../../config/payment_config.dart';
import 'ath_payment_dialog.dart';

/// Full screen upgrade/purchase UI
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final AthMovilService _athMovilService = AthMovilService();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  bool _isLoading = false;
  String? _selectedPlan; // 'monthly' or 'lifetime'
  String _paymentMethod = 'google_play'; // 'google_play' or 'ath_movil'
  String _athInputMethod = 'phone'; // 'phone' or 'qr'
  String? _phoneError;

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  /// Open Terms of Service URL
  Future<void> _openTermsOfService() async {
    final uri = Uri.parse(PaymentConfig.termsOfServiceUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Terms of Service')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to open Terms URL: $e');
      }
    }
  }

  /// Open Privacy Policy URL
  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(PaymentConfig.privacyPolicyUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Privacy Policy')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to open Privacy URL: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: PremiumTheme.secondaryTextColor,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: PremiumTheme.surfaceColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : _restorePurchases,
                    child: Text(
                      'Restore',
                      style: TextStyle(
                        color: PremiumTheme.accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  children: [
                    // Hero icon
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: PremiumTheme.heroGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: PremiumTheme.accentColor.withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    Text(
                      'Go Premium',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: PremiumTheme.primaryTextColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock unlimited alerts and support the app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: PremiumTheme.secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Benefits
                    _buildBenefitsSection(),
                    const SizedBox(height: 24),
                    // Payment method toggle
                    _buildPaymentMethodToggle(),
                    // ATH Móvil input section (phone or QR)
                    if (_paymentMethod == 'ath_movil') ...[
                      const SizedBox(height: 16),
                      _buildAthInputTabs(),
                      const SizedBox(height: 12),
                      if (_athInputMethod == 'phone')
                        _buildPhoneInput()
                      else
                        _buildQrCodeSection(),
                    ],
                    const SizedBox(height: 24),
                    // Pricing cards
                    _buildPricingCards(),
                    const SizedBox(height: 24),
                    // Purchase button
                    _buildPurchaseButton(),
                    const SizedBox(height: 16),
                    // Terms
                    _buildTermsText(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = [
      (Icons.all_inclusive_rounded, 'Unlimited Alerts', 'Send as many alerts as you need'),
      (Icons.flash_on_rounded, 'No Daily Limits', 'Alert anytime, day or night'),
      (Icons.favorite_rounded, 'Support Development', 'Help us improve the app'),
      (Icons.star_rounded, 'Priority Features', 'Early access to new features'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: PremiumTheme.largeRadius,
        border: Border.all(
          color: PremiumTheme.dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        children: benefits.map((benefit) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PremiumTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    benefit.$1,
                    color: PremiumTheme.accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        benefit.$2,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: PremiumTheme.primaryTextColor,
                        ),
                      ),
                      Text(
                        benefit.$3,
                        style: TextStyle(
                          fontSize: 13,
                          color: PremiumTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade400,
                  size: 20,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentMethodToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PremiumTheme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPaymentMethodButton(
              id: 'google_play',
              icon: Icons.play_arrow_rounded,
              label: 'Google Play',
            ),
          ),
          Expanded(
            child: _buildPaymentMethodButton(
              id: 'ath_movil',
              icon: Icons.account_balance_wallet_rounded,
              label: 'ATH Móvil',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodButton({
    required String id,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _paymentMethod == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _paymentMethod = id;
          _phoneError = null;
        });
      },
      child: AnimatedContainer(
        duration: PremiumTheme.fastDuration,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? PremiumTheme.accentColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : PremiumTheme.secondaryTextColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : PremiumTheme.secondaryTextColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAthInputTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PremiumTheme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _athInputMethod = 'phone'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _athInputMethod == 'phone'
                      ? PremiumTheme.accentColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_rounded,
                      size: 16,
                      color: _athInputMethod == 'phone'
                          ? PremiumTheme.accentColor
                          : PremiumTheme.secondaryTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Phone',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _athInputMethod == 'phone'
                            ? PremiumTheme.accentColor
                            : PremiumTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _athInputMethod = 'qr'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _athInputMethod == 'qr'
                      ? PremiumTheme.accentColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_rounded,
                      size: 16,
                      color: _athInputMethod == 'qr'
                          ? PremiumTheme.accentColor
                          : PremiumTheme.secondaryTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'QR Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _athInputMethod == 'qr'
                            ? PremiumTheme.accentColor
                            : PremiumTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeSection() {
    final amount = _selectedPlan == 'lifetime'
        ? PaymentConfig.athLifetimePrice
        : PaymentConfig.athMonthlyPrice;
    final planName = _selectedPlan == 'lifetime' ? 'Lifetime' : 'Monthly';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PremiumTheme.dividerColor),
      ),
      child: Column(
        children: [
          // QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: 'athmovil://business/dezetingz',
              version: QrVersions.auto,
              size: 160,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFFE31837),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Instructions
          Text(
            'Scan with ATH Móvil',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Or search "/dezetingz" in the app',
            style: TextStyle(
              fontSize: 13,
              color: PremiumTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),

          // Amount reminder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE31837).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFFE31837),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pay exactly \$${amount.toStringAsFixed(2)} for $planName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE31837),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Phone input for verification
          Text(
            'After paying, enter your ATH phone to verify:',
            style: TextStyle(
              fontSize: 12,
              color: PremiumTheme.tertiaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: PremiumTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PremiumTheme.dividerColor),
            ),
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(
                fontSize: 15,
                color: PremiumTheme.primaryTextColor,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
                _PhoneNumberFormatter(),
              ],
              decoration: InputDecoration(
                hintText: 'Your ATH phone number',
                hintStyle: TextStyle(
                  color: PremiumTheme.tertiaryTextColor,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.phone_rounded,
                  size: 20,
                  color: PremiumTheme.secondaryTextColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _phoneError != null
                  ? Colors.red.shade400
                  : PremiumTheme.dividerColor,
            ),
          ),
          child: TextField(
            controller: _phoneController,
            focusNode: _phoneFocusNode,
            keyboardType: TextInputType.phone,
            style: TextStyle(
              fontSize: 16,
              color: PremiumTheme.primaryTextColor,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
              _PhoneNumberFormatter(),
            ],
            decoration: InputDecoration(
              hintText: 'Enter your ATH phone number',
              hintStyle: TextStyle(
                color: PremiumTheme.tertiaryTextColor,
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.phone_android_rounded,
                color: PremiumTheme.secondaryTextColor,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (value) {
              if (_phoneError != null) {
                setState(() => _phoneError = null);
              }
            },
          ),
        ),
        if (_phoneError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _phoneError!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade400,
              ),
            ),
          ),
        // Helper tip about ATH path
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 14,
                color: PremiumTheme.tertiaryTextColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Or search "/dezetingz" in ATH Móvil',
                  style: TextStyle(
                    fontSize: 12,
                    color: PremiumTheme.tertiaryTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingCards() {
    return Row(
      children: [
        // Monthly plan
        Expanded(
          child: _buildPlanCard(
            planId: 'monthly',
            title: 'Monthly',
            price: '\$2.99',
            period: '/month',
            isPopular: false,
          ),
        ),
        const SizedBox(width: 12),
        // Lifetime plan
        Expanded(
          child: _buildPlanCard(
            planId: 'lifetime',
            title: 'Lifetime',
            price: '\$19.99',
            period: 'one-time',
            isPopular: true,
            badge: 'Best Value',
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String planId,
    required String title,
    required String price,
    required String period,
    bool isPopular = false,
    String? badge,
  }) {
    final isSelected = _selectedPlan == planId;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planId),
      child: AnimatedContainer(
        duration: PremiumTheme.fastDuration,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? PremiumTheme.accentColor.withValues(alpha: 0.08)
              : PremiumTheme.surfaceColor,
          borderRadius: PremiumTheme.mediumRadius,
          border: Border.all(
            color: isSelected
                ? PremiumTheme.accentColor
                : PremiumTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PremiumTheme.accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 22),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PremiumTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: PremiumTheme.primaryTextColor,
              ),
            ),
            Text(
              period,
              style: TextStyle(
                fontSize: 12,
                color: PremiumTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            // Selection indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? PremiumTheme.accentColor
                      : PremiumTheme.dividerColor,
                  width: 2,
                ),
                color: isSelected ? PremiumTheme.accentColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _selectedPlan == null || _isLoading ? null : _purchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: PremiumTheme.accentColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: PremiumTheme.accentColor.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _selectedPlan == null
                    ? 'Select a Plan'
                    : _selectedPlan == 'monthly'
                        ? 'Subscribe for \$2.99/month'
                        : 'Get Lifetime Access - \$19.99',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildTermsText() {
    return Column(
      children: [
        Text(
          'Subscriptions auto-renew unless cancelled.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: PremiumTheme.tertiaryTextColor,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _openTermsOfService,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Terms',
                style: TextStyle(
                  fontSize: 11,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
            ),
            Text(
              '|',
              style: TextStyle(
                fontSize: 11,
                color: PremiumTheme.tertiaryTextColor,
              ),
            ),
            TextButton(
              onPressed: _openPrivacyPolicy,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Privacy',
                style: TextStyle(
                  fontSize: 11,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _purchase() async {
    if (_selectedPlan == null) return;

    // Route to appropriate payment method
    if (_paymentMethod == 'ath_movil') {
      await _purchaseWithAthMovil();
    } else {
      await _purchaseWithGooglePlay();
    }
  }

  Future<void> _purchaseWithGooglePlay() async {
    setState(() => _isLoading = true);

    try {
      PurchaseResult result;
      if (_selectedPlan == 'monthly') {
        result = await _subscriptionService.purchaseMonthly();
      } else {
        result = await _subscriptionService.purchaseLifetime();
      }

      if (!mounted) return;

      if (result.success) {
        _showSuccessDialog();
      } else {
        _showErrorSnackbar(result.error ?? 'Purchase failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Purchase error: $e');
      }
      if (mounted) {
        _showErrorSnackbar('An error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _purchaseWithAthMovil() async {
    // Validate phone number
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final validPhone = _athMovilService.validatePhoneNumber(phone);

    if (validPhone == null) {
      setState(() {
        _phoneError = 'Enter a valid 10-digit phone number';
      });
      _phoneFocusNode.requestFocus();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get user ID
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _showErrorSnackbar('Please sign in to continue');
        return;
      }

      // Determine product type
      final productType = _selectedPlan == 'lifetime'
          ? AthProductType.lifetime
          : AthProductType.monthly;

      // Create payment
      final result = await _athMovilService.createPayment(
        userId: userId,
        productType: productType,
        phoneNumber: validPhone,
      );

      if (!mounted) return;

      if (!result.success) {
        _showErrorSnackbar(result.error ?? 'Failed to create payment');
        return;
      }

      // Show payment dialog
      final paymentResult = await AthPaymentDialog.show(
        context: context,
        transactionId: result.transactionId!,
        amount: result.amount!,
        productType: productType,
      );

      if (!mounted) return;

      if (paymentResult == true) {
        // Payment successful - refresh subscription status
        await _subscriptionService.refreshEntitlements(force: true);
        _showSuccessDialog();
      }
    } catch (e) {
      if (kDebugMode) {
        print('ATH Móvil purchase error: $e');
      }
      if (mounted) {
        _showErrorSnackbar('An error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    try {
      final result = await _subscriptionService.restorePurchases();

      if (!mounted) return;

      if (result.success) {
        _showSuccessDialog(isRestore: true);
      } else {
        _showErrorSnackbar(result.error ?? 'No purchases to restore');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to restore purchases');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog({bool isRestore = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: PremiumTheme.surfaceColor,
            borderRadius: PremiumTheme.extraLargeRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isRestore ? 'Restored!' : 'Welcome to Premium!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isRestore
                    ? 'Your premium access has been restored.'
                    : 'You now have unlimited alerts!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Close upgrade screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
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
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// Phone number formatter for Puerto Rico numbers (787-XXX-XXXX)
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Just return digits as-is for the internal value
    // The display formatting is handled by the hint
    if (text.isEmpty) {
      return newValue;
    }

    // Format as XXX-XXX-XXXX for display
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write('-');
      }
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
