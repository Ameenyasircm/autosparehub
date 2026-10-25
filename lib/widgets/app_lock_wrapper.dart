import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_lock_provider.dart';
import '../screens/app_lock_screen.dart';

/// Wraps any screen or the entire MaterialApp in the App Lock protector.
/// When the version lock is active, seamlessly displays AppLockScreen
/// without destroying the navigation stack or re-initializing providers.
class AppLockWrapper extends StatelessWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final lockProvider = context.watch<AppLockProvider>();

    if (lockProvider.isLocked) {
      return const AppLockScreen();
    }

    return child;
  }
}
