import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String _athPath = ''; // Loaded from Supabase
  bool _athPathLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAthPath();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAthPath() async {
    final path = await _athMovilService.getAthPath();
    if (mounted) {
      setState(() {
        _athPath = path;
        _athPathLoaded = true;
      });
    }
  }

  /// Open Terms of Service URL
  Future<void> _openTermsOfService() async {
    final uri = Uri.parse(PaymentConfig.termsOfServiceUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showErrorSnackbar('Could not open Terms of Service');
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
          _showErrorSnackbar('Could not open Privacy Policy');
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
    return CupertinoPageScaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Go Premium'),
        backgroundColor: PremiumTheme.backgroundColor,
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _restorePurchases,
          child: const Text('Restore'),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
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
                            color: PremiumTheme.accentColor.withAlpha(77),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.star_fill,
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

                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock unlimited alerts and support the app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: PremiumTheme.secondaryTextColor,
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
      (CupertinoIcons.infinite, 'Unlimited Alerts', 'Send as many alerts as you need'),
      (CupertinoIcons.time_solid, 'No Daily Limits', 'Alert anytime, day or night'),
      (CupertinoIcons.heart_fill, 'Support Development', 'Help us improve the app'),
      (CupertinoIcons.sparkles, 'Priority Features', 'Early access to new features'),
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
                    color: PremiumTheme.accentColor.withAlpha(25),
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
                  CupertinoIcons.check_mark_circled_solid,
                  color: CupertinoColors.systemGreen,
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
              icon: CupertinoIcons.device_laptop,
              label: 'Google Play',
            ),
          ),
          Expanded(
            child: _buildPaymentMethodButton(
              id: 'ath_movil',
              icon: CupertinoIcons.creditcard_fill,
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
                      ? PremiumTheme.accentColor.withAlpha(38)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.phone_fill,
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
                      ? PremiumTheme.accentColor.withAlpha(38)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.qrcode,
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
    // QR code is preset for monthly payment
    const amount = PaymentConfig.athMonthlyPrice;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PremiumTheme.dividerColor),
      ),
      child: Column(
        children: [
          // QR Code - Cropped to show only the ATH card portion
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 240,
              height: 320,
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: const Alignment(0.0, 0.15), // Center on the QR card
                child: SizedBox(
                  width: 300,
                  height: 650,
                  child: Image.asset(
                    'assets/images/yuhblockin_monthly_qrcode_ath.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Instructions
          Text(
            'Scan or screenshot this QR code',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open ATH Móvil and scan to pay \$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              color: PremiumTheme.secondaryTextColor,
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
          CupertinoTextField(
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
            placeholder: 'Your ATH phone number',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12.0),
              child: Icon(
                CupertinoIcons.phone_fill,
                size: 20,
                color: CupertinoColors.placeholderText,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoTextField(
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
          placeholder: 'Enter your ATH phone number',
          prefix: const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: Icon(
              CupertinoIcons.phone_fill,
              color: CupertinoColors.placeholderText,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          onChanged: (value) {
            if (_phoneError != null) {
              setState(() => _phoneError = null);
            }
          },
        ),
        if (_phoneError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _phoneError!,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemRed,
              ),
            ),
          ),
        // Helper tip about ATH path
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.lightbulb_fill,
                size: 14,
                color: PremiumTheme.tertiaryTextColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _athPathLoaded
                      ? 'Or search "$_athPath" in ATH Móvil'
                      : 'Or search in ATH Móvil',
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
              ? PremiumTheme.accentColor.withAlpha(20)
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
                      CupertinoIcons.check_mark,
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
      child: CupertinoButton.filled(
        onPressed: _selectedPlan == null || _isLoading ? null : _purchase,
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CupertinoActivityIndicator(color: Colors.white),
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
            CupertinoButton(
              onPressed: _openTermsOfService,
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
            CupertinoButton(
              onPressed: _openPrivacyPolicy,
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoColors.systemGreen),
            SizedBox(width: 8),
            Text(isRestore ? 'Restored!' : 'Welcome to Premium!'),
          ],
        ),
        content: Text(
          isRestore
              ? 'Your premium access has been restored.'
              : 'You now have unlimited alerts!',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Continue'),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close upgrade screen
            },
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: CupertinoColors.systemRed,
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
