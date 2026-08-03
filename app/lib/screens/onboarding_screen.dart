import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:tingungu_app/screens/register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  bool _isLastPage = false;

  static const _pages = [
    _OnboardData(
      image: 'lib/assets/images/logo.png',
      title: 'Welcome to Tingungu',
      description:
          'Your church companion app – connect with your society, stay informed, and access spiritual support.',
    ),
    _OnboardData(
      image: 'lib/assets/images/logo.png',
      title: 'Buy & Pay Easily',
      description:
          'Buy airtime, pay electricity bills, send vouchers and much more right inside the app.',
    ),
    _OnboardData(
      image: 'lib/assets/images/logo.png',
      title: 'Stay Updated',
      description:
          'Get instant notifications for church announcements, events, and society notices.',
    ),
    _OnboardData(
      image: 'lib/assets/images/logo.png',
      title: 'Secure Giving',
      description:
          'Give your tithes, offerings, and pledges in a few taps with trusted channels.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3B0D11),
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedOpacity(
                        opacity: _isLastPage ? 0 : 1,
                        duration: const Duration(milliseconds: 250),
                        child: TextButton(
                          onPressed: _isLastPage ? null : _finishOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          child: const Text(
                            'SKIP',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _isLastPage = index == _pages.length - 1);
                    },
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          double page = index.toDouble();
                          if (_controller.hasClients) {
                            page =
                                _controller.page ??
                                _controller.initialPage.toDouble();
                          }
                          final distance = (page - index).abs().clamp(0.0, 1.0);
                          final scale = 1 - (distance * 0.1);
                          final opacity = 1 - (distance * 0.55);
                          return Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: Transform.scale(scale: scale, child: child),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _OnboardPage(
                            key: ValueKey(index),
                            data: _pages[index],
                            stepNumber: index + 1,
                            totalSteps: _pages.length,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SmoothPageIndicator(
                  controller: _controller,
                  count: _pages.length,
                  effect: const ExpandingDotsEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3.5,
                    spacing: 6,
                    activeDotColor: Color(0xFFFB8B24),
                    dotColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: _isLastPage
                        ? _PulsingButton(
                            child: ElevatedButton(
                              onPressed: _finishOnboarding,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFB8B24),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 8,
                                shadowColor: const Color(
                                  0xFFFB8B24,
                                ).withValues(alpha: 0.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'GET STARTED',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: () {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(54),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'NEXT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft, static radial glows over a subtle vertical gradient. Cheap to
/// render (no blur filters) since the glow itself is baked into the
/// gradient stops rather than post-processed.
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A0A0D), Color(0xFF3B0D11), Color(0xFF4A1116)],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _GlowOrb(size: 260, color: const Color(0xFFFB8B24)),
        ),
        Positioned(
          bottom: -110,
          left: -90,
          child: _GlowOrb(size: 240, color: const Color(0xFFFB8B24)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

class _OnboardData {
  final String image;
  final String title;
  final String description;

  const _OnboardData({
    required this.image,
    required this.title,
    required this.description,
  });
}

class _OnboardPage extends StatefulWidget {
  final _OnboardData data;
  final int stepNumber;
  final int totalSteps;

  const _OnboardPage({
    super.key,
    required this.data,
    required this.stepNumber,
    required this.totalSteps,
  });

  @override
  State<_OnboardPage> createState() => _OnboardPageState();
}

class _OnboardPageState extends State<_OnboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _interval(double start, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.data.title.split(' ');
    final imageAnim = _interval(0.0, 0.45);
    final tagAnim = _interval(0.1, 0.5);
    final cardAnim = _interval(0.25, 0.7);
    final descriptionAnim = _interval(0.6, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: imageAnim,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(imageAnim),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFB8B24).withValues(alpha: 0.22),
                        const Color(0xFFFB8B24).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                Image.asset(widget.data.image, height: 170),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeTransition(
          opacity: tagAnim,
          child: Text(
            'STEP ${widget.stepNumber} OF ${widget.totalSteps}',
            style: const TextStyle(
              color: Color(0xFFFB8B24),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.4,
            ),
          ),
        ),
        const SizedBox(height: 20),
        FadeTransition(
          opacity: cardAnim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(cardAnim),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: List.generate(words.length, (i) {
                          final start = (0.3 + i * 0.12).clamp(0.0, 1.0);
                          final end = (start + 0.45).clamp(0.0, 1.0);
                          final anim = _interval(start, end);
                          return AnimatedBuilder(
                            animation: anim,
                            builder: (context, child) => Opacity(
                              opacity: anim.value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - anim.value) * 14),
                                child: child,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                words[i],
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      FadeTransition(
                        opacity: descriptionAnim,
                        child: Text(
                          widget.data.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingButton extends StatefulWidget {
  final Widget child;

  const _PulsingButton({required this.child});

  @override
  State<_PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<_PulsingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1.04,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}
