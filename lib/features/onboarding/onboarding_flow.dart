import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import '../../core/theme/premium_theme.dart';
import '../../config/premium_config.dart';
import '../plate_registration/plate_registration_screen.dart';
import '../../main_premium.dart';

/// Premium Onboarding Flow
///
/// Emphasizes security transparency while creating comfort and trust
/// Features step-by-step education about our privacy-first approach
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late AnimationController _sparkleController;

  int _currentPage = 0;
  final int _totalPages = 5;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _fadeController = AnimationController(
      duration: PremiumTheme.mediumDuration,
      vsync: this,
    );

    _sparkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeController.forward();
    _sparkleController.repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _currentPage++;
      _pageController.animateToPage(
        _currentPage,
        duration: PremiumTheme.mediumDuration,
        curve: Curves.easeOutCubic,
      );
      HapticFeedback.lightImpact();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _currentPage--;
      _pageController.animateToPage(
        _currentPage,
        duration: PremiumTheme.mediumDuration,
        curve: Curves.easeOutCubic,
      );
      HapticFeedback.lightImpact();
    }
  }

  void _skipToPlateRegistration() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const PlateRegistrationScreen(isOnboarding: true),
      ),
    );
  }

  void _completeOnboarding() {
    // After onboarding, go to license plate registration as the final setup step
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const PlateRegistrationScreen(isOnboarding: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            children: [
              // Header with skip option
              _buildHeader(),

              // Main content - wrapped in flexible to prevent overflow
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                        HapticFeedback.selectionClick();
                      },
                      children: [
                        SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: _WelcomePage(sparkleController: _sparkleController),
                          ),
                        ),
                        SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: _SecurityTransparencyPage(),
                          ),
                        ),
                        SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: _PrivacyFirstPage(),
                          ),
                        ),
                        SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: _RespectfulCommunityPage(),
                          ),
                        ),
                        SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: _ReadyToStartPage(onComplete: _completeOnboarding),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Navigation footer
              _buildNavigationFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Progress indicator
          Row(
            children: List.generate(_totalPages, (index) {
              final isActive = index <= _currentPage;
              return Container(
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 24 : 8,
                height: 4,
                decoration: BoxDecoration(
                  color: isActive
                      ? PremiumTheme.accentColor
                      : PremiumTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),

          // Skip button
          if (_currentPage < _totalPages - 1)
            GestureDetector(
              onTap: _skipToPlateRegistration,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: PremiumTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: PremiumTheme.subtleShadow,
                ),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PremiumTheme.secondaryTextColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationFooter() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          // Previous button
          if (_currentPage > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: _previousPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.surfaceColor,
                  foregroundColor: PremiumTheme.primaryTextColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: PremiumTheme.dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            const Spacer(),

          if (_currentPage > 0 && _currentPage < _totalPages - 1)
            const SizedBox(width: 16),

          // Next/Get Started button
          if (_currentPage < _totalPages - 1)
            Expanded(
              flex: _currentPage == 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentPage == 0 ? 'Get Started' : 'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Welcome page with premium branding
class _WelcomePage extends StatelessWidget {
  final AnimationController sparkleController;

  const _WelcomePage({required this.sparkleController});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 60.0 : 24.0),
      child: IntrinsicHeight(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Premium car vector icon - clean and professional
            Container(
              width: isTablet ? 120 : 100,
              height: isTablet ? 120 : 100,
              decoration: BoxDecoration(
                gradient: PremiumTheme.heroGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: PremiumTheme.accentColor.withOpacity(0.15),
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                Icons.directions_car_outlined,
                size: isTablet ? 50 : 42,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 32),

            // Enhanced welcome message with premium typography
            Column(
              children: [
                Text(
                  'Let\'s get that car',
                  style: TextStyle(
                    fontSize: isTablet ? 36 : 28,
                    fontWeight: FontWeight.w300,
                    color: PremiumTheme.primaryTextColor,
                    letterSpacing: 0.8,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'out your way!',
                  style: TextStyle(
                    fontSize: isTablet ? 40 : 32,
                    fontWeight: FontWeight.w200,
                    color: PremiumTheme.accentColor,
                    letterSpacing: 1.0,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PremiumTheme.surfaceColor,
                        PremiumTheme.surfaceColor.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: PremiumTheme.accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: PremiumTheme.accentColor.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    PremiumConfig.appName,
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.accentColor,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'The respectful way to solve parking conflicts',
                style: TextStyle(
                  fontSize: isTablet ? 24 : 18,
                  fontWeight: FontWeight.w500,
                  color: PremiumTheme.primaryTextColor,
                  height: 1.4,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Key features preview - made more compact
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PremiumTheme.surfaceColor,
                  borderRadius: PremiumTheme.largeRadius,
                  boxShadow: PremiumTheme.subtleShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FeatureRow(
                      icon: Icons.security_rounded,
                      title: 'Privacy-First Security',
                      subtitle: 'Your data is encrypted and never shared',
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.people_rounded,
                      title: 'Respectful Community',
                      subtitle: 'Building better parking etiquette together',
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.auto_fix_high_rounded,
                      title: 'Effortless Experience',
                      subtitle: 'Simple, elegant, and effective',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Security transparency page
class _SecurityTransparencyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 60.0 : 32.0),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Security icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Complete Security\nTransparency',
            style: TextStyle(
              fontSize: isTablet ? 32 : 28,
              fontWeight: FontWeight.w200,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 0.8,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          Text(
            'We believe you should know exactly how your data is protected. Here\'s our complete security approach:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: PremiumTheme.secondaryTextColor,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Security measures
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: PremiumTheme.mediumRadius,
              boxShadow: PremiumTheme.subtleShadow,
            ),
            child: Column(
              children: [
                _SecurityFeature(
                  icon: Icons.enhanced_encryption_rounded,
                  title: 'HMAC-SHA256 Encryption',
                  description: 'Your license plates are hashed with military-grade encryption before storage',
                  isComforting: true,
                ),
                const SizedBox(height: 16),
                _SecurityFeature(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Zero Raw Data Storage',
                  description: 'We never store your actual license plate number anywhere',
                  isComforting: true,
                ),
                const SizedBox(height: 16),
                _SecurityFeature(
                  icon: Icons.visibility_off_rounded,
                  title: 'Anonymous by Design',
                  description: 'No names, addresses, or personal info required',
                  isComforting: true,
                ),
                const SizedBox(height: 16),
                _SecurityFeature(
                  icon: Icons.devices_rounded,
                  title: 'Local-First Storage',
                  description: 'Your data stays on your device, encrypted in secure local storage',
                  isComforting: true,
                ),
              ],
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

/// Privacy-first approach page
class _PrivacyFirstPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 60.0 : 32.0),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Privacy shield
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.privacy_tip_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Privacy by Design\nNot by Accident',
            style: TextStyle(
              fontSize: isTablet ? 32 : 28,
              fontWeight: FontWeight.w200,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 0.8,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: PremiumTheme.mediumRadius,
              border: Border.all(
                color: Colors.blue.shade200,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.psychology_rounded,
                  size: 32,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  'How it works',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'When you enter "ABC 123", we immediately convert it to an irreversible hash like "a7b2c8d4e1f9". Only you know the original plate number.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.blue.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // What this means for you
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: PremiumTheme.mediumRadius,
              boxShadow: PremiumTheme.subtleShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What this means for you:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                _PrivacyBenefit('✅ Even we can\'t see your license plate'),
                _PrivacyBenefit('✅ No data breaches can expose your info'),
                _PrivacyBenefit('✅ Complete anonymity in the system'),
                _PrivacyBenefit('✅ You control all your data'),
              ],
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _PrivacyBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: PremiumTheme.secondaryTextColor,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Respectful community page
class _RespectfulCommunityPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 60.0 : 32.0),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Community icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Building a Respectful\nParking Community',
            style: TextStyle(
              fontSize: isTablet ? 32 : 28,
              fontWeight: FontWeight.w200,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 0.8,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          Text(
            'Together, we\'re creating a culture of mutual respect and understanding around parking.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: PremiumTheme.secondaryTextColor,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Community principles
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: PremiumTheme.mediumRadius,
              boxShadow: PremiumTheme.subtleShadow,
            ),
            child: Column(
              children: [
                _CommunityPrinciple(
                  emoji: '🤝',
                  title: 'Respectful Communication',
                  description: 'All alerts are polite and constructive',
                ),
                const SizedBox(height: 16),
                _CommunityPrinciple(
                  emoji: '⚡',
                  title: 'Quick Responses',
                  description: 'Most people move their car within 5 minutes',
                ),
                const SizedBox(height: 16),
                _CommunityPrinciple(
                  emoji: '🌟',
                  title: 'Positive Reputation',
                  description: 'Build your community standing through helpfulness',
                ),
                const SizedBox(height: 16),
                _CommunityPrinciple(
                  emoji: '🛡️',
                  title: 'Zero Tolerance for Harassment',
                  description: 'Automated systems prevent abuse',
                ),
              ],
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

/// Ready to start page
class _ReadyToStartPage extends StatelessWidget {
  final VoidCallback onComplete;

  const _ReadyToStartPage({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 60.0 : 32.0),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Success checkmark
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'You\'re All Set!',
            style: TextStyle(
              fontSize: isTablet ? 36 : 32,
              fontWeight: FontWeight.w200,
              color: PremiumTheme.primaryTextColor,
              letterSpacing: 0.8,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          Text(
            'You now understand how ${PremiumConfig.appName} protects your privacy while fostering respectful parking solutions.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: PremiumTheme.secondaryTextColor,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Quick start actions
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: PremiumTheme.largeRadius,
              boxShadow: PremiumTheme.subtleShadow,
            ),
            child: Column(
              children: [
                Text(
                  'Ready to start?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 20),

                // Register plates button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const PlateRegistrationScreen(isOnboarding: true),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Register Your License Plates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Skip to main app
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onComplete,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Skip for now, go to main app',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: PremiumTheme.secondaryTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// Helper widgets

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PremiumTheme.accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: PremiumTheme.accentColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecurityFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isComforting;

  const _SecurityFeature({
    required this.icon,
    required this.title,
    required this.description,
    this.isComforting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isComforting
                ? Colors.green.withOpacity(0.1)
                : PremiumTheme.accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isComforting ? Colors.green : PremiumTheme.accentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.secondaryTextColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityPrinciple extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;

  const _CommunityPrinciple({
    required this.emoji,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: PremiumTheme.backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: PremiumTheme.secondaryTextColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Simple, clean car painter - much better than the overly complex version
class _PremiumCarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Clean car body
    final bodyPaint = Paint()
      ..color = PremiumTheme.accentColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = PremiumTheme.accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Simple car silhouette
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.1,
        size.height * 0.3,
        size.width * 0.8,
        size.height * 0.4,
      ),
      Radius.circular(size.height * 0.1),
    );

    // Draw car body
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, strokePaint);

    // Simple wheels
    final wheelPaint = Paint()
      ..color = PremiumTheme.accentColor
      ..style = PaintingStyle.fill;

    final wheelRadius = size.height * 0.12;

    // Left wheel
    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.8),
      wheelRadius,
      wheelPaint,
    );

    // Right wheel
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.8),
      wheelRadius,
      wheelPaint,
    );

    // Simple windows
    final windowPaint = Paint()
      ..color = PremiumTheme.accentColor.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.2,
        size.height * 0.35,
        size.width * 0.6,
        size.height * 0.25,
      ),
      Radius.circular(size.height * 0.05),
    );

    canvas.drawRRect(windowRect, windowPaint);
  }


  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Motion lines painter for playful movement effect
class _MotionLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Three motion lines of varying lengths
    canvas.drawLine(
      Offset(0, size.height * 0.2),
      Offset(size.width * 0.6, size.height * 0.2),
      paint,
    );

    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width * 0.8, size.height * 0.5),
      paint,
    );

    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.7, size.height * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}