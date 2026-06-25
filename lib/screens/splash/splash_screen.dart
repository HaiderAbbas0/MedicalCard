import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final AnimationController _pulse;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _intro.forward();
    _navTimer = Timer(const Duration(milliseconds: 2200), _go);
  }

  Future<void> _go() async {
    final auth = context.read<AuthProvider>();
    while (!auth.bootstrapped) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
    }
    if (!mounted) return;
    if (auth.loggedIn) {
      context.go('/dashboard');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: brandGradient(context)),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _fade,
                      child: Container(
                        width: 104,
                        height: 104,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const _MedicalCross(size: 52, color: kPrimary),
                      ),
                    ),
                    const SizedBox(height: 26),
                    SlideTransition(
                      position: _slide,
                      child: FadeTransition(
                        opacity: _fade,
                        child: Column(
                          children: [
                            Text(
                              'Sehat ID',
                              style: AppText.display.copyWith(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Your health history, always with you',
                              textAlign: TextAlign.center,
                              style: AppText.body.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 70),
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final t = (_pulse.value + i / 3) % 1.0;
                          final scale = 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2);
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5),
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withValues(alpha: 0.45 + 0.45 * scale),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green medical cross built from two rounded rectangles.
class _MedicalCross extends StatelessWidget {
  final double size;
  final Color color;
  const _MedicalCross({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final bar = size * 0.30;
    final radius = BorderRadius.circular(size * 0.12);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: bar,
            height: size,
            decoration: BoxDecoration(color: color, borderRadius: radius),
          ),
          Container(
            width: size,
            height: bar,
            decoration: BoxDecoration(color: color, borderRadius: radius),
          ),
        ],
      ),
    );
  }
}
