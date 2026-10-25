import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import '../../theme/app_theme.dart';
import 'admin_home_screen.dart';
import 'admin_menu_screen.dart';

/// Persistent shell container hosting the bottom navigation bar with Home and Menu destinations.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AdminHomeScreen(),
    AdminMenuScreen(),
  ];

  Future<bool> _showExitConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.darkHeader,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: AppColors.warmGold,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Exit Admin Panel?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkHeader,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit the SN AutoSpare Hub admin application?',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.darkCharcoal,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkButton,
              foregroundColor: AppColors.warmGold,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Exit',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        final shouldExit = await _showExitConfirmDialog(context);
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.darkCharcoal,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            height: 64,
            elevation: 0,
            backgroundColor: AppColors.darkCharcoal,
            indicatorColor: AppColors.primaryGold.withValues(alpha: 0.22),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: Colors.white70),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryGold),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined, color: Colors.white70),
                selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.primaryGold),
                label: 'Menu',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
