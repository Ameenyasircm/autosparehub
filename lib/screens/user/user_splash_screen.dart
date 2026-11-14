import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_lock_provider.dart';
import '../../widgets/splash_brand_view.dart';
import 'user_home_screen.dart';

/// User Splash Screen displaying the Auto Spare Hub logo and "SN AUTO SPARE HUB"
/// branding with subtle fade, scale, and slide animations.
class UserSplashScreen extends StatefulWidget {
  final WidgetBuilder? destinationBuilder;

  const UserSplashScreen({
    super.key,
    this.destinationBuilder,
  });

  @override
  State<UserSplashScreen> createState() => _UserSplashScreenState();
}

class _UserSplashScreenState extends State<UserSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<Offset> _textSlideAnimation;

  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textFadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleNavigation();
    });
  }

  void _scheduleNavigation() {
    _splashTimer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;

      try {
        context.read<AppLockProvider>().setAdminMode(false);
      } catch (_) {
        // Provider may be omitted in isolated widget tests.
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              widget.destinationBuilder?.call(context) ?? const UserHomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SplashBrandView(
      logoFade: _fadeAnimation,
      logoScale: _scaleAnimation,
      textFade: _textFadeAnimation,
      textSlide: _textSlideAnimation,
    );
  }
}
