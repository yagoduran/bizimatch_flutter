import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const String _seenOnboardingKey = 'seen_onboarding';

  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.favorite_rounded,
      title: 'Haz Match',
      subtitle: 'Encuentra personas compatibles antes de compartir piso.',
    ),
    _OnboardingPageData(
      icon: Icons.verified_user_rounded,
      title: 'Firma Contratos Seguros',
      subtitle: 'Centraliza acuerdos, confianza y documentos importantes.',
    ),
    _OnboardingPageData(
      icon: Icons.donut_large_rounded,
      title: 'Gestiona tu Piso',
      subtitle: 'Organiza pagos, tareas y convivencia desde un lugar limpio.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _onPrimaryAction() async {
    final isLastPage = _currentPage == _pages.length - 1;
    if (isLastPage) {
      await _finishOnboarding();
      return;
    }

    await _pageController.nextPage(
      duration: AppTheme.motionNavigation,
      curve: AppTheme.motionCurveEmphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppTheme.darkBackground : const Color(0xFFF6FBF8);
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final mutedColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final page = _pages[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    var delta = 0.0;
                    if (_pageController.hasClients &&
                        _pageController.page != null) {
                      delta = (_pageController.page! - index).abs();
                    }
                    final opacity = (1 - delta * 0.42).clamp(0.0, 1.0);
                    final offset = 24 * delta;
                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(offset, 0),
                        child: child,
                      ),
                    );
                  },
                  child: _OnboardingPage(
                    page: page,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                );
              },
            ),
            Positioned(
              top: 14,
              right: 18,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: Text(
                  'Saltar',
                  style: TextStyle(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 26,
              child: Row(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      spacing: 7,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3.6,
                      dotColor: isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : const Color(0xFFCFE1D8),
                      activeDotColor: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(
                            alpha: isDark ? 0.42 : 0.28,
                          ),
                          blurRadius: 28,
                          spreadRadius: -6,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      heroTag: 'onboarding_next',
                      onPressed: _onPrimaryAction,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      child: AnimatedSwitcher(
                        duration: AppTheme.motionFast,
                        child: Icon(
                          isLastPage
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          key: ValueKey<bool>(isLastPage),
                        ),
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
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.page,
    required this.textColor,
    required this.mutedColor,
  });

  final _OnboardingPageData page;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 64, 28, 112),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 156,
            height: 156,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE8F7F0),
              borderRadius: BorderRadius.circular(42),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFD3EBDD),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(
                    alpha: isDark ? 0.26 : 0.14,
                  ),
                  blurRadius: 34,
                  spreadRadius: -8,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Icon(page.icon, size: 72, color: AppTheme.primary),
          ),
          const SizedBox(height: 38),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: mutedColor,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
