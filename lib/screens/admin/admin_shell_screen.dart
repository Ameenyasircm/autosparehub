import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
