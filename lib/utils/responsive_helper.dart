import 'package:flutter/material.dart';

/// Centralized utility for responsive design breakpoints and tablet detection
/// across the AutoSpare Hub application.
class ResponsiveHelper {
  /// Minimum width threshold (in logical pixels) for tablet UI layouts.
  static const double tabletBreakpoint = 720.0;

  /// Minimum width threshold for desktop / wide landscape tablet layouts.
  static const double wideTabletBreakpoint = 980.0;

  /// Returns true if the device screen width is tablet size or larger (>= 720dp).
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Returns true if the device screen is wide tablet or landscape workstation size (>= 980dp).
  static bool isWideTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= wideTabletBreakpoint;
  }

  /// Returns true if the device screen is standard mobile phone size (< 720dp).
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < tabletBreakpoint;
  }

  /// Selects a responsive value according to current screen form factor.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    required T tablet,
    T? wideTablet,
  }) {
    if (isWideTablet(context) && wideTablet != null) {
      return wideTablet;
    }
    if (isTablet(context)) {
      return tablet;
    }
    return mobile;
  }
}

