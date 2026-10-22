import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/customer_model.dart';
import '../../models/order_model.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../providers/admin_login_provider.dart';
import '../../providers/customer_management_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/admin_authorization_service.dart';
import '../../theme/app_theme.dart';
import '../admin_login_screen.dart';
import 'admin_management_screen.dart';
import 'categories_screen.dart';
import 'companies_screen.dart';
import 'product_form_screen.dart';
import 'products_screen.dart';

/// Comprehensive Automotive Admin Dashboard with Live Orders Management,
/// Date/Status Filtering, Customer Approval Center, and Catalog Metrics.
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
      _refreshAllData();
    });
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      context.read<AdminDashboardProvider>().fetchDashboardCounts(),
      context.read<CustomerManagementProvider>().fetchCustomers(),
      context.read<OrderProvider>().fetchAdminOrders(),
    ]);
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
    if (!mounted) return;
    _refreshAllData();
  }

  // --- CUSTOMER APPROVAL REVIEW MODAL ---
  void _showCustomerApprovalsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer<CustomerManagementProvider>(
          builder: (context, customerProvider, child) {
            final pending = customerProvider.pendingCustomers;
            final currentAdmin = context.read<AdminLoginProvider>().currentAdmin;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_add_rounded, color: Colors.amber, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Pending Approvals (${pending.length})',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: pending.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 48, color: Colors.green.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'All customer requests have been processed!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkCharcoal,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: pending.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final customer = pending[index];
                              return _buildCustomerApprovalCard(customer, currentAdmin?.id);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerApprovalCard(CustomerModel customer, String? adminId) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppColors.darkCharcoal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: AppColors.secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          customer.phone,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primaryGold),
                          tooltip: 'Copy Phone',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: customer.phone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied ${customer.phone} to clipboard'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final provider = context.read<CustomerManagementProvider>();
                  final ok = await provider.rejectCustomer(customer.id);
                  if (mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Rejected request for ${customer.name}')),
                    );
                  }
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final provider = context.read<CustomerManagementProvider>();
                  final ok = await provider.approveCustomer(customer.id, adminId: adminId);
                  if (mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Approved ${customer.name}! They can now place orders.')),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approve Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ORDER STATUS UPDATER SHEET ---
  void _showOrderStatusDialog(BuildContext context, OrderModel order) {
    final orderProvider = context.read<OrderProvider>();
    const statuses = [
      {'status': 'PENDING', 'label': 'Pending Review', 'icon': Icons.hourglass_top_rounded, 'color': Colors.amber},
      {'status': 'CONFIRMED', 'label': 'Confirmed & Processing', 'icon': Icons.thumb_up_alt_rounded, 'color': Colors.blue},
      {'status': 'DISPATCHED', 'label': 'Dispatched for Delivery', 'icon': Icons.local_shipping_rounded, 'color': Colors.deepPurple},
      {'status': 'DELIVERED', 'label': 'Delivered Successfully', 'icon': Icons.check_circle_rounded, 'color': Colors.green},
      {'status': 'CANCELLED', 'label': 'Cancelled / Rejected', 'icon': Icons.cancel_rounded, 'color': Colors.red},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Status for ${order.orderNumber}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
              ),
              const SizedBox(height: 4),
              Text(
                'Current Status: ${order.status}',
                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 16),
              ...statuses.map((s) {
                final isSelected = order.status == s['status'];
                final color = s['color'] as Color;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? color : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    tileColor: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
                    leading: Icon(s['icon'] as IconData, color: color),
                    title: Text(
                      s['label'] as String,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.darkCharcoal,
                        fontSize: 13,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: color) : null,
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      final ok = await orderProvider.updateOrderStatus(order.id, s['status'] as String);
                      if (context.mounted && ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Order ${order.orderNumber} updated to ${s['status']}')),
                        );
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // --- CUSTOM DATE RANGE PICKER ---
  Future<void> _pickCustomDateRange(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();
    final initialRange = orderProvider.customDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.darkCharcoal,
              onPrimary: AppColors.primaryGold,
              surface: Colors.white,
              onSurface: AppColors.darkCharcoal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      orderProvider.setDateFilter(OrderDateFilter.custom, customRange: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = context.watch<AdminLoginProvider>().currentAdmin;
    final dashboardProvider = context.watch<AdminDashboardProvider>();
    final customerProvider = context.watch<CustomerManagementProvider>();
    final orderProvider = context.watch<OrderProvider>();

    final adminName = currentAdmin?.name.isNotEmpty == true ? currentAdmin!.name : 'Admin';
    final adminType = currentAdmin?.type.isNotEmpty == true ? currentAdmin!.type : 'MANAGER';
    final isManager = AdminAuthorizationService.canManageAdmins(currentAdmin);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        color: AppColors.primaryGold,
        backgroundColor: AppColors.darkCharcoal,
        onRefresh: _refreshAllData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // --- HEADER ---
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
                  tooltip: 'Refresh All',
                  onPressed: _refreshAllData,
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
                    // --- PENDING CUSTOMER APPROVALS BANNER ---
                    if (customerProvider.pendingCount > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_add_rounded, color: Colors.amber, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${customerProvider.pendingCount} Customer Approval Request${customerProvider.pendingCount > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: AppColors.darkCharcoal,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'New accounts waiting for permission to order',
                                    style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.darkCharcoal,
                                foregroundColor: AppColors.primaryGold,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () => _showCustomerApprovalsModal(context),
                              child: const Text('Review', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                    // --- CATALOG & SHORTCUTS HEADER ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Catalog Overview',
                          style: TextStyle(
                            color: AppColors.darkCharcoal,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
                    const SizedBox(height: 12),

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
                    const SizedBox(height: 24),

                    // ==========================================
                    // --- LIVE CUSTOMER ORDERS MANAGEMENT ---
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Customer Orders',
                              style: TextStyle(
                                color: AppColors.darkCharcoal,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${orderProvider.filteredAdminOrders.length}',
                                style: const TextStyle(
                                  color: AppColors.darkCharcoal,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Total: ${orderProvider.totalOrdersCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- DATE FILTER STRIP ---
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDateFilterChip(
                            label: 'All Time',
                            filter: OrderDateFilter.all,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => orderProvider.setDateFilter(OrderDateFilter.all),
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: 'Today',
                            filter: OrderDateFilter.today,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => orderProvider.setDateFilter(OrderDateFilter.today),
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: 'This Week',
                            filter: OrderDateFilter.thisWeek,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => orderProvider.setDateFilter(OrderDateFilter.thisWeek),
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: 'This Month',
                            filter: OrderDateFilter.thisMonth,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => orderProvider.setDateFilter(OrderDateFilter.thisMonth),
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: orderProvider.customDateRange != null
                                ? '${orderProvider.customDateRange!.start.day}/${orderProvider.customDateRange!.start.month} - ${orderProvider.customDateRange!.end.day}/${orderProvider.customDateRange!.end.month}'
                                : 'Custom Range...',
                            filter: OrderDateFilter.custom,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => _pickCustomDateRange(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- STATUS FILTER STRIP ---
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusFilterChip('ALL', 'All', orderProvider),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip('PENDING', 'Pending (${orderProvider.pendingOrdersCount})', orderProvider),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip('CONFIRMED', 'Confirmed (${orderProvider.confirmedOrdersCount})', orderProvider),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip('DISPATCHED', 'Dispatched', orderProvider),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip('DELIVERED', 'Delivered (${orderProvider.deliveredOrdersCount})', orderProvider),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip('CANCELLED', 'Cancelled', orderProvider),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- ORDERS LIST ---
                    if (orderProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
                          ),
                        ),
                      )
                    else if (orderProvider.filteredAdminOrders.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No Orders Found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No customer orders match the selected date & status filter.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orderProvider.filteredAdminOrders.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = orderProvider.filteredAdminOrders[index];
                          return _buildOrderCard(order);
                        },
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ORDER CARD WIDGET ---
  Widget _buildOrderCard(OrderModel order) {
    Color badgeColor;
    Color badgeBg;
    IconData statusIcon;

    switch (order.status) {
      case 'CONFIRMED':
        badgeColor = Colors.blue.shade700;
        badgeBg = Colors.blue.shade50;
        statusIcon = Icons.thumb_up_alt_rounded;
        break;
      case 'DISPATCHED':
        badgeColor = Colors.deepPurple;
        badgeBg = Colors.deepPurple.shade50;
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'DELIVERED':
        badgeColor = Colors.green.shade700;
        badgeBg = Colors.green.shade50;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'CANCELLED':
        badgeColor = Colors.red.shade700;
        badgeBg = Colors.red.shade50;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'PENDING':
      default:
        badgeColor = Colors.amber.shade800;
        badgeBg = Colors.amber.shade50;
        statusIcon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Card Top Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (order.createdAt != null)
                      Text(
                        '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}',
                        style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        order.status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Snapshot
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade100,
                        child: order.productImage.isNotEmpty
                            ? Image.network(
                                order.productImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.precision_manufacturing_outlined,
                                  color: AppColors.primaryGold,
                                ),
                              )
                            : const Icon(
                                Icons.precision_manufacturing_outlined,
                                color: AppColors.primaryGold,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.companyName} • ${order.categoryName}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty: ${order.quantity}   •   ₹${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Customer Snapshot
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      order.userName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
                    ),
                    const Spacer(),
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      order.userPhone,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primaryGold),
                      tooltip: 'Copy Phone',
                      padding: const EdgeInsets.only(left: 6),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: order.userPhone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${order.userPhone} to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                if (order.shippingAddress != null && order.shippingAddress!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: AppColors.secondaryText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.shippingAddress!,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ],

                if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.secondaryText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '"${order.customerNote!}"',
                          style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkCharcoal,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showOrderStatusDialog(context, order),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text(
                        'Change Status',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip({
    required String label,
    required OrderDateFilter filter,
    required OrderDateFilter activeFilter,
    required VoidCallback onTap,
  }) {
    final isSelected = filter == activeFilter;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkCharcoal : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.darkCharcoal : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primaryGold : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(String status, String label, OrderProvider provider) {
    final isSelected = provider.statusFilter == status;
    return GestureDetector(
      onTap: () => provider.setStatusFilter(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.darkCharcoal : AppColors.secondaryText,
          ),
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
