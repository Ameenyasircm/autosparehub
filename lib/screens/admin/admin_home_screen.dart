import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/contact_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone_helper.dart';

/// Pure Order Management Operations Screen for Administrators.
/// Displays live customer orders with multi-parameter filtering, search,
/// direct customer contact intents, status workflows, and detailed breakdowns.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ContactService _contactService = ContactService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await Future.wait([
      context.read<OrderProvider>().fetchAdminOrders(),
      context.read<CategoryProvider>().fetchCategories(),
    ]);
  }

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
              primary: AppColors.darkHeader,
              onPrimary: AppColors.warmGold,
              surface: Colors.white,
              onSurface: AppColors.darkHeader,
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

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year • ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildTopAppBar(context, orderProvider),
      body: RefreshIndicator(
        color: AppColors.warmGold,
        backgroundColor: AppColors.darkHeader,
        onRefresh: _refreshData,
        child: Column(
          children: [
            // Sticky Filter & Search Control Panel
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Search Bar
                  _buildSearchBar(orderProvider),

                  const SizedBox(height: 10),

                  // 2. Status Filter Strip
                  _buildStatusFilterRow(orderProvider),

                  const SizedBox(height: 8),

                  // 3. Category & Date Filters Row
                  _buildSecondaryFiltersRow(orderProvider, categoryProvider),

                  // 4. Active Filters Indicator
                  if (_hasActiveFilters(orderProvider)) ...[
                    const SizedBox(height: 8),
                    _buildActiveFiltersBar(orderProvider),
                  ],
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFECEFF3)),

            // Orders List
            Expanded(
              child: orderProvider.isLoading
                  ? _buildLoadingState()
                  : orderProvider.filteredAdminOrders.isEmpty
                      ? _buildEmptyState(orderProvider)
                      : _buildOrdersList(orderProvider),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. TOP APP BAR (MATCHING USER SCREEN DESIGN SYSTEM)
  // =========================================================================
  PreferredSizeWidget _buildTopAppBar(BuildContext context, OrderProvider orderProvider) {
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
          // Brand Title: "AUTO SPARE HUB" with "ADMIN ORDERS"
          Column(
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
                'ADMIN ORDERS',
                style: TextStyle(
                  color: AppColors.warmGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Pending Orders Alert Chip (if any)
        if (orderProvider.pendingOrdersCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: InkWell(
              onTap: () => orderProvider.setStatusFilter('PENDING'),
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
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${orderProvider.pendingOrdersCount} PENDING',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Rounded Square Refresh Button
        Padding(
          padding: const EdgeInsets.only(right: 14, left: 8),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _refreshData,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF22262F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF303642), width: 1),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.warmGold,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. SEARCH BAR (MATCHING USER SCREEN PILL DESIGN)
  // =========================================================================
  Widget _buildSearchBar(OrderProvider orderProvider) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE1E6), width: 1.1),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => orderProvider.setCustomerFilter(val),
        style: const TextStyle(
          color: AppColors.darkHeader,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF8C95A6),
            size: 20,
          ),
          hintText: 'Search customer name, phone, or order #...',
          hintStyle: const TextStyle(
            color: Color(0xFF8C95A6),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF8C95A6)),
                  onPressed: () {
                    _searchController.clear();
                    orderProvider.setCustomerFilter('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  // =========================================================================
  // 3. STATUS FILTER ROW
  // =========================================================================
  Widget _buildStatusFilterRow(OrderProvider orderProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildStatusPill(
            label: 'All Orders',
            statusKey: 'ALL',
            count: orderProvider.totalOrdersCount,
            icon: Icons.all_inbox_rounded,
            color: AppColors.darkHeader,
            orderProvider: orderProvider,
          ),
          const SizedBox(width: 8),
          _buildStatusPill(
            label: 'Pending',
            statusKey: 'PENDING',
            count: orderProvider.pendingOrdersCount,
            icon: Icons.hourglass_top_rounded,
            color: Colors.amber.shade800,
            orderProvider: orderProvider,
          ),
          const SizedBox(width: 8),
          _buildStatusPill(
            label: 'Confirmed',
            statusKey: 'CONFIRMED',
            count: orderProvider.confirmedOrdersCount,
            icon: Icons.thumb_up_alt_rounded,
            color: Colors.blue.shade700,
            orderProvider: orderProvider,
          ),
          const SizedBox(width: 8),
          _buildStatusPill(
            label: 'Dispatched',
            statusKey: 'DISPATCHED',
            count: orderProvider.dispatchedOrdersCount,
            icon: Icons.local_shipping_rounded,
            color: Colors.deepPurple,
            orderProvider: orderProvider,
          ),
          const SizedBox(width: 8),
          _buildStatusPill(
            label: 'Delivered',
            statusKey: 'DELIVERED',
            count: orderProvider.deliveredOrdersCount,
            icon: Icons.check_circle_rounded,
            color: Colors.green.shade700,
            orderProvider: orderProvider,
          ),
          const SizedBox(width: 8),
          _buildStatusPill(
            label: 'Cancelled',
            statusKey: 'CANCELLED',
            count: orderProvider.cancelledOrdersCount,
            icon: Icons.cancel_rounded,
            color: Colors.red.shade700,
            orderProvider: orderProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required String statusKey,
    required int count,
    required IconData icon,
    required Color color,
    required OrderProvider orderProvider,
  }) {
    final bool isSelected = orderProvider.statusFilter == statusKey;

    return GestureDetector(
      onTap: () => orderProvider.setStatusFilter(statusKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkButton : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.warmGold : const Color(0xFFDDE1E6),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.5,
              color: isSelected ? AppColors.warmGold : color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.warmGold : const Color(0xFF2C323E),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.warmGold.withValues(alpha: 0.2)
                    : const Color(0xFFEDEFF2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppColors.warmGold : const Color(0xFF5A6271),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. SECONDARY FILTERS ROW (DATE & CATEGORY)
  // =========================================================================
  Widget _buildSecondaryFiltersRow(OrderProvider orderProvider, CategoryProvider categoryProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Date Filter Pills
          _buildFilterChip(
            label: 'All Time',
            isSelected: orderProvider.dateFilter == OrderDateFilter.all,
            icon: Icons.calendar_today_rounded,
            onTap: () => orderProvider.setDateFilter(OrderDateFilter.all),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'Today',
            isSelected: orderProvider.dateFilter == OrderDateFilter.today,
            onTap: () => orderProvider.setDateFilter(OrderDateFilter.today),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'This Week',
            isSelected: orderProvider.dateFilter == OrderDateFilter.thisWeek,
            onTap: () => orderProvider.setDateFilter(OrderDateFilter.thisWeek),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'This Month',
            isSelected: orderProvider.dateFilter == OrderDateFilter.thisMonth,
            onTap: () => orderProvider.setDateFilter(OrderDateFilter.thisMonth),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: orderProvider.customDateRange != null
                ? '${orderProvider.customDateRange!.start.day}/${orderProvider.customDateRange!.start.month} - ${orderProvider.customDateRange!.end.day}/${orderProvider.customDateRange!.end.month}'
                : 'Custom Date...',
            isSelected: orderProvider.dateFilter == OrderDateFilter.custom,
            icon: Icons.date_range_rounded,
            onTap: () => _pickCustomDateRange(context),
          ),
          const SizedBox(width: 10),
          Container(
            height: 16,
            width: 1,
            color: const Color(0xFFDDE1E6),
          ),
          const SizedBox(width: 10),

          // Category Chips
          _buildFilterChip(
            label: 'All Categories',
            isSelected: orderProvider.categoryFilter.toLowerCase() == 'all',
            onTap: () => orderProvider.setCategoryFilter('ALL'),
          ),
          ...categoryProvider.categories.map((cat) {
            final isSelected = orderProvider.categoryFilter.toLowerCase() == cat.name.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _buildFilterChip(
                label: cat.name,
                isSelected: isSelected,
                onTap: () => orderProvider.setCategoryFilter(cat.name),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF22262F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.warmGold : const Color(0xFFDDE1E6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 11,
                color: isSelected ? AppColors.warmGold : const Color(0xFF8C95A6),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.warmGold : const Color(0xFF5A6271),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasActiveFilters(OrderProvider orderProvider) {
    return orderProvider.customerFilter.isNotEmpty ||
        orderProvider.categoryFilter != 'ALL' ||
        orderProvider.statusFilter != 'ALL' ||
        orderProvider.dateFilter != OrderDateFilter.all;
  }

  Widget _buildActiveFiltersBar(OrderProvider orderProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.warmGold),
            const SizedBox(width: 4),
            Text(
              'Showing ${orderProvider.filteredAdminOrders.length} of ${orderProvider.totalOrdersCount} orders',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            _searchController.clear();
            orderProvider.resetAllFilters();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'Reset Filters',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 5. ORDERS LIST VIEW
  // =========================================================================
  Widget _buildOrdersList(OrderProvider orderProvider) {
    final orders = orderProvider.filteredAdminOrders;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index]);
      },
    );
  }

  // =========================================================================
  // 6. ORDER CARD (MATCHING USER APP ELEGANCE)
  // =========================================================================
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
        border: Border.all(color: const Color(0xFFEDEFF2), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header Bar: #ORD-XXXX + Date + Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFECEFF3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.darkHeader,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (order.createdAt != null)
                      Text(
                        _formatDateTime(order.createdAt!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
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
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Snapshot Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 54,
                        height: 54,
                        color: const Color(0xFFF4F6F9),
                        child: order.productImage.isNotEmpty
                            ? Image.network(
                                order.productImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.precision_manufacturing_outlined,
                                  color: AppColors.warmGold,
                                  size: 26,
                                ),
                              )
                            : const Icon(
                                Icons.precision_manufacturing_outlined,
                                color: AppColors.warmGold,
                                size: 26,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.items.length > 1
                                ? '${order.items.first.productName} & ${order.items.length - 1} more parts'
                                : order.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.darkHeader,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.items.length > 1
                                ? '${order.items.length} items total • ${order.totalItemUnits} units'
                                : '${order.companyName} • ${order.categoryName}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Units: ${order.totalItemUnits}   •   ₹${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.darkHeader,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFECEFF3)),
                const SizedBox(height: 10),

                // Customer Snapshot with Direct Call / WhatsApp Intents
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 15, color: AppColors.secondaryText),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        order.userName,
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

                    // Phone & Quick Contact Buttons
                    Text(
                      PhoneHelper.formatForDisplay(order.userPhone),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkHeader,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Call Button
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _contactService.launchPhoneCall(order.userPhone),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300, width: 0.8),
                        ),
                        child: Icon(Icons.phone_rounded, size: 13, color: Colors.green.shade800),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // WhatsApp Button
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _contactService.launchWhatsApp(
                        order.userPhone,
                        'Hello ${order.userName}, regarding your order ${order.orderNumber} at SN AutoSpare Hub Manjeri...',
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.teal.shade300, width: 0.8),
                        ),
                        child: Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Colors.teal.shade800),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Copy Phone
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: order.userPhone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${order.userPhone} to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDDE1E6), width: 0.8),
                        ),
                        child: const Icon(Icons.copy_rounded, size: 13, color: AppColors.secondaryText),
                      ),
                    ),
                  ],
                ),

                // Shipping address preview (if present)
                if (order.shippingAddress != null && order.shippingAddress!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.secondaryText),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          order.shippingAddress!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ],

                // Customer note preview (if present)
                if (order.customerNote != null && order.customerNote!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_rounded, size: 14, color: AppColors.secondaryText),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '"${order.customerNote!}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ],

                // Admin Remark Box (if present)
                if (order.adminRemark != null && order.adminRemark!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.warmGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.rate_review_rounded, size: 14, color: AppColors.warmGold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 11.5, color: AppColors.darkHeader),
                              children: [
                                const TextSpan(
                                  text: 'Admin Remark: ',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                TextSpan(
                                  text: order.adminRemark!,
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Card Actions: "View Details" + "Status & Remark"
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkHeader,
                        side: const BorderSide(color: Color(0xFFDDE1E6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showOrderDetailsSheet(context, order),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text(
                        'View Details',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkButton,
                        foregroundColor: AppColors.warmGold,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showOrderStatusDialog(context, order),
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text(
                        'Status & Remark',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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

  // =========================================================================
  // 7. ORDER DETAILS BREAKDOWN MODAL SHEET
  // =========================================================================
  void _showOrderDetailsSheet(BuildContext context, OrderModel order) {
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

    final items = order.distinctItems;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkHeader,
                        ),
                      ),
                      if (order.createdAt != null)
                        Text(
                          _formatDateTime(order.createdAt!),
                          style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: badgeColor),
                        const SizedBox(width: 4),
                        Text(
                          order.status,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFECEFF3)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Customer Information Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEDEFF2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkHeader,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 16, color: AppColors.secondaryText),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order.userName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded, size: 16, color: AppColors.secondaryText),
                            const SizedBox(width: 8),
                            Text(
                              PhoneHelper.formatForDisplay(order.userPhone),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.phone_forwarded_rounded, size: 16, color: Colors.green),
                              onPressed: () => _contactService.launchPhoneCall(order.userPhone),
                              tooltip: 'Call Customer',
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.teal),
                              onPressed: () => _contactService.launchWhatsApp(order.userPhone),
                              tooltip: 'WhatsApp Customer',
                            ),
                          ],
                        ),
                        if (order.shippingAddress != null && order.shippingAddress!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: AppColors.secondaryText),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.shippingAddress!,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFECEFF3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.secondaryText),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Customer Note: "${order.customerNote!}"',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Order Items Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEDEFF2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Order Items',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkHeader,
                              ),
                            ),
                            Text(
                              '${order.totalItemUnits} units in total',
                              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFECEFF3)),
                        const SizedBox(height: 10),

                        ...items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    color: const Color(0xFFF4F6F9),
                                    child: item.productImage.isNotEmpty
                                        ? Image.network(
                                            item.productImage,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const Icon(
                                              Icons.precision_manufacturing_outlined,
                                              color: AppColors.warmGold,
                                              size: 20,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.precision_manufacturing_outlined,
                                            color: AppColors.warmGold,
                                            size: 20,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      if (item.refNo != null && item.refNo!.isNotEmpty)
                                        Text(
                                          'Ref #: ${item.refNo}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                        ),
                                      Text(
                                        'Qty: ${item.quantity}  ×  ₹${item.unitPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${item.totalPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Total Calculation Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEDEFF2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grand Total',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkHeader,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Offline settlement upon delivery',
                              style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                        Text(
                          '₹${order.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkHeader,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Status & Remark Action
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkButton,
                        foregroundColor: AppColors.warmGold,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _showOrderStatusDialog(context, order);
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: const Text('Update Order Status & Remark', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 8. ORDER STATUS & REMARK SHEET
  // =========================================================================
  void _showOrderStatusDialog(BuildContext context, OrderModel order) {
    final orderProvider = context.read<OrderProvider>();
    const statuses = [
      {'status': 'PENDING', 'label': 'Pending Review', 'icon': Icons.hourglass_top_rounded, 'color': Colors.amber},
      {'status': 'CONFIRMED', 'label': 'Confirmed & Processing', 'icon': Icons.thumb_up_alt_rounded, 'color': Colors.blue},
      {'status': 'DISPATCHED', 'label': 'Dispatched for Delivery', 'icon': Icons.local_shipping_rounded, 'color': Colors.deepPurple},
      {'status': 'DELIVERED', 'label': 'Delivered Successfully', 'icon': Icons.check_circle_rounded, 'color': Colors.green},
      {'status': 'CANCELLED', 'label': 'Cancelled / Rejected', 'icon': Icons.cancel_rounded, 'color': Colors.red},
    ];

    final remarkController = TextEditingController(text: order.adminRemark ?? '');
    String selectedStatus = order.status;
    bool isSaving = false;

    const quickRemarks = [
      'Verified with customer',
      'Ready for store pickup',
      'Dispatched via transport',
      'Customer unreachable on phone',
      'Cancelled on customer request',
      'Out of stock / part unavailable',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Update Status & Remark',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.darkHeader),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${order.orderNumber} • ${order.userName}',
                                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.secondaryText),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFECEFF3)),
                    const SizedBox(height: 14),

                    const Text(
                      'ORDER STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...statuses.map((s) {
                      final isSelected = selectedStatus == s['status'];
                      final color = s['color'] as Color;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setSheetState(() {
                              selectedStatus = s['status'] as String;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : const Color(0xFFEDEFF2),
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(s['icon'] as IconData, color: color, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s['label'] as String,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? AppColors.darkHeader : Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: color, size: 20)
                                else
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ADMIN REMARK / NOTE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        if (remarkController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                remarkController.clear();
                              });
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Remark Suggestion Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: quickRemarks.map((q) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 8),
                            child: ActionChip(
                              label: Text(
                                q,
                                style: const TextStyle(fontSize: 11, color: AppColors.darkHeader),
                              ),
                              backgroundColor: const Color(0xFFF4F6F9),
                              side: const BorderSide(color: Color(0xFFDDE1E6)),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () {
                                setSheetState(() {
                                  remarkController.text = q;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    TextField(
                      controller: remarkController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13, color: AppColors.darkHeader),
                      decoration: InputDecoration(
                        hintText: 'e.g. Called customer, confirmed delivery timing...',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.all(12),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.warmGold, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.darkHeader,
                              side: const BorderSide(color: Color(0xFFDDE1E6)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSaving ? null : () => Navigator.pop(sheetCtx),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.darkButton,
                              foregroundColor: AppColors.warmGold,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setSheetState(() => isSaving = true);
                                    final finalRemark = remarkController.text.trim();
                                    final ok = await orderProvider.updateOrderStatus(
                                      order.id,
                                      selectedStatus,
                                      adminRemark: finalRemark,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(sheetCtx);
                                      if (ok) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Order ${order.orderNumber} updated to $selectedStatus'),
                                            backgroundColor: AppColors.darkHeader,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to update order status.'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warmGold),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              isSaving ? 'Updating...' : 'Save Status & Remark',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 9. LOADING AND EMPTY STATES
  // =========================================================================
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.warmGold),
          ),
          SizedBox(height: 14),
          Text(
            'Loading orders...',
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

  Widget _buildEmptyState(OrderProvider orderProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F6F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: Color(0xFF8C95A6),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Orders Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.darkHeader,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _hasActiveFilters(orderProvider)
                  ? 'No customer orders match the applied search or filter criteria.'
                  : 'No customer orders have been received yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
            if (_hasActiveFilters(orderProvider)) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkButton,
                  foregroundColor: AppColors.warmGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
                onPressed: () {
                  _searchController.clear();
                  orderProvider.resetAllFilters();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset All Filters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
