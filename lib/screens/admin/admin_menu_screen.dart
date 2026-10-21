import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_login_provider.dart';
import '../../services/admin_authorization_service.dart';
import '../../theme/app_theme.dart';
import '../admin_login_screen.dart';
import 'admin_management_screen.dart';
import 'categories_screen.dart';
import 'companies_screen.dart';

/// Dedicated Admin Menu screen with categorized management options.
class AdminMenuScreen extends StatelessWidget {
  const AdminMenuScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.darkCharcoal,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your administrative session?',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AdminLoginProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 400),
                  pageBuilder: (context, anim, secAnim) => const AdminLoginScreen(),
                  transitionsBuilder: (context, anim, secAnim, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
                (route) => false,
              );
            },
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = context.watch<AdminLoginProvider>().currentAdmin;
    final isManager = AdminAuthorizationService.canManageAdmins(currentAdmin);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: const Text(
          'Admin Menu',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        physics: const BouncingScrollPhysics(),
        children: [
          // Current Admin Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkCharcoal,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryGold, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryGold,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentAdmin?.name ?? 'Admin',
                        style: const TextStyle(
                          color: AppColors.darkCharcoal,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Phone: ${currentAdmin?.phoneNumber ?? '--'}',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    currentAdmin?.type ?? 'STAFF',
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // SECTION 1: ADMINISTRATION
          _buildSectionHeader('Administration'),
          const SizedBox(height: 8),

          _buildMenuItem(
            context: context,
            title: 'Manager Admins',
            description: 'Manage administrator accounts, roles, and access.',
            icon: Icons.admin_panel_settings_rounded,
            badge: isManager ? null : 'LOCKED',
            onTap: () {
              if (isManager) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminManagementScreen()),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Access restricted. Only Managers can manage administrators.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 24),

          // SECTION 2: BUSINESS SETUP
          _buildSectionHeader('Business Setup'),
          const SizedBox(height: 8),

          _buildMenuItem(
            context: context,
            title: 'Companies',
            description: 'Add and maintain vehicle manufacturers, brands, or companies.',
            icon: Icons.business_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CompaniesScreen()),
              );
            },
          ),

          const SizedBox(height: 10),

          _buildMenuItem(
            context: context,
            title: 'Categories',
            description: 'Manage spare parts categories and their images.',
            icon: Icons.category_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          // SECTION 3: SESSION MANAGEMENT
          _buildSectionHeader('Account & Session'),
          const SizedBox(height: 8),

          _buildMenuItem(
            context: context,
            title: 'Sign Out',
            description: 'Securely sign out of this administrative portal.',
            icon: Icons.logout_rounded,
            iconColor: AppColors.error,
            onTap: () => _showLogoutDialog(context),
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'AutoSpare Admin Portal • Version 2.0.0',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    Color? iconColor,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.darkCharcoal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? AppColors.primaryGold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.darkCharcoal,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
