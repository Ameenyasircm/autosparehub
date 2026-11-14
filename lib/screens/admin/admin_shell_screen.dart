import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';

import '../../providers/admin_login_provider.dart';
import '../../providers/customer_management_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/admin_authorization_service.dart';
import '../../services/contact_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_helper.dart';
import '../admin_login_screen.dart';
import 'admin_home_screen.dart';
import 'admin_management_screen.dart';
import 'admin_menu_screen.dart';
import 'categories_screen.dart';
import 'companies_screen.dart';
import 'customer_approvals_screen.dart';
import 'widgets/edit_contact_numbers_dialog.dart';
import 'products_screen.dart';

/// Persistent shell container hosting:
/// - Mobile: Traditional bottom navigation bar with Orders and Menu destinations.
/// - Tablet (>= 720dp): Luxury side navigation rail/sidebar with immediate 1-tap access
///   to Orders, Customer Approvals, Products, Companies, Categories, Admin Management,
///   Helpline Settings, and Sign Out.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _currentIndex = 0; // For Mobile (0: Orders, 1: Menu)
  int _tabletIndex = 0;  // For Tablet (0: Orders, 1: Approvals, 2: Products, 3: Companies, 4: Categories, 5: Admins)

  final ContactService _contactService = ContactService();
  List<String> _activeContactPhones = const [ContactService.defaultPhoneNumber];

  final List<Widget> _mobileScreens = const [
    AdminHomeScreen(),
    AdminMenuScreen(),
  ];

  late final List<Widget> _tabletScreens = const [
    AdminHomeScreen(isTablet: true),
    CustomerApprovalsScreen(embedded: true),
    ProductsScreen(embedded: true),
    CompaniesScreen(embedded: true),
    CategoriesScreen(embedded: true),
    AdminManagementScreen(embedded: true),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissionIfNotGranted();
      context.read<OrderProvider>().startListeningAdminOrders();
      context.read<CustomerManagementProvider>().listenToCustomers();
    });
    _loadContactPhone();
  }

  Future<void> _loadContactPhone() async {
    final phones = await _contactService.fetchContactPhones();
    if (mounted) {
      setState(() {
        _activeContactPhones = phones;
      });
    }
  }

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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sign Out',
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
          'Are you sure you want to end your administrative session?',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13.5,
            height: 1.4,
          ),
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
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await context.read<AdminLoginProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 300),
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

  Future<void> _showEditContactDialog(BuildContext context) async {
    final saved = await showEditContactNumbersDialog(
      context,
      contactService: _contactService,
      currentPhones: _activeContactPhones,
    );
    if (saved != null && mounted) {
      setState(() => _activeContactPhones = saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (isTablet) {
          if (_tabletIndex != 0) {
            setState(() => _tabletIndex = 0);
            return;
          }
        } else {
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
            return;
          }
        }

        final shouldExit = await _showExitConfirmDialog(context);
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: isTablet ? _buildTabletLayout(context) : _buildMobileLayout(context),
    );
  }

  // =========================================================================
  // --- MOBILE LAYOUT (< 720dp) ---
  // =========================================================================
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _mobileScreens,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildBottomNav(context),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECEFF3), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: 'Orders',
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.darkCharcoal : const Color(0xFF8C95A6);

    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.warmGold,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // --- TABLET LAYOUT (>= 720dp) ---
  // =========================================================================
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Persistent Luxury Side Navigation Rail
          _buildTabletSidebar(context),

          // Main View Content
          Expanded(
            child: IndexedStack(
              index: _tabletIndex,
              children: _tabletScreens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletSidebar(BuildContext context) {
    final currentAdmin = context.watch<AdminLoginProvider>().currentAdmin;
    final orderProvider = context.watch<OrderProvider>();
    final customerProvider = context.watch<CustomerManagementProvider>();
    final isManager = AdminAuthorizationService.canManageAdmins(currentAdmin);

    final pendingOrdersCount = orderProvider.pendingOrdersCount;
    final pendingApprovalsCount = customerProvider.pendingCount;

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.darkCharcoal,
        border: Border(
          right: BorderSide(color: Color(0xFF262933), width: 1.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. App Header & Emblem
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.warmGold, width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warmGold.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/AutoSpareLogo.jpg',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.settings_suggest_rounded,
                        color: AppColors.warmGold,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'AutoSpare Hub',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Admin Console',
                        style: TextStyle(
                          color: AppColors.warmGold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Active Admin Profile Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.warmGold.withValues(alpha: 0.2),
                  child: Text(
                    (currentAdmin?.name.isNotEmpty == true ? currentAdmin!.name[0] : 'A').toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.warmGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentAdmin?.name ?? 'Admin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isManager ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isManager ? 'MANAGER' : 'STAFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // 3. Navigation Rail Destinations
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildSidebarItem(
                  index: 0,
                  icon: Icons.receipt_long_rounded,
                  title: 'Orders & Requests',
                  badge: pendingOrdersCount > 0 ? '$pendingOrdersCount' : null,
                  badgeColor: const Color(0xFFD97706),
                ),
                _buildSidebarItem(
                  index: 1,
                  icon: Icons.how_to_reg_rounded,
                  title: 'Customer Approvals',
                  badge: pendingApprovalsCount > 0 ? '$pendingApprovalsCount' : null,
                  badgeColor: const Color(0xFFD97706),
                ),
                _buildSidebarItem(
                  index: 2,
                  icon: Icons.precision_manufacturing_rounded,
                  title: 'Products Catalog',
                ),
                _buildSidebarItem(
                  index: 3,
                  icon: Icons.business_rounded,
                  title: 'Brands',
                ),
                _buildSidebarItem(
                  index: 4,
                  icon: Icons.category_rounded,
                  title: 'Part Categories',
                ),
                _buildSidebarItem(
                  index: 5,
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Admin Accounts',
                  isLocked: !isManager,
                  onLockedTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Access restricted. Only Managers can manage administrators.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),

                // Helpline Setting Quick Action
                _buildSidebarActionItem(
                  icon: Icons.contact_phone_rounded,
                  title: 'Store Helpline',
                  subtitle: formatContactPhones(_activeContactPhones, separator: '\n'),
                  iconColor: const Color(0xFF0D9488),
                  onTap: () => _showEditContactDialog(context),
                ),
              ],
            ),
          ),

          // 4. Sidebar Footer with Sign Out
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: _buildSidebarActionItem(
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              iconColor: AppColors.error,
              onTap: () => _showLogoutDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    bool isLocked = false,
    VoidCallback? onLockedTap,
  }) {
    final isSelected = _tabletIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: isSelected ? AppColors.warmGold.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (isLocked) {
              if (onLockedTap != null) onLockedTap();
              return;
            }
            setState(() => _tabletIndex = index);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppColors.warmGold.withValues(alpha: 0.4), width: 1)
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.warmGold
                      : (isLocked ? Colors.white30 : Colors.white70),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isLocked ? Colors.white38 : Colors.white.withValues(alpha: 0.85)),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (isLocked)
                  const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white30)
                else if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? AppColors.warmGold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
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

  Widget _buildSidebarActionItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 19, color: iconColor ?? Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.warmGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
