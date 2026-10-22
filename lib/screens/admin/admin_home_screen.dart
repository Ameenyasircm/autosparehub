import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../providers/admin_login_provider.dart';
import '../../services/admin_authorization_service.dart';
import '../../theme/app_theme.dart';
import '../admin_login_screen.dart';
import 'admin_management_screen.dart';
import 'categories_screen.dart';
import 'companies_screen.dart';
import 'product_form_screen.dart';
import 'products_screen.dart';

/// Polished Automotive Admin Dashboard showing actual Firestore counts and quick management actions.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminDashboardProvider>().fetchDashboardCounts();
    });
  }

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
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await context.read<AdminLoginProvider>().logout();
              if (!context.mounted) return;
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

  Future<void> _navigateTo(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    // Refresh dashboard counts on return
    if (!mounted) return;
    context.read<AdminDashboardProvider>().fetchDashboardCounts();
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = context.watch<AdminLoginProvider>().currentAdmin;
    final dashboardProvider = context.watch<AdminDashboardProvider>();
    final adminName = currentAdmin?.name.isNotEmpty == true ? currentAdmin!.name : 'Admin';
    final adminType = currentAdmin?.type.isNotEmpty == true ? currentAdmin!.type : 'MANAGER';
    final isManager = AdminAuthorizationService.canManageAdmins(currentAdmin);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        color: AppColors.primaryGold,
        backgroundColor: AppColors.darkCharcoal,
        onRefresh: () => context.read<AdminDashboardProvider>().fetchDashboardCounts(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // --- HEADER WITH LOGO & GREETING ---
            SliverAppBar(
              expandedHeight: 140.0,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.darkCharcoal,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/AutoSpareLogo.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.directions_car,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ),
              ),
              title: const Text(
                'AutoSpare Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: 0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.lightGold),
                  tooltip: 'Refresh Counts',
                  onPressed: () => dashboardProvider.fetchDashboardCounts(),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppColors.lightGold),
                  tooltip: 'Sign Out',
                  onPressed: () => _showLogoutDialog(context),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1E2125),
                        AppColors.darkCharcoal,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 54, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Welcome back, $adminName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Automotive Spare Parts Management',
                                  style: TextStyle(
                                    color: AppColors.textMuted.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryGold, AppColors.lightGold],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              adminType,
                              style: const TextStyle(
                                color: AppColors.darkCharcoal,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- DASHBOARD BODY CONTENT ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- REAL FIRESTORE DATA SUMMARY CARDS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Catalog & Operations',
                              style: TextStyle(
                                color: AppColors.darkCharcoal,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (dashboardProvider.isLoading) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Top Quick Action: + Add Product Shortcut
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGold,
                            foregroundColor: AppColors.darkCharcoal,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                          onPressed: () => _navigateTo(const ProductFormScreen()),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'Add Product',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // --- 2x2 METRICS GRID ---
                    Row(
                      children: [
                        _buildSummaryCard(
                          title: 'Products',
                          count: dashboardProvider.productCount,
                          subtitle: 'Spare Parts',
                          icon: Icons.precision_manufacturing_outlined,
                          accentColor: AppColors.primaryGold,
                          isLoading: dashboardProvider.isLoading,
                          onTap: () => _navigateTo(const ProductsScreen()),
                        ),
                        const SizedBox(width: 10),
                        _buildSummaryCard(
                          title: 'Companies',
                          count: dashboardProvider.companyCount,
                          subtitle: 'Vehicle Brands',
                          icon: Icons.business_outlined,
                          accentColor: AppColors.secondaryGold,
                          isLoading: dashboardProvider.isLoading,
                          onTap: () => _navigateTo(const CompaniesScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildSummaryCard(
                          title: 'Categories',
                          count: dashboardProvider.categoryCount,
                          subtitle: 'Part Catalog',
                          icon: Icons.category_outlined,
                          accentColor: AppColors.darkCharcoal,
                          isLoading: dashboardProvider.isLoading,
                          onTap: () => _navigateTo(const CategoriesScreen()),
                        ),
                        const SizedBox(width: 10),
                        _buildSummaryCard(
                          title: 'Admins',
                          count: dashboardProvider.adminCount,
                          subtitle: 'Registered Staff',
                          icon: Icons.admin_panel_settings_outlined,
                          accentColor: AppColors.primaryGold,
                          isLoading: dashboardProvider.isLoading,
                          onTap: () {
                            if (isManager) {
                              _navigateTo(const AdminManagementScreen());
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Admin Management requires MANAGER privileges.'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- MAIN CENTRAL SECTION (RESERVED FOR CUSTOMER ORDERS FEED) ---

                    // --- SYSTEM STATUS BANNER ---
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.cloud_done_rounded,
                              color: AppColors.primaryGold,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Cloud Storage & Database Active',
                                  style: TextStyle(
                                    color: AppColors.darkCharcoal,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Cloud Firestore and Cloudinary (autospare/*) synchronized',
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 20, color: accentColor),
                    if (isLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    else
                      Text(
                        count.toString(),
                        style: const TextStyle(
                          color: AppColors.darkCharcoal,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.darkCharcoal,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 9.5,
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
