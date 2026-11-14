import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:provider/provider.dart';
import '../providers/admin_login_provider.dart';
import '../providers/app_lock_provider.dart';
import '../widgets/splash_brand_view.dart';
import 'admin/admin_shell_screen.dart';
import 'admin_login_screen.dart';
import 'user/user_home_screen.dart';

/// Admin Splash Screen displaying the Auto Spare Hub logo and "SN AUTO SPARE HUB"
/// branding with subtle animations and dark charcoal / gold styling.
class AdminSplashScreen extends StatefulWidget {
  const AdminSplashScreen({super.key});

  @override
  State<AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends State<AdminSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  Timer? _splashTimer;
  Future<bool>? _sessionFuture;

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
      _checkSessionAndScheduleNavigation();
    });
  }

  /// Concurrently verify persisted session in SharedPreferences and wait for splash animation
  void _checkSessionAndScheduleNavigation() {
    _sessionFuture = context.read<AdminLoginProvider>().checkSavedSession();

    _splashTimer = Timer(const Duration(milliseconds: 3000), () async {
      if (!mounted) return;
      final bool hasValidSession = await (_sessionFuture ?? Future.value(false));
      if (!mounted) return;
      final bool isUserFlavor = appFlavor != null && appFlavor != 'admin';
      context.read<AppLockProvider>().setAdminMode(!isUserFlavor);

      final Widget destination = isUserFlavor
          ? const UserHomeScreen()
          : (hasValidSession ? const AdminShellScreen() : const AdminLoginScreen());

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => destination,
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
      badge: 'ADMIN PORTAL',
    );
  }
}
