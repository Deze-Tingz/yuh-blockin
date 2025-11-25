import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Native splash removed - using custom AppInitializer splash

import '../../core/theme/premium_theme.dart';
import '../../config/premium_config.dart';
import '../plate_registration/plate_registration_screen.dart';
import '../../main_premium.dart';

/// Compact Onboarding Flow - No Scrolling Required
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late PageController _pageController;
  int _currentPage = 0;
  final int _totalPages = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _currentPage++;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      HapticFeedback.lightImpact();
    }
  }

  void _skipToMainApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PremiumHomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(opacity: curvedAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
    } catch (e) {
      debugPrint('Failed to save onboarding state: $e');
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PlateRegistrationScreen(isOnboarding: true),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );
            return FadeTransition(opacity: curvedAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  HapticFeedback.selectionClick();
                },
                children: [
                  const _WelcomePage(),
                  const _SecurityPage(),
                  _ReadyPage(onComplete: _completeOnboarding, onSkip: _skipToMainApp),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Fixed-width indicator container for consistent alignment
          Row(
            children: List.generate(_totalPages, (index) {
              final isActive = index <= _currentPage;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: isActive ? PremiumTheme.accentColor : PremiumTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          // Placeholder to maintain consistent layout when Skip is hidden
          if (_currentPage < _totalPages - 1)
            GestureDetector(
              onTap: _skipToMainApp,
              child: Text(
                'Skip',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: PremiumTheme.secondaryTextColor,
                ),
              ),
            )
          else
            const SizedBox(width: 32), // Maintains spacing when Skip is hidden
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentPage > 0 && _currentPage < _totalPages - 1)
            const SizedBox(width: 12),
          if (_currentPage < _totalPages - 1)
            Expanded(
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_currentPage == 0 ? 'Get Started' : 'Continue'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Page 1: Welcome
class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Image.asset(
            'assets/images/app_icon.png',
            width: 220,
            height: 220,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          Text(
            'The respectful way to solve parking conflicts',
            style: TextStyle(
              fontSize: 16,
              color: PremiumTheme.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _CompactFeature(Icons.security_rounded, 'Privacy-First', 'Your data is encrypted'),
          const SizedBox(height: 12),
          _CompactFeature(Icons.people_rounded, 'Respectful', 'Polite notifications only'),
          const SizedBox(height: 12),
          _CompactFeature(Icons.bolt_rounded, 'Quick', 'Most cars move in 5 min'),
        ],
      ),
    );
  }
}

/// Page 2: Security & Privacy Combined
class _SecurityPage extends StatelessWidget {
  const _SecurityPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, size: 35, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            'Your Privacy Protected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _SecurityItem(Icons.enhanced_encryption, 'Military-grade encryption'),
                const SizedBox(height: 10),
                _SecurityItem(Icons.visibility_off, 'We never see your plate number'),
                const SizedBox(height: 10),
                _SecurityItem(Icons.person_off, 'No personal info required'),
                const SizedBox(height: 10),
                _SecurityItem(Icons.phone_android, 'Data stays on your device'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your plate is converted to a secure hash that even we cannot reverse.',
            style: TextStyle(
              fontSize: 13,
              color: PremiumTheme.secondaryTextColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Page 3: Ready to Start
class _ReadyPage extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const _ReadyPage({required this.onComplete, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 45, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            'You\'re All Set!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Register your license plate to receive alerts when someone needs you to move your car.',
            style: TextStyle(
              fontSize: 15,
              color: PremiumTheme.secondaryTextColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Register License Plate',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSkip,
            child: Text(
              'Skip for now',
              style: TextStyle(color: PremiumTheme.secondaryTextColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact feature row
class _CompactFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CompactFeature(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: PremiumTheme.accentColor),
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
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: PremiumTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Security item row
class _SecurityItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SecurityItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: PremiumTheme.primaryTextColor,
            ),
          ),
        ),
      ],
    );
  }
}
