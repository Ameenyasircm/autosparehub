import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared splash layout for the user and admin apps: spotlight background,
/// ringed logo, and the "SN AUTO / SPARE HUB" brand lockup.
///
/// The animations are owned by the splash screen so each screen keeps its
/// own timing and navigation logic.
class SplashBrandView extends StatelessWidget {
  final Animation<double> logoFade;
  final Animation<double> logoScale;
  final Animation<double> textFade;
  final Animation<Offset> textSlide;

  /// Optional small badge under the tagline, e.g. "ADMIN PORTAL".
  final String? badge;

  const SplashBrandView({
    super.key,
    required this.logoFade,
    required this.logoScale,
    required this.textFade,
    required this.textSlide,
    this.badge,
  });

  static const String tagline = 'Auto Hydraulics & Brake System';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortestSide = size.shortestSide;
    final isTablet = shortestSide >= 600;
    final logoSize = (shortestSide * 0.42).clamp(140.0, 230.0);
    final titleSize = isTablet ? 40.0 : 31.0;

    return Scaffold(
      backgroundColor: AppColors.darkHeader,
      body: Stack(
        children: [
          // Spotlight background: lighter behind the logo, darker at the edges.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.25),
                  radius: 1.1,
                  colors: [
                    Color(0xFF2C313D),
                    AppColors.darkHeader,
                    Color(0xFF14171D),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: logoFade,
                      child: ScaleTransition(
                        scale: logoScale,
                        child: _buildRingedLogo(logoSize),
                      ),
                    ),
                    SizedBox(height: isTablet ? 36 : 28),
                    FadeTransition(
                      opacity: textFade,
                      child: SlideTransition(
                        position: textSlide,
                        child: _buildLockup(titleSize, isTablet),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: FadeTransition(
                  opacity: textFade,
                  child: Text(
                    'SN Auto Spare Hub  •  Manjeri',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingedLogo(double logoSize) {
    const ringGap = 9.0;
    return Container(
      width: logoSize + ringGap * 2,
      height: logoSize + ringGap * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.warmGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: 0.22),
            blurRadius: 48,
            spreadRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: logoSize,
        height: logoSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/AutoSpareLogo.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.darkCharcoal,
              child: const Icon(
                Icons.directions_car_filled,
                color: AppColors.primaryGold,
                size: 72,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockup(double titleSize, bool isTablet) {
    final goldLine = Container(
      width: isTablet ? 36 : 26,
      height: 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: const LinearGradient(
          colors: [Color(0x00E5A93C), AppColors.warmGold],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'SN AUTO',
            maxLines: 1,
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: titleSize,
              fontWeight: FontWeight.w900,
              letterSpacing: titleSize * 0.18,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 3),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              goldLine,
              const SizedBox(width: 10),
              Text(
                'SPARE HUB',
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.warmGold,
                  fontSize: titleSize * 0.48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: titleSize * 0.22,
                  shadows: [
                    Shadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.4),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              // Letter spacing adds trailing space after the last letter; balance it.
              SizedBox(width: 10 - titleSize * 0.22),
              Transform.flip(flipX: true, child: goldLine),
            ],
          ),
        ),
        SizedBox(height: isTablet ? 18 : 14),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: isTablet ? 15 : 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warmGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: AppColors.lightGold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
