import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:auto_spare_hub/utils/snackbar_helper.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/company_model.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone_helper.dart';
import '../../utils/responsive_helper.dart';
import 'cart_screen.dart';
import 'user_login_screen.dart';
import 'user_orders_screen.dart';
import 'user_product_detail_screen.dart';
import 'widgets/approval_pending_dialog.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/contact_us_sheet.dart';
import 'widgets/order_access_guard.dart';

/// Customer Storefront Home Screen:
/// - Dark AppBar (#12151B) with circular logo, "AUTO SPARE HUB" rich title, and rounded square cart button with badge dot
/// - Hierarchical browsing: Vehicle Companies -> Company Categories -> Spare Parts Items
/// - Global and scoped search bars, category quick-jump pills, and 2-Column grids
/// - 3-Tab Bottom Navigation Bar (Home, My Orders, Profile) with warm gold dot active indicator
class UserHomeScreen extends StatefulWidget {
  final bool showPendingAlertOnStart;
  final String? pendingPhone;

  const UserHomeScreen({
    super.key,
    this.showPendingAlertOnStart = false,
    this.pendingPhone,
  });

  static const int tabHome = 0;
  static const int tabOrders = 1;
  static const int tabProfile = 2;

  static final ValueNotifier<int?> _tabRequest = ValueNotifier<int?>(null);

  /// From any screen pushed on top of the home screen (e.g. the cart): go
  /// back to the home screen and switch it to [tab]. Keeps the same home
  /// screen, so the logged-in state and loaded data stay as they are.
  static void openTab(BuildContext context, int tab) {
    _tabRequest.value = tab;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentTabIndex = 0;
  final List<int> _tabHistory = [];
  final _searchController = TextEditingController();
  bool _isInitialLoading = true;
  bool _isCheckingApproval = false;
  CompanyModel? _selectedCompany;
  CategoryModel? _selectedCategory;

  void _handleTabRequest() {
    final tab = UserHomeScreen._tabRequest.value;
    if (tab == null || !mounted) return;
    UserHomeScreen._tabRequest.value = null;
    if (_currentTabIndex != tab) _tabHistory.add(_currentTabIndex);
    setState(() => _currentTabIndex = tab);
    if (tab == UserHomeScreen.tabOrders) {
      final cust = context.read<UserAuthProvider>().currentCustomer;
      if (cust != null) {
        context.read<OrderProvider>().listenToCustomerOrders(cust.id, userPhone: cust.phone);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    UserHomeScreen._tabRequest.addListener(_handleTabRequest);
    _isInitialLoading = context.read<CompanyProvider>().companies.isEmpty &&
        context.read<CategoryProvider>().categories.isEmpty &&
        context.read<ProductProvider>().products.isEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      NotificationService.instance.requestPermissionIfNotGranted();
      await context.read<UserAuthProvider>().initSession();
      if (!mounted) return;
      final auth = context.read<UserAuthProvider>();
      if (auth.currentCustomer != null) {
        final cust = auth.currentCustomer!;
        if (auth.isApproved) {
          context.read<CartProvider>().loadCartForUser(cust.id);
        }
        context.read<OrderProvider>().listenToCustomerOrders(cust.id, userPhone: cust.phone);
      }

      if (widget.showPendingAlertOnStart) {
        final phone = widget.pendingPhone ?? auth.currentCustomer?.phone ?? '';
        ApprovalPendingDialog.show(context, phone: phone);
      }

      // Live listeners: companies/categories/products hidden or changed in the
      // admin app update here immediately, without a refresh.
      await Future.wait([
        context.read<CompanyProvider>().startListening(),
        context.read<CategoryProvider>().startListening(),
        context.read<ProductProvider>().startListening(),
      ]);
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    });
  }

  @override
  void dispose() {
    UserHomeScreen._tabRequest.removeListener(_handleTabRequest);
    _searchController.dispose();
    super.dispose();
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
                'Exit App?',
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
          'Are you sure you want to exit SN AutoSpare Hub?',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.darkCharcoal,
            height: 1.4,
            fontWeight: FontWeight.w500,
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
    final cart = context.watch<CartProvider>();
    final auth = context.watch<UserAuthProvider>();

    // Account deleted by the admin while the app was open: logged out
    // automatically; clear local data and explain once.
    if (auth.accountRemovedNotice) {
      auth.consumeAccountRemovedNotice();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CartProvider>().onUserLogout();
        context.read<OrderProvider>().clearCustomerOrders();
        showAccountRemovedMessage(context);
      });
    }

    // One-time celebration notification when admin approves customer for the first time
    if (auth.shouldShowApprovalCelebration) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await auth.consumeApprovalCelebration();
        if (!mounted) return;
        final cust = auth.currentCustomer;
        if (cust != null) {
          context.read<CartProvider>().loadCartForUser(cust.id);
        }
        ScaffoldMessenger.of(context).showSnackBarAutoHide(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🎉 Your garage account has been approved! You can now place orders.',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.darkHeader,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Handle Home tab search & Company -> Category -> Items drill-down
        if (_currentTabIndex == 0) {
          final productProvider = context.read<ProductProvider>();

          // 1. If user is searching on any level, clear search query first
          if (_searchController.text.isNotEmpty) {
            setState(() {
              _searchController.clear();
            });
            productProvider.setSearchQuery('');
            return;
          }

          // 2. If user is viewing items in a category, go back to company's categories
          if (_selectedCategory != null) {
            _onBackToCategories(productProvider);
            return;
          }

          // 3. If user is viewing categories in a company, go back to companies grid
          if (_selectedCompany != null) {
            _onBackToCompanies(productProvider);
            return;
          }
        }

        // If user navigated between tabs, pop previous tab from history
        while (_tabHistory.isNotEmpty) {
          final prevTab = _tabHistory.removeLast();
          if (prevTab != _currentTabIndex) {
            setState(() => _currentTabIndex = prevTab);
            return;
          }
        }

        // If user is on Orders or Profile tab without history, switch back to Home tab first
        if (_currentTabIndex != 0) {
          setState(() => _currentTabIndex = 0);
          return;
        }

        final shouldExit = await _showExitConfirmDialog(context);
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: ResponsiveHelper.isTablet(context)
          ? _buildTabletLayout(context, cart, auth)
          : Scaffold(
              backgroundColor: AppColors.backgroundLight,
              appBar: _buildTopAppBar(context, cart, auth),
              body: SafeArea(
                top: false,
                child: IndexedStack(
                  index: _currentTabIndex,
                  children: [
                    _buildStorefrontCatalogTab(context),
                    const UserOrdersScreen(showAppBar: false),
                    _buildProfileTab(context, auth),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: _buildBottomNav(context),
              ),
            ),
    );
  }

  // =========================================================================
  // 1A. TABLET SHELL (>= 720dp) — PERSISTENT SIDEBAR RAIL
  // =========================================================================
  Widget _buildTabletLayout(
    BuildContext context,
    CartProvider cart,
    UserAuthProvider auth,
  ) {
    final orderProvider = context.watch<OrderProvider>();
    final customer = auth.currentCustomer;
    final activeOrdersCount = orderProvider.customerOrders
        .where((o) => o.isPending || o.isConfirmed || o.isDispatched)
        .length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabletSidebar(
            context,
            cart: cart,
            auth: auth,
            activeOrdersCount: customer == null ? 0 : activeOrdersCount,
          ),
          Expanded(
            child: Scaffold(
              backgroundColor: AppColors.backgroundLight,
              appBar: _buildTabletContentAppBar(context, cart, auth),
              body: SafeArea(
                top: false,
                left: false,
                child: IndexedStack(
                  index: _currentTabIndex,
                  children: [
                    _buildStorefrontCatalogTab(context),
                    const UserOrdersScreen(showAppBar: false),
                    _buildProfileTab(context, auth),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletSidebar(
    BuildContext context, {
    required CartProvider cart,
    required UserAuthProvider auth,
    required int activeOrdersCount,
  }) {
    final customer = auth.currentCustomer;

    final String statusLabel;
    final Color statusBg;
    if (customer == null) {
      statusLabel = 'SIGN IN';
      statusBg = AppColors.warmGold.withValues(alpha: 0.22);
    } else if (auth.isApproved) {
      statusLabel = 'APPROVED';
      statusBg = const Color(0xFF065F46);
    } else if (auth.isPending) {
      statusLabel = 'PENDING';
      statusBg = const Color(0xFFB45309);
    } else {
      statusLabel = 'REJECTED';
      statusBg = const Color(0xFF991B1B);
    }

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.darkCharcoal,
        border: Border(
          right: BorderSide(color: Color(0xFF262933), width: 1.2),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. App Header & Emblem
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Garage Portal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

            // 2. Active Customer Status Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Material(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (customer == null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UserLoginScreen()),
                      );
                    } else {
                      if (_currentTabIndex != UserHomeScreen.tabProfile) {
                        _tabHistory.add(_currentTabIndex);
                      }
                      setState(() => _currentTabIndex = UserHomeScreen.tabProfile);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: AppColors.warmGold.withValues(alpha: 0.2),
                          child: customer == null
                              ? const Icon(
                                  Icons.person_outline_rounded,
                                  color: AppColors.warmGold,
                                  size: 16,
                                )
                              : Text(
                                  (customer.name.isNotEmpty ? customer.name[0] : 'G').toUpperCase(),
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
                                customer?.name ?? 'Guest Garage',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: customer == null ? AppColors.warmGold : Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  ),
                ),
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
                  _buildTabletSidebarItem(
                    icon: Icons.storefront_rounded,
                    title: 'Browse Parts',
                    isSelected: _currentTabIndex == UserHomeScreen.tabHome,
                    onTap: () {
                      if (_currentTabIndex == UserHomeScreen.tabHome &&
                          (_selectedCompany != null ||
                              _selectedCategory != null ||
                              _searchController.text.isNotEmpty)) {
                        _onBackToCompanies(context.read<ProductProvider>());
                        return;
                      }
                      if (_currentTabIndex != UserHomeScreen.tabHome) {
                        _tabHistory.add(_currentTabIndex);
                      }
                      setState(() => _currentTabIndex = UserHomeScreen.tabHome);
                    },
                  ),
                  _buildTabletSidebarItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'My Orders',
                    isSelected: _currentTabIndex == UserHomeScreen.tabOrders,
                    badge: activeOrdersCount > 0 ? '$activeOrdersCount' : null,
                    badgeColor: const Color(0xFFD97706),
                    onTap: () {
                      if (_currentTabIndex != UserHomeScreen.tabOrders) {
                        _tabHistory.add(_currentTabIndex);
                      }
                      setState(() => _currentTabIndex = UserHomeScreen.tabOrders);
                      if (customer != null) {
                        context.read<OrderProvider>().listenToCustomerOrders(
                              customer.id,
                              userPhone: customer.phone,
                            );
                      }
                    },
                  ),
                  _buildTabletSidebarItem(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Shopping Cart',
                    isSelected: false,
                    badge: cart.totalItemCount > 0 ? '${cart.totalItemCount}' : null,
                    badgeColor: AppColors.warmGold,
                    badgeTextColor: AppColors.darkHeader,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    },
                  ),
                  _buildTabletSidebarItem(
                    icon: Icons.person_rounded,
                    title: 'Account & Profile',
                    isSelected: _currentTabIndex == UserHomeScreen.tabProfile,
                    onTap: () {
                      if (_currentTabIndex != UserHomeScreen.tabProfile) {
                        _tabHistory.add(_currentTabIndex);
                      }
                      setState(() => _currentTabIndex = UserHomeScreen.tabProfile);
                    },
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),

                  _buildTabletSidebarActionItem(
                    icon: Icons.support_agent_rounded,
                    title: 'Contact Store',
                    subtitle: 'Helpline & WhatsApp Support',
                    iconColor: const Color(0xFF0D9488),
                    onTap: () => ContactUsSheet.show(context),
                  ),
                ],
              ),
            ),

            // 4. Sidebar Footer
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: customer != null
                  ? _buildTabletSidebarActionItem(
                      icon: Icons.logout_rounded,
                      title: 'Sign Out',
                      iconColor: AppColors.error,
                      onTap: () async {
                        await auth.logout();
                        if (context.mounted) {
                          context.read<CartProvider>().onUserLogout();
                          context.read<OrderProvider>().clearCustomerOrders();
                          ScaffoldMessenger.of(context).showSnackBarAutoHide(
                            const SnackBar(content: Text('Logged out successfully.')),
                          );
                        }
                      },
                    )
                  : _buildTabletSidebarActionItem(
                      icon: Icons.login_rounded,
                      title: 'Login / Register',
                      iconColor: AppColors.warmGold,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const UserLoginScreen()),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletSidebarItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
    Color badgeTextColor = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: isSelected ? AppColors.warmGold.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
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
                  color: isSelected ? AppColors.warmGold : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? AppColors.warmGold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeTextColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletSidebarActionItem({
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.warmGold,
                          fontSize: 10.5,
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

  PreferredSizeWidget _buildTabletContentAppBar(
    BuildContext context,
    CartProvider cart,
    UserAuthProvider auth,
  ) {
    final String sectionTitle;
    switch (_currentTabIndex) {
      case UserHomeScreen.tabOrders:
        sectionTitle = 'My Spare Part Orders';
        break;
      case UserHomeScreen.tabProfile:
        sectionTitle = 'Profile & Garage Account';
        break;
      default:
        sectionTitle = 'Browse Spare Parts';
        break;
    }

    return AppBar(
      backgroundColor: AppColors.darkHeader,
      automaticallyImplyLeading: false,
      elevation: 0,
      toolbarHeight: 56,
      titleSpacing: 20,
      title: Text(
        sectionTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16.5,
        ),
      ),
      actions: [
        if (auth.isPending)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: InkWell(
              onTap: () => setState(() => _currentTabIndex = UserHomeScreen.tabProfile),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Pending Approval',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 8),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22262F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: AppColors.warmGold,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cart.totalItemCount > 0 ? 'Cart (${cart.totalItemCount})' : 'Cart',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 1. TOP APP BAR (MATCHING IMAGE 5)
  // =========================================================================
  PreferredSizeWidget _buildTopAppBar(
    BuildContext context,
    CartProvider cart,
    UserAuthProvider auth,
  ) {
    return AppBar(
      backgroundColor: AppColors.darkHeader,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Logo Emblem
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.warmGold.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/AutoSpareLogo.jpg',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.settings_suggest_rounded,
                  color: AppColors.warmGold,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Brand Title: "AUTO SPARE HUB" with "MANJERI"
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'AUTO SPARE ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'HUB',
                          style: TextStyle(
                            color: AppColors.warmGold,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'MANJERI',
                    style: TextStyle(
                      color: AppColors.warmGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 9.5,
                      letterSpacing: 2.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Pending Status Quick Chip (if applicable)
        if (auth.isPending)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: InkWell(
              onTap: () => setState(() => _currentTabIndex = 2),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Rounded Square Cart Button (matching Image 5 top right)
        Padding(
          padding: const EdgeInsets.only(right: 14, left: 6),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF22262F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: AppColors.warmGold,
                      size: 21,
                    ),
                    if (cart.totalItemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.warmGold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. STOREFRONT CATALOG TAB (COMPANY -> CATEGORY -> ITEMS BROWSING)
  // =========================================================================
  Widget _buildStorefrontCatalogTab(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    if (_isInitialLoading ||
        (companyProvider.isLoading && companyProvider.companies.isEmpty) ||
        (categoryProvider.isLoading && categoryProvider.categories.isEmpty)) {
      return _buildLoadingState();
    }

    // Resolve live active records so edits/deactivations in admin reflect immediately.
    CompanyModel? activeCompany;
    if (_selectedCompany != null) {
      for (final c in companyProvider.companies) {
        if (c.id == _selectedCompany!.id && c.isActive) {
          activeCompany = c;
          break;
        }
      }
    }

    CategoryModel? activeCategory;
    if (activeCompany != null && _selectedCategory != null) {
      for (final cat in categoryProvider.categories) {
        if (cat.id == _selectedCategory!.id &&
            cat.isActive &&
            cat.companyId == activeCompany.id) {
          activeCategory = cat;
          break;
        }
      }
    }

    if ((_selectedCompany != null && activeCompany == null) ||
        (activeCompany != null && _selectedCategory != null && activeCategory == null)) {
      final needsCompanyReset = _selectedCompany != null && activeCompany == null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (needsCompanyReset) {
            _selectedCompany = null;
          }
          _selectedCategory = null;
        });
        if (needsCompanyReset) {
          productProvider.clearFilters();
        } else {
          productProvider.setSelectedCategoryId('ALL');
        }
      });
    }

    if (activeCompany == null) {
      return _buildCompaniesView(
        context,
        companyProvider,
        categoryProvider,
        productProvider,
      );
    } else if (activeCategory == null) {
      return _buildCompanyCategoriesView(
        context,
        activeCompany,
        categoryProvider,
        productProvider,
      );
    } else {
      return _buildCategorySparesView(
        context,
        activeCompany,
        activeCategory,
        categoryProvider,
        productProvider,
      );
    }
  }

  Widget _buildCatalogSearchBar({
    required String hintText,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 14, 16, 10),
  }) {
    return Container(
      margin: margin,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDDE1E6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF8C95A6),
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkHeader,
                fontWeight: FontWeight.w500,
              ),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF8C95A6),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Color(0xFF8C95A6), size: 18),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }

  int _adaptiveGridColumns(double availableWidth) {
    if (availableWidth >= 900) return 4;
    if (availableWidth >= 540) return 3;
    return 2;
  }

  SliverGridDelegateWithFixedCrossAxisCount _buildCategoryGridDelegate({
    required BuildContext context,
    required double availableWidth,
    double horizontalPadding = 32,
    bool hasCompanyLabel = false,
  }) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4);
    final crossAxisCount = _adaptiveGridColumns(availableWidth);
    const spacing = 12.0;
    final colWidth =
        (availableWidth - horizontalPadding - (crossAxisCount - 1) * spacing) /
            crossAxisCount;
    final imageHeight = (colWidth * 0.72).clamp(92.0, 150.0);
    final detailsHeight = (hasCompanyLabel ? 98.0 : 72.0) * textScale + 18.0;
    final cardHeight = (imageHeight + detailsHeight).ceilToDouble();

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisExtent: cardHeight,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
    );
  }

  SliverGridDelegateWithFixedCrossAxisCount _buildProductGridDelegate({
    required BuildContext context,
    required double availableWidth,
    double horizontalPadding = 32,
  }) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4);
    final crossAxisCount = _adaptiveGridColumns(availableWidth);
    const spacing = 12.0;
    final colWidth =
        (availableWidth - horizontalPadding - (crossAxisCount - 1) * spacing) /
            crossAxisCount;
    final imageHeight = (colWidth * 0.68).clamp(88.0, 146.0);
    final detailsHeight = 114.0 * textScale + 58.0;
    final cardHeight = (imageHeight + detailsHeight).ceilToDouble();

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisExtent: cardHeight,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
    );
  }

  void _selectCompany(CompanyModel company, ProductProvider productProvider) {
    setState(() {
      _selectedCompany = company;
      _selectedCategory = null;
      _searchController.clear();
    });
    productProvider.setSelectedCompanyId(company.id);
    productProvider.setSelectedCategoryId('ALL');
    productProvider.setSearchQuery('');
  }

  void _selectCategory(
    CompanyModel company,
    CategoryModel category,
    ProductProvider productProvider,
  ) {
    setState(() {
      _selectedCompany = company;
      _selectedCategory = category;
      _searchController.clear();
    });
    productProvider.setSelectedCompanyId(company.id);
    productProvider.setSelectedCategoryId(category.id);
    productProvider.setSearchQuery('');
  }

  // --- 2A. LEVEL 1: COMPANIES BROWSING VIEW ---
  Widget _buildCompaniesView(
    BuildContext context,
    CompanyProvider companyProvider,
    CategoryProvider categoryProvider,
    ProductProvider productProvider,
  ) {
    final activeCompanies = companyProvider.companies.where((c) => c.isActive).toList();
    final companyById = {for (final c in activeCompanies) c.id: c};
    final activeCategories = categoryProvider.categories
        .where((c) => c.isActive && companyById.containsKey(c.companyId))
        .toList();
    final activeCategoryIds = activeCategories.map((c) => c.id).toSet();

    final query = _searchController.text.trim().toLowerCase();
    final isSearching = query.isNotEmpty;

    final filteredCompanies = isSearching
        ? activeCompanies.where((c) {
            final nameMatch = c.name.toLowerCase().contains(query);
            final descMatch = c.description?.toLowerCase().contains(query) ?? false;
            return nameMatch || descMatch;
          }).toList()
        : activeCompanies;

    final filteredCategories = isSearching
        ? activeCategories.where((c) {
            final nameMatch = c.name.toLowerCase().contains(query);
            final companyMatch = c.companyName.toLowerCase().contains(query);
            final descMatch = c.description?.toLowerCase().contains(query) ?? false;
            return nameMatch || companyMatch || descMatch;
          }).toList()
        : <CategoryModel>[];

    final searchProducts = isSearching
        ? productProvider.products.where((p) {
            if (!p.isActive) return false;
            if (!companyById.containsKey(p.companyId)) return false;
            if (!activeCategoryIds.contains(p.categoryId)) return false;
            return p.name.toLowerCase().contains(query) ||
                (p.refNo?.toLowerCase().contains(query) ?? false) ||
                p.application.toLowerCase().contains(query) ||
                (p.description?.toLowerCase().contains(query) ?? false) ||
                p.companyName.toLowerCase().contains(query) ||
                p.categoryName.toLowerCase().contains(query) ||
                p.searchKeywords.any((k) => k.toLowerCase().contains(query));
          }).toList()
        : <ProductModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCatalogSearchBar(
          hintText: 'Search brands, categories, spares...',
          onChanged: (val) {
            productProvider.setSearchQuery(val);
            setState(() {});
          },
          onClear: () {
            _searchController.clear();
            productProvider.setSearchQuery('');
            setState(() {});
          },
        ),

        if (isSearching && searchProducts.isNotEmpty) ...[
          if (filteredCompanies.isNotEmpty) ...[
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: filteredCompanies.map((comp) {
                  return _buildCategoryPill(
                    label: comp.name,
                    isSelected: false,
                    onTap: () {
                      final catCount = activeCategories
                          .where((c) => c.companyId == comp.id)
                          .length;
                      if (catCount == 0 && !categoryProvider.isLoading) {
                        _showEmptyCompanyDialog(comp);
                        return;
                      }
                      _selectCompany(comp, productProvider);
                    },
                    isCompact: true,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
          ] else if (filteredCategories.isNotEmpty) ...[
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: filteredCategories.map((cat) {
                  final parentCompany = companyById[cat.companyId];
                  final pillLabel = parentCompany != null
                      ? '${cat.name} (${parentCompany.name})'
                      : cat.name;
                  return _buildCategoryPill(
                    label: pillLabel,
                    isSelected: false,
                    onTap: () {
                      if (parentCompany == null) return;
                      final spareCount = productProvider.products
                          .where((p) =>
                              p.isActive &&
                              p.companyId == parentCompany.id &&
                              p.categoryId == cat.id)
                          .length;
                      if (spareCount == 0 && !productProvider.isLoading) {
                        _showEmptyCategoryDialog(cat);
                        return;
                      }
                      _selectCategory(parentCompany, cat, productProvider);
                    },
                    isCompact: true,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
          ],

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${searchProducts.length} Spares Found (All Brands)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkHeader,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                    setState(() {});
                  },
                  child: const Text(
                    'Clear Search ×',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                gridDelegate: _buildProductGridDelegate(
                  context: context,
                  availableWidth: constraints.maxWidth,
                ),
                itemCount: searchProducts.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(context, searchProducts[index]);
                },
              ),
            ),
          ),
        ] else if (isSearching && searchProducts.isEmpty && filteredCompanies.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${filteredCompanies.length} ${filteredCompanies.length == 1 ? 'Brand' : 'Brands'} matching "$query"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkHeader,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                    setState(() {});
                  },
                  child: const Text(
                    'Clear Search ×',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                gridDelegate: _buildCategoryGridDelegate(
                  context: context,
                  availableWidth: constraints.maxWidth,
                ),
                itemCount: filteredCompanies.length,
                itemBuilder: (context, index) {
                  final company = filteredCompanies[index];
                  final catCount = activeCategories
                      .where((c) => c.companyId == company.id)
                      .length;
                  return _buildCompanyCard(
                    context,
                    company,
                    catCount,
                    categoryProvider,
                    productProvider,
                  );
                },
              ),
            ),
          ),
        ] else if (isSearching &&
            searchProducts.isEmpty &&
            filteredCompanies.isEmpty &&
            filteredCategories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${filteredCategories.length} ${filteredCategories.length == 1 ? 'Category' : 'Categories'} matching "$query"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkHeader,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                    setState(() {});
                  },
                  child: const Text(
                    'Clear Search ×',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                gridDelegate: _buildCategoryGridDelegate(
                  context: context,
                  availableWidth: constraints.maxWidth,
                  hasCompanyLabel: true,
                ),
                itemCount: filteredCategories.length,
                itemBuilder: (context, index) {
                  final category = filteredCategories[index];
                  final parentCompany = companyById[category.companyId];
                  if (parentCompany == null) return const SizedBox.shrink();
                  final spareCount = productProvider.products
                      .where((p) =>
                          p.isActive &&
                          p.companyId == parentCompany.id &&
                          p.categoryId == category.id)
                      .length;
                  return _buildCategoryCard(
                    context,
                    parentCompany,
                    category,
                    spareCount,
                    productProvider,
                    companyLabel: parentCompany.name,
                  );
                },
              ),
            ),
          ),
        ] else if (isSearching) ...[
          Expanded(child: _buildEmptyCompaniesState(query, productProvider)),
        ] else ...[
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => RefreshIndicator(
                color: AppColors.warmGold,
                backgroundColor: AppColors.darkHeader,
                onRefresh: () async {
                  await Future.wait([
                    companyProvider.fetchCompanies(),
                    categoryProvider.fetchCategories(),
                    productProvider.fetchProducts(),
                  ]);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildWelcomePosterBanner(context),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Brands',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.darkHeader,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${activeCompanies.length} ${activeCompanies.length == 1 ? 'Brand' : 'Brands'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (activeCompanies.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyCompaniesState('', productProvider),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                        sliver: SliverGrid(
                          gridDelegate: _buildCategoryGridDelegate(
                            context: context,
                            availableWidth: constraints.maxWidth,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final company = activeCompanies[index];
                              final catCount = activeCategories
                                  .where((c) => c.companyId == company.id)
                                  .length;
                              return _buildCompanyCard(
                                context,
                                company,
                                catCount,
                                categoryProvider,
                                productProvider,
                              );
                            },
                            childCount: activeCompanies.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWelcomePosterBanner(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bannerMinHeight = screenWidth >= 600 ? 180.0 : 156.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        key: const ValueKey('welcome_truck_poster_banner'),
        decoration: BoxDecoration(
          color: AppColors.darkHeader,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.warmGold.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkHeader.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: bannerMinHeight),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.08,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: 2.6,
                        sigmaY: 2.6,
                        tileMode: TileMode.mirror,
                      ),
                      child: Image.asset(
                        'assets/heavy_truck_banner.jpg',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0.0, 0.05),
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPosterFallbackBackground(),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xCC12161E),
                          const Color(0x9E1E222B),
                          const Color(0xD412161E),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.15),
                        radius: 0.95,
                        colors: [
                          AppColors.warmGold.withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warmGold.withValues(alpha: 0.30),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.warmGold.withValues(alpha: 0.45),
                            width: 0.9,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping_rounded,
                              size: 12,
                              color: AppColors.warmGold,
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'WELCOME TO',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.lightGold,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'SN AUTO ',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  height: 1.15,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.75),
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
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  height: 1.15,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.75),
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
                      const SizedBox(height: 7),
                      Container(
                        width: 54,
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.warmGold,
                              AppColors.lightGold,
                              AppColors.warmGold,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Heavy Truck & Commercial Spares',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.35,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.75),
                              offset: const Offset(0, 1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterFallbackBackground() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkHeader,
            AppColors.darkCharcoal,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_shipping_rounded,
          size: 72,
          color: AppColors.warmGold.withValues(alpha: 0.14),
        ),
      ),
    );
  }

  void _showEmptyCompanyDialog(CompanyModel company) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.business_outlined, color: AppColors.warmGold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                company.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkHeader,
                ),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmptyBoxAnimation(),
            SizedBox(height: 14),
            Text(
              'No categories are added under this brand yet. Please check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppColors.darkHeader,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(
    BuildContext context,
    CompanyModel company,
    int categoryCount,
    CategoryProvider categoryProvider,
    ProductProvider productProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (categoryCount == 0 && !categoryProvider.isLoading) {
              _showEmptyCompanyDialog(company);
              return;
            }
            _selectCompany(company, productProvider);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: company.logoUrl.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: Image.network(
                                company.logoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _buildCompanyFallbackIcon(),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.warmGold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : _buildCompanyFallbackIcon(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  company.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkHeader,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$categoryCount ${categoryCount == 1 ? 'Category' : 'Categories'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.badgeGoldBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppColors.badgeGoldText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyFallbackIcon() {
    return Container(
      color: const Color(0xFFF7F8FA),
      child: const Center(
        child: Icon(
          Icons.business_rounded,
          color: AppColors.warmGold,
          size: 38,
        ),
      ),
    );
  }

  Widget _buildEmptyCompaniesState(String query, ProductProvider productProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              query.isNotEmpty ? 'No Matching Results' : 'No Brands Found',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              query.isNotEmpty
                  ? 'No brands, categories, or parts match "$query". Try another keyword.'
                  : 'Brands will appear here once added.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkCharcoal,
                  side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                ),
                onPressed: () {
                  _searchController.clear();
                  productProvider.setSearchQuery('');
                  setState(() {});
                },
                child: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 2B. LEVEL 2: CATEGORIES FOR SELECTED COMPANY ---
  Widget _buildCompanyCategoriesView(
    BuildContext context,
    CompanyModel company,
    CategoryProvider categoryProvider,
    ProductProvider productProvider,
  ) {
    final companyCategories = categoryProvider.categories
        .where((c) => c.isActive && c.companyId == company.id)
        .toList();
    final companyCategoryIds = companyCategories.map((c) => c.id).toSet();

    final query = _searchController.text.trim().toLowerCase();
    final isSearching = query.isNotEmpty;

    final filteredCategories = isSearching
        ? companyCategories.where((c) {
            final nameMatch = c.name.toLowerCase().contains(query);
            final descMatch = c.description?.toLowerCase().contains(query) ?? false;
            return nameMatch || descMatch;
          }).toList()
        : companyCategories;

    final searchProducts = isSearching
        ? productProvider.products.where((p) {
            if (!p.isActive) return false;
            if (p.companyId != company.id) return false;
            if (!companyCategoryIds.contains(p.categoryId)) return false;
            return p.name.toLowerCase().contains(query) ||
                (p.refNo?.toLowerCase().contains(query) ?? false) ||
                p.application.toLowerCase().contains(query) ||
                (p.description?.toLowerCase().contains(query) ?? false) ||
                p.categoryName.toLowerCase().contains(query) ||
                p.searchKeywords.any((k) => k.toLowerCase().contains(query));
          }).toList()
        : <ProductModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Company Navigation Header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => _onBackToCompanies(productProvider),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.darkHeader,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, color: AppColors.warmGold, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Brands',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      company.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkHeader,
                      ),
                    ),
                    Text(
                      '${companyCategories.length} ${companyCategories.length == 1 ? 'Category' : 'Categories'} Available',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (company.logoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    color: const Color(0xFFF1F5F9),
                    child: Image.network(
                      company.logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.business_outlined,
                        size: 20,
                        color: AppColors.warmGold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Search Bar (Within Company)
        _buildCatalogSearchBar(
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          hintText: 'Search categories or spares in ${company.name}...',
          onChanged: (val) {
            productProvider.setSearchQuery(val);
            setState(() {});
          },
          onClear: () {
            _searchController.clear();
            productProvider.setSearchQuery('');
            setState(() {});
          },
        ),

        if (isSearching && searchProducts.isNotEmpty) ...[
          if (filteredCategories.isNotEmpty) ...[
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: filteredCategories.map((cat) {
                  return _buildCategoryPill(
                    label: cat.name,
                    isSelected: false,
                    onTap: () {
                      final spareCount = productProvider.products
                          .where((p) =>
                              p.isActive &&
                              p.companyId == company.id &&
                              p.categoryId == cat.id)
                          .length;
                      if (spareCount == 0 && !productProvider.isLoading) {
                        _showEmptyCategoryDialog(cat);
                        return;
                      }
                      _selectCategory(company, cat, productProvider);
                    },
                    isCompact: true,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
          ],

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${searchProducts.length} Spares Found in ${company.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkHeader,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                    setState(() {});
                  },
                  child: const Text(
                    'Clear Search ×',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                gridDelegate: _buildProductGridDelegate(
                  context: context,
                  availableWidth: constraints.maxWidth,
                ),
                itemCount: searchProducts.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(context, searchProducts[index]);
                },
              ),
            ),
          ),
        ] else if (isSearching && searchProducts.isEmpty && filteredCategories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${filteredCategories.length} ${filteredCategories.length == 1 ? 'Category' : 'Categories'} matching "$query"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkHeader,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                    setState(() {});
                  },
                  child: const Text(
                    'Clear Search ×',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                gridDelegate: _buildCategoryGridDelegate(
                  context: context,
                  availableWidth: constraints.maxWidth,
                ),
                itemCount: filteredCategories.length,
                itemBuilder: (context, index) {
                  final category = filteredCategories[index];
                  final spareCount = productProvider.products
                      .where((p) =>
                          p.isActive &&
                          p.companyId == company.id &&
                          p.categoryId == category.id)
                      .length;
                  return _buildCategoryCard(
                    context,
                    company,
                    category,
                    spareCount,
                    productProvider,
                  );
                },
              ),
            ),
          ),
        ] else if (isSearching) ...[
          Expanded(
            child: _buildEmptyCompanyCategoriesState(
              company,
              query,
              productProvider,
            ),
          ),
        ] else ...[
          Expanded(
            child: RefreshIndicator(
              color: AppColors.warmGold,
              backgroundColor: AppColors.darkHeader,
              onRefresh: () async {
                await Future.wait([
                  categoryProvider.fetchCategories(),
                  productProvider.fetchProducts(),
                ]);
              },
              child: companyCategories.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: _buildEmptyCompanyCategoriesState(
                              company,
                              '',
                              productProvider,
                            ),
                          ),
                        );
                      },
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        gridDelegate: _buildCategoryGridDelegate(
                          context: context,
                          availableWidth: constraints.maxWidth,
                        ),
                        itemCount: companyCategories.length,
                        itemBuilder: (context, index) {
                          final category = companyCategories[index];
                          final spareCount = productProvider.products
                              .where((p) =>
                                  p.isActive &&
                                  p.companyId == company.id &&
                                  p.categoryId == category.id)
                              .length;
                          return _buildCategoryCard(
                            context,
                            company,
                            category,
                            spareCount,
                            productProvider,
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  // --- CATEGORY CARD ITEM ---
  void _showEmptyCategoryDialog(CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppColors.warmGold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.darkHeader),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmptyBoxAnimation(),
            SizedBox(height: 14),
            Text(
              'No items are added in this category yet. Please check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.darkHeader, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    CompanyModel company,
    CategoryModel category,
    int spareCount,
    ProductProvider productProvider, {
    String? companyLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Empty category: explain instead of opening an empty screen.
            // (While products are still loading the count is not final yet.)
            if (spareCount == 0 && !productProvider.isLoading) {
              _showEmptyCategoryDialog(category);
              return;
            }
            _selectCategory(company, category, productProvider);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Image Frame
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: category.imageUrl.isNotEmpty
                          ? Image.network(
                              category.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _buildCategoryFallbackIcon(),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.warmGold,
                                    ),
                                  ),
                                );
                              },
                            )
                          : _buildCategoryFallbackIcon(),
                    ),
                  ),
                ),
                if (companyLabel != null && companyLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    companyLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.badgeGoldText,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Category Name
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkHeader,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                // Spare Count and Forward Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$spareCount ${spareCount == 1 ? 'Part' : 'Parts'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.badgeGoldBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppColors.badgeGoldText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 2C. LEVEL 3: ITEMS VIEW FOR SELECTED COMPANY + CATEGORY ---
  Widget _buildCategorySparesView(
    BuildContext context,
    CompanyModel company,
    CategoryModel category,
    CategoryProvider categoryProvider,
    ProductProvider productProvider,
  ) {
    final companyCategories = categoryProvider.categories
        .where((c) => c.isActive && c.companyId == company.id)
        .toList();
    final companyCategoryIds = companyCategories.map((c) => c.id).toSet();

    final categoryProducts = productProvider.products
        .where((p) =>
            p.isActive &&
            p.companyId == company.id &&
            p.categoryId == category.id)
        .toList();

    final query = _searchController.text.trim().toLowerCase();
    final isSearching = query.isNotEmpty;

    final displayedProducts = productProvider.products.where((p) {
      if (!p.isActive || p.companyId != company.id) return false;
      final inScope = isSearching
          ? companyCategoryIds.contains(p.categoryId)
          : p.categoryId == category.id;
      if (!inScope) return false;
      if (!isSearching) return true;
      return p.name.toLowerCase().contains(query) ||
          (p.refNo?.toLowerCase().contains(query) ?? false) ||
          p.application.toLowerCase().contains(query) ||
          (p.description?.toLowerCase().contains(query) ?? false) ||
          p.companyName.toLowerCase().contains(query) ||
          p.categoryName.toLowerCase().contains(query) ||
          p.searchKeywords.any((k) => k.toLowerCase().contains(query));
    }).toList();

    return Column(
      children: [
        // Top Category Navigation Header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => _onBackToCategories(productProvider),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.darkHeader,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, color: AppColors.warmGold, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Categories',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkHeader,
                      ),
                    ),
                    Text(
                      '${company.name} • ${categoryProducts.length} ${categoryProducts.length == 1 ? 'Part' : 'Parts'} Available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (category.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    color: const Color(0xFFF1F5F9),
                    child: Image.network(
                      category.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.category_outlined,
                        size: 20,
                        color: AppColors.warmGold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Search Bar (Within Company)
        _buildCatalogSearchBar(
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          hintText: 'Search spare parts in ${company.name}...',
          onChanged: (val) {
            productProvider.setSearchQuery(val);
            setState(() {});
          },
          onClear: () {
            _searchController.clear();
            productProvider.setSearchQuery('');
            setState(() {});
          },
        ),

        // Quick Category Jump Bar (Categories within Selected Company)
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ...companyCategories.map((cat) {
                final isSelected = cat.id == category.id;
                return _buildCategoryPill(
                  label: cat.name,
                  isSelected: isSelected,
                  onTap: () {
                    if (!isSelected) {
                      _selectCategory(company, cat, productProvider);
                    }
                  },
                  isCompact: true,
                );
              }),
            ],
          ),
        ),

        // Filter Status Row
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isSearching
                      ? '${displayedProducts.length} Spares Found in ${company.name}'
                      : '${displayedProducts.length} ${displayedProducts.length == 1 ? 'Part' : 'Parts'} in ${category.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              if (isSearching)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                    productProvider.setSelectedCompanyId(company.id);
                    productProvider.setSelectedCategoryId(category.id);
                    setState(() {});
                  },
                  child: const Text(
                    'Clear Search ×',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2-Column Product Grid
        Expanded(
          child: RefreshIndicator(
            color: AppColors.warmGold,
            backgroundColor: AppColors.darkHeader,
            onRefresh: () async {
              await Future.wait([
                categoryProvider.fetchCategories(),
                productProvider.fetchProducts(),
              ]);
            },
            child: displayedProducts.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: _buildEmptyCategorySparesState(
                            company,
                            category,
                            productProvider,
                          ),
                        ),
                      );
                    },
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      gridDelegate: _buildProductGridDelegate(
                        context: context,
                        availableWidth: constraints.maxWidth,
                      ),
                      itemCount: displayedProducts.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(context, displayedProducts[index]);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _onBackToCategories(ProductProvider productProvider) {
    setState(() {
      _selectedCategory = null;
      _searchController.clear();
    });
    productProvider.setSelectedCategoryId('ALL');
    productProvider.setSearchQuery('');
    if (_selectedCompany != null) {
      productProvider.setSelectedCompanyId(_selectedCompany!.id);
    }
  }

  void _onBackToCompanies(ProductProvider productProvider) {
    setState(() {
      _selectedCompany = null;
      _selectedCategory = null;
      _searchController.clear();
    });
    productProvider.clearFilters();
  }

  Widget _buildCategoryFallbackIcon() {
    return Container(
      color: const Color(0xFFF7F8FA),
      child: const Center(
        child: Icon(
          Icons.category_outlined,
          color: AppColors.warmGold,
          size: 38,
        ),
      ),
    );
  }

  Widget _buildEmptyCompanyCategoriesState(
    CompanyModel company,
    String query,
    ProductProvider productProvider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              query.isNotEmpty
                  ? 'No Matching Categories or Parts'
                  : 'No Categories Under ${company.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              query.isNotEmpty
                  ? 'No categories or spare parts in ${company.name} match "$query".'
                  : 'Spare parts categories for ${company.name} will appear here once added.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                if (query.isNotEmpty)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkCharcoal,
                      side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      productProvider.setSearchQuery('');
                      setState(() {});
                    },
                    child: const Text('Clear Search'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkButton,
                    foregroundColor: AppColors.warmGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _onBackToCompanies(productProvider),
                  child: const Text('All Brands'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategorySparesState(
    CompanyModel company,
    CategoryModel category,
    ProductProvider provider,
  ) {
    final rawQuery = _searchController.text.trim().isNotEmpty
        ? _searchController.text.trim()
        : provider.searchQuery.trim();
    final isSearching = rawQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 52, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              isSearching
                  ? 'No Matching Spares Found'
                  : 'No Spares in ${category.name}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'No parts match "$rawQuery" in ${company.name}.'
                  : 'Parts in this category will be available soon.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                if (isSearching)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkCharcoal,
                      side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      provider.setSearchQuery('');
                      provider.setSelectedCompanyId(company.id);
                      provider.setSelectedCategoryId(category.id);
                      setState(() {});
                    },
                    child: const Text('Clear Search'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkButton,
                    foregroundColor: AppColors.warmGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _onBackToCategories(provider),
                  child: const Text('All Categories'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- CATEGORY PILL ITEM ---
  Widget _buildCategoryPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 11 : 14,
            vertical: isCompact ? 4 : 7,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkButton : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.warmGold : const Color(0xFFDDE1E6),
              width: 1.1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 11.5 : 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.warmGold : const Color(0xFF2C323E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 2-COLUMN PRODUCT CARD (MATCHING IMAGE 5 WITH PERFECTION) ---
  Widget _buildProductCard(BuildContext context, ProductModel product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            UserProductDetailScreen.show(context, product);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Category Tag Pill (e.g., "Engine Parts")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppColors.badgeGoldBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.badgeGoldBorder, width: 1),
                  ),
                  child: Text(
                    product.categoryName.isNotEmpty ? product.categoryName : 'Spare Part',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.badgeGoldText,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Centered Product Image
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(
                            Icons.car_repair,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Product Title (e.g., "Engine Oil Filter")
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryText,
                  ),
                ),

                const SizedBox(height: 2),

                // Brand snippet (product codes are admin-only)
                Text(
                  product.companyName.isNotEmpty ? product.companyName : 'Genuine Spare Part',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7A8499),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 6),

                // Price (e.g., "₹1522")
                Text(
                  product.price != null
                      ? '₹${product.price!.toStringAsFixed(0)}'
                      : 'Price on Req',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryText,
                  ),
                ),

                const SizedBox(height: 8),

                // Outlined "+ Add to Cart" Button (Matching Image 5)
                // Note: Crisp, unbroken, complete rounded rectangular border
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    context.read<CartProvider>().addToCart(product);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBarAutoHide(
                      SnackBar(
                        content: Text('Added ${product.name} to cart'),
                        backgroundColor: AppColors.darkButton,
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: 'View Cart',
                          textColor: AppColors.warmGold,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CartScreen()),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 34),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFBFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD6DAE2),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add, size: 15, color: AppColors.primaryGold),
                        SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Add to Cart',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
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

  // --- LOADING CATALOG STATE ---
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(
            color: AppColors.warmGold,
            strokeWidth: 2.8,
          ),
          SizedBox(height: 16),
          Text(
            'Loading spare parts...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _handleCheckApprovalStatus(UserAuthProvider auth) async {
    if (_isCheckingApproval) return;
    setState(() => _isCheckingApproval = true);
    try {
      await auth.refreshApprovalStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarAutoHide(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  auth.isApproved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                  color: auth.isApproved ? Colors.greenAccent : AppColors.warmGold,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    auth.isApproved
                        ? 'Account approved! You can now place orders.'
                        : 'Still pending administrator review.',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.darkHeader,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
    } finally {
      if (mounted) setState(() => _isCheckingApproval = false);
    }
  }

  // =========================================================================
  // 3. PROFILE / ACCOUNT TAB
  // =========================================================================
  Widget _buildProfileTab(BuildContext context, UserAuthProvider auth) {
    if (!auth.isRegistered) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.darkHeader,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warmGold.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/AutoSpareLogo.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Welcome to Auto Spare Hub',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkHeader,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in with your garage mobile number to view orders, check approval status, and manage spare part requests.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkButton,
                      foregroundColor: AppColors.warmGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UserLoginScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Login to Garage',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkCharcoal,
                      side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UserLoginScreen(initialIsRegister: true),
                        ),
                      );
                    },
                    child: const Text(
                      'Register New Garage',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => ContactUsSheet.show(context),
                  icon: const Icon(Icons.support_agent_rounded, size: 18, color: AppColors.warmGold),
                  label: const Text(
                    'Need Help? Contact Us',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkHeader,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Logged in User Profile Details
    final customer = auth.currentCustomer;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Garage Info Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E9F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.darkHeader,
                        child: Text(
                          customer?.name.isNotEmpty == true
                              ? customer!.name[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.warmGold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer?.name ?? 'Garage User',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkHeader,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              PhoneHelper.formatForDisplay(customer?.phone),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Status Pill
                  if (auth.isApproved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Verified & Approved Garage Customer',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (auth.isPending)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              color: Color(0xFFD97706),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Awaiting Administrator Approval',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your garage account registration has been submitted and is currently being reviewed. Once authorized, you can place orders directly.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'നിങ്ങളുടെ രജിസ്ട്രേഷൻ അഡ്മിൻ പരിശോധിച്ചുകൊണ്ടിരിക്കുകയാണ്. പരിശോധന പൂർത്തിയാക്കിയ ശേഷം അഡ്മിൻ നിങ്ങളെ ഉടൻ ബന്ധപ്പെടുന്നതാണ്. ദയവായി കാത്തിരിക്കുക!',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 1,
                        color: const Color(0xFFFDE68A).withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // InkWell(
                          //   onTap: () => ApprovalPendingDialog.show(
                          //     context,
                          //     phone: customer?.phone ?? '',
                          //   ),
                          //   borderRadius: BorderRadius.circular(6),
                          //   child: Padding(
                          //     padding: const EdgeInsets.symmetric(vertical: 4),
                          //     child: Row(
                          //       mainAxisSize: MainAxisSize.min,
                          //       children: [
                          //         Image.asset(
                          //           'assets/member_whats_app.png',
                          //           width: 15,
                          //           height: 15,
                          //         ),
                          //         const SizedBox(width: 5),
                          //         const Text(
                          //           'Contact Admin',
                          //           style: TextStyle(
                          //             fontSize: 11.5,
                          //             fontWeight: FontWeight.w700,
                          //             color: Color(0xFF92400E),
                          //             decoration: TextDecoration.underline,
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                          // ), // InkWell(
                          //   onTap: () => ApprovalPendingDialog.show(
                          //     context,
                          //     phone: customer?.phone ?? '',
                          //   ),
                          //   borderRadius: BorderRadius.circular(6),
                          //   child: Padding(
                          //     padding: const EdgeInsets.symmetric(vertical: 4),
                          //     child: Row(
                          //       mainAxisSize: MainAxisSize.min,
                          //       children: [
                          //         Image.asset(
                          //           'assets/member_whats_app.png',
                          //           width: 15,
                          //           height: 15,
                          //         ),
                          //         const SizedBox(width: 5),
                          //         const Text(
                          //           'Contact Admin',
                          //           style: TextStyle(
                          //             fontSize: 11.5,
                          //             fontWeight: FontWeight.w700,
                          //             color: Color(0xFF92400E),
                          //             color: Color(0xFF92400E),
                          //             decoration: TextDecoration.underline,
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                          // ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isCheckingApproval ? null : () => _handleCheckApprovalStatus(auth),
                              borderRadius: BorderRadius.circular(20),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.darkHeader, Color(0xFF2C303B)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.warmGold.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.darkHeader.withValues(alpha: 0.18),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isCheckingApproval)
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.warmGold,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.sync_rounded,
                                        size: 14,
                                        color: AppColors.warmGold,
                                      ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Check Approval Status',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Settings / Actions List
        // ListTiles paint their ripple on the nearest Material; the transparent
        // Material keeps it visible above the white box, the clip keeps it
        // inside the rounded corners.
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E9F0)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: AppColors.warmGold),
                title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UserOrdersScreen(showAppBar: true),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: AppColors.dividerLight),
              ListTile(
                leading: const Icon(Icons.support_agent_rounded, color: AppColors.warmGold),
                title: const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () => ContactUsSheet.show(context),
              ),
              const Divider(height: 1, color: AppColors.dividerLight),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded, color: AppColors.warmGold),
                title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () => ChangeUserPasswordDialog.show(context),
              ),
              const Divider(height: 1, color: AppColors.dividerLight),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error)),
                onTap: () async {
                  await auth.logout();
                  if (context.mounted) {
                    context.read<CartProvider>().onUserLogout();
                    // Stop live order updates and clear this customer's orders.
                    context.read<OrderProvider>().clearCustomerOrders();
                    ScaffoldMessenger.of(context).showSnackBarAutoHide(
                      const SnackBar(content: Text('Logged out successfully.')),
                    );
                  }
                },
              ),
            ],
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. BOTTOM NAVIGATION BAR (MATCHING IMAGE 2 & 5)
  // =========================================================================
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.format_list_bulleted_rounded,
            activeIcon: Icons.format_list_bulleted_rounded,
            label: 'My Orders',
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
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
    final bool isSelected = _currentTabIndex == index;
    final color = isSelected ? AppColors.darkCharcoal : const Color(0xFF8C95A6);

    return InkWell(
      onTap: () {
        if (_currentTabIndex == index &&
            index == 0 &&
            (_selectedCompany != null ||
                _selectedCategory != null ||
                _searchController.text.isNotEmpty)) {
          _onBackToCompanies(context.read<ProductProvider>());
          return;
        }
        if (_currentTabIndex != index) {
          _tabHistory.add(_currentTabIndex);
        }
        setState(() => _currentTabIndex = index);
        if (index == 1) {
          final auth = context.read<UserAuthProvider>();
          if (auth.currentCustomer != null) {
            final cust = auth.currentCustomer!;
            context.read<OrderProvider>().listenToCustomerOrders(cust.id, userPhone: cust.phone);
          }
        }
      },
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            // Active Gold Dot Indicator (Matching Image 2 & 5)
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
}

/// Small looping "empty" illustration for the empty-category alert:
/// an open box floating over its shadow, a soft pulsing halo and a "?" bubble.
class _EmptyBoxAnimation extends StatefulWidget {
  const _EmptyBoxAnimation();

  @override
  State<_EmptyBoxAnimation> createState() => _EmptyBoxAnimationState();
}

class _EmptyBoxAnimationState extends State<_EmptyBoxAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 120,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          final lift = -10 * t; // box floats up and down
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing halo
              Transform.scale(
                scale: 0.85 + 0.15 * t,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.warmGold.withValues(alpha: 0.10 + 0.08 * (1 - t)),
                  ),
                ),
              ),
              // Shadow: shrinks as the box rises
              Positioned(
                bottom: 14,
                child: Container(
                  width: 46 - 14 * t,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.10 - 0.04 * t),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Empty box
              Transform.translate(
                offset: Offset(0, lift),
                child: Transform.rotate(
                  angle: 0.06 * (t - 0.5),
                  child: const Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.warmGold),
                ),
              ),
              // "?" bubble, fades in and out
              Positioned(
                top: 8 + lift / 2,
                right: 16,
                child: Opacity(
                  opacity: 0.35 + 0.65 * t,
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.darkHeader,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '?',
                      style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
