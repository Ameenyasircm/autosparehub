import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:provider/provider.dart';
import '../providers/admin_login_provider.dart';
import '../providers/app_lock_provider.dart';
import '../theme/app_theme.dart';
import 'admin/admin_shell_screen.dart';
import 'admin_login_screen.dart';
import 'user/user_home_screen.dart';

/// Admin Splash Screen displaying the Auto Spare Hub logo and "SN AUTO HUB"
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

    _splashTimer = Timer(const Duration(milliseconds: 2000), () async {
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
    final size = MediaQuery.of(context).size;
    final logoSize = (size.width * 0.45).clamp(160.0, 220.0);

    return Scaffold(
      backgroundColor: AppColors.darkHeader,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGold.withValues(alpha: 0.25),
                            blurRadius: 32,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/AutoSpareLogo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.darkCharcoal,
                              child: const Icon(
                                Icons.directions_car_filled,
                                color: AppColors.primaryGold,
                                size: 72,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _textFadeAnimation,
                  child: SlideTransition(
                    position: _textSlideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'SN AUTO ',
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3.4,
                                    height: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        offset: const Offset(0, 2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                TextSpan(
                                  text: 'HUB',
                                  style: TextStyle(
                                    color: AppColors.warmGold,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3.4,
                                    height: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: AppColors.primaryGold.withValues(alpha: 0.35),
                                        blurRadius: 14,
                                      ),
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        offset: const Offset(0, 2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 72,
                          height: 2.5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.secondaryGold,
                                AppColors.lightGold,
                                AppColors.secondaryGold,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
