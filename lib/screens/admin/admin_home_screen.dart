import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/contact_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone_helper.dart';
import '../../utils/responsive_helper.dart';

/// Pure Order Management Operations Screen for Administrators.
/// Displays live customer orders with multi-parameter filtering, search,
/// direct customer contact intents, status workflows, and detailed breakdowns.
class AdminHomeScreen extends StatefulWidget {
  final bool isTablet;
  const AdminHomeScreen({super.key, this.isTablet = false});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ContactService _contactService = ContactService();
  OrderModel? _selectedOrder;

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
    context.read<OrderProvider>().startListeningAdminOrders();
    await Future.wait([
      context.read<OrderProvider>().fetchAdminOrders(),
      context.read<CategoryProvider>().fetchCategories(),
    ]);
  }

  Future<void> _pickCalendarDate(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();
    final initialDate = orderProvider.particularDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'SELECT ORDER DATE',
      confirmText: 'FILTER',
      cancelText: 'CANCEL',
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
      orderProvider.setParticularDate(picked);
    }
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

  String _formatParticularDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final isWide = ResponsiveHelper.isWideTablet(context);
    final orders = orderProvider.filteredAdminOrders;

    if (orders.isNotEmpty) {
      if (_selectedOrder == null || !orders.any((o) => o.id == _selectedOrder!.id)) {
        _selectedOrder = orders.first;
      } else {
        _selectedOrder = orders.firstWhere((o) => o.id == _selectedOrder!.id);
      }
    } else {
      _selectedOrder = null;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildTopAppBar(context, orderProvider),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.warmGold,
          backgroundColor: AppColors.darkHeader,
          onRefresh: _refreshData,
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Pane: Filters & Orders List (390px)
                    SizedBox(
                      width: 390,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            right: BorderSide(color: Color(0xFFECEFF3), width: 1.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildFilterHeader(orderProvider, categoryProvider),
                            const Divider(height: 1, thickness: 1, color: Color(0xFFECEFF3)),
                            Expanded(
                              child: orderProvider.isLoading
                                  ? _buildLoadingState()
                                  : orders.isEmpty
                                      ? _buildEmptyState(orderProvider)
                                      : _buildOrdersList(orderProvider, isWideMaster: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right Pane: Detail view
                    Expanded(
                      child: _selectedOrder == null
                          ? _buildNoOrderSelected()
                          : _buildTabletDetailPane(_selectedOrder!, orderProvider),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildFilterHeader(orderProvider, categoryProvider),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFECEFF3)),
                    Expanded(
                      child: orderProvider.isLoading
                          ? _buildLoadingState()
                          : orders.isEmpty
                              ? _buildEmptyState(orderProvider)
                              : _buildOrdersList(orderProvider),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFilterHeader(OrderProvider orderProvider, CategoryProvider categoryProvider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _buildSearchBar(orderProvider)),
              const SizedBox(width: 8),
              _buildFilterButton(orderProvider, categoryProvider),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatusFilterRow(orderProvider),
          if (_hasActiveFilters(orderProvider)) ...[
            const SizedBox(height: 6),
            _buildActiveFiltersBar(orderProvider),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // 1. TOP APP BAR (MATCHING USER SCREEN DESIGN SYSTEM)
  // =========================================================================
  PreferredSizeWidget _buildTopAppBar(BuildContext context, OrderProvider orderProvider) {
    final isTablet = widget.isTablet || ResponsiveHelper.isTablet(context);

    if (isTablet) {
      return AppBar(
        backgroundColor: AppColors.darkHeader,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Customer Orders',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: AppColors.warmGold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.5)),
              ),
              child: Text(
                '${orderProvider.adminOrders.length} Total',
                style: const TextStyle(
                  color: AppColors.lightGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD97706)),
              ),
              child: Text(
                '${orderProvider.pendingOrdersCount} Pending',
                style: const TextStyle(
                  color: Color(0xFFFDE68A),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.lightGold),
            tooltip: 'Refresh Orders',
            onPressed: _refreshData,
          ),
          const SizedBox(width: 14),
        ],
      );
    }

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
  // 2. SEARCH BAR & FILTER BUTTON
  // =========================================================================
  Widget _buildSearchBar(OrderProvider orderProvider) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE1E6), width: 1.1),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => orderProvider.setCustomerFilter(val),
        style: const TextStyle(
          color: AppColors.darkHeader,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF8C95A6),
            size: 18,
          ),
          hintText: 'Search customer, phone, order #...',
          hintStyle: const TextStyle(
            color: Color(0xFF8C95A6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF8C95A6)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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

  Widget _buildFilterButton(OrderProvider orderProvider, CategoryProvider categoryProvider) {
    final hasDateFilter = orderProvider.dateFilter != OrderDateFilter.all;
    final hasCategoryFilter = orderProvider.categoryFilter.toUpperCase() != 'ALL';
    final activeCount = (hasDateFilter ? 1 : 0) + (hasCategoryFilter ? 1 : 0);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _showFiltersSheet(context),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: activeCount > 0 ? AppColors.darkButton : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: activeCount > 0 ? AppColors.warmGold : const Color(0xFFDDE1E6),
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: activeCount > 0 ? AppColors.warmGold : const Color(0xFF5A6271),
            ),
            const SizedBox(width: 5),
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: activeCount > 0 ? AppColors.warmGold : const Color(0xFF2C323E),
              ),
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: const BoxDecoration(
                  color: AppColors.warmGold,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$activeCount',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkHeader,
                  ),
                ),
              ),
            ],
          ],
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
            label: 'Completed',
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
  // 4. SECONDARY FILTERS MODAL SHEET (DATE & CATEGORY)
  // =========================================================================
  void _showFiltersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Consumer2<OrderProvider, CategoryProvider>(
        builder: (ctx, orderProvider, categoryProvider, _) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header with Title & Reset Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Orders',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkHeader,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            orderProvider.setDateFilter(OrderDateFilter.all);
                            orderProvider.setCategoryFilter('ALL');
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1, color: AppColors.dividerLight),
                    const SizedBox(height: 14),

                    // Section 1: Date Range
                    const Text(
                      'DATE RANGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondaryText,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'All Time',
                          isSelected: orderProvider.dateFilter == OrderDateFilter.all,
                          icon: Icons.calendar_today_rounded,
                          onTap: () => orderProvider.setDateFilter(OrderDateFilter.all),
                        ),
                        _buildFilterChip(
                          label: 'Today',
                          isSelected: orderProvider.dateFilter == OrderDateFilter.today,
                          onTap: () => orderProvider.setDateFilter(OrderDateFilter.today),
                        ),
                        _buildFilterChip(
                          label: 'This Week',
                          isSelected: orderProvider.dateFilter == OrderDateFilter.thisWeek,
                          onTap: () => orderProvider.setDateFilter(OrderDateFilter.thisWeek),
                        ),
                        _buildFilterChip(
                          label: 'This Month',
                          isSelected: orderProvider.dateFilter == OrderDateFilter.thisMonth,
                          onTap: () => orderProvider.setDateFilter(OrderDateFilter.thisMonth),
                        ),
                        _buildFilterChip(
                          label: orderProvider.dateFilter == OrderDateFilter.particularDate &&
                                  orderProvider.particularDate != null
                              ? _formatParticularDate(orderProvider.particularDate!)
                              : 'Select Date',
                          isSelected: orderProvider.dateFilter == OrderDateFilter.particularDate,
                          icon: Icons.calendar_month_rounded,
                          onTap: () => _pickCalendarDate(context),
                          onClear: orderProvider.dateFilter == OrderDateFilter.particularDate
                              ? () => orderProvider.setParticularDate(null)
                              : null,
                        ),
                        _buildFilterChip(
                          label: orderProvider.dateFilter == OrderDateFilter.custom &&
                                  orderProvider.customDateRange != null
                              ? '${orderProvider.customDateRange!.start.day}/${orderProvider.customDateRange!.start.month} - ${orderProvider.customDateRange!.end.day}/${orderProvider.customDateRange!.end.month}'
                              : 'Date Range...',
                          isSelected: orderProvider.dateFilter == OrderDateFilter.custom,
                          icon: Icons.date_range_rounded,
                          onTap: () => _pickCustomDateRange(context),
                          onClear: orderProvider.dateFilter == OrderDateFilter.custom
                              ? () => orderProvider.setDateFilter(OrderDateFilter.all)
                              : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Section 2: Category
                    const Text(
                      'CATEGORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondaryText,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'All Categories',
                          isSelected: orderProvider.categoryFilter.toLowerCase() == 'all',
                          onTap: () => orderProvider.setCategoryFilter('ALL'),
                        ),
                        ...categoryProvider.categories.map((cat) {
                          final isSelected = orderProvider.categoryFilter.toLowerCase() == cat.name.toLowerCase();
                          return _buildFilterChip(
                            label: cat.name,
                            isSelected: isSelected,
                            onTap: () => orderProvider.setCategoryFilter(cat.name),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkButton,
                          foregroundColor: AppColors.warmGold,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    IconData? icon,
    VoidCallback? onClear,
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
            if (isSelected && onClear != null) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: AppColors.warmGold.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 11,
                    color: AppColors.warmGold,
                  ),
                ),
              ),
            ],
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
    String? dateTag;
    if (orderProvider.dateFilter == OrderDateFilter.today) {
      dateTag = 'Today';
    } else if (orderProvider.dateFilter == OrderDateFilter.thisWeek) {
      dateTag = 'This Week';
    } else if (orderProvider.dateFilter == OrderDateFilter.thisMonth) {
      dateTag = 'This Month';
    } else if (orderProvider.dateFilter == OrderDateFilter.particularDate &&
        orderProvider.particularDate != null) {
      dateTag = _formatParticularDate(orderProvider.particularDate!);
    } else if (orderProvider.dateFilter == OrderDateFilter.custom &&
        orderProvider.customDateRange != null) {
      dateTag =
          '${orderProvider.customDateRange!.start.day}/${orderProvider.customDateRange!.start.month} - ${orderProvider.customDateRange!.end.day}/${orderProvider.customDateRange!.end.month}';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.warmGold),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  dateTag != null
                      ? 'Showing ${orderProvider.filteredAdminOrders.length} of ${orderProvider.totalOrdersCount} ($dateTag)'
                      : 'Showing ${orderProvider.filteredAdminOrders.length} of ${orderProvider.totalOrdersCount} orders',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
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
  Widget _buildOrdersList(OrderProvider orderProvider, {bool isWideMaster = false}) {
    final orders = orderProvider.filteredAdminOrders;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final order = orders[index];
        final isSelected = isWideMaster && _selectedOrder?.id == order.id;
        return _buildOrderCard(order, index + 1, isSelected: isSelected);
      },
    );
  }

  // =========================================================================
  // 6. ORDER CARD (COMPACT, MODERN & STREAMLINED)
  // =========================================================================
  Widget _buildOrderCard(OrderModel order, int serialNumber, {bool isSelected = false}) {
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

    return InkWell(
      onTap: () {
        if (ResponsiveHelper.isWideTablet(context)) {
          setState(() => _selectedOrder = order);
        } else {
          _showOrderDetailsSheet(context, order);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.warmGold.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.warmGold, width: 2)
              : Border.all(color: AppColors.borderSoft),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.warmGold.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 8 : 6,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Header: Serial # + Order # + Date + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.darkCharcoal.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$serialNumber',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ),
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: AppColors.darkHeader,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (order.createdAt != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '• ${_formatDateTime(order.createdAt!)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: badgeColor),
                      const SizedBox(width: 3),
                      Text(
                        order.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 2. Middle Row: Product Image + Product Name / Items Count + Total Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Compact thumbnail (38x38)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 38,
                    height: 38,
                    color: const Color(0xFFF4F6F9),
                    child: order.productImage.isNotEmpty
                        ? Image.network(
                            order.productImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
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

                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        order.items.length > 1
                            ? '${order.items.first.productName} +${order.items.length - 1} more'
                            : order.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.darkHeader,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        order.items.length > 1
                            ? '${order.items.length} items • ${order.totalItemUnits} units total'
                            : '${order.companyName} • ${order.totalItemUnits} unit${order.totalItemUnits > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Amount
                Text(
                  '₹${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkHeader,
                  ),
                ),
              ],
            ),

            // Admin Remark (if present)
            if (order.adminRemark != null && order.adminRemark!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warmGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_rounded, size: 12, color: AppColors.darkHeader),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Remark: ${order.adminRemark!}',
                        style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.darkHeader),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.dividerLight),
            const SizedBox(height: 8),

            // 3. Footer Row: Customer info + quick Call & WhatsApp + Status button
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.secondaryText),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkHeader,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Call Button
                Tooltip(
                  message: 'Call ${order.userName}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _contactService.launchPhoneCall(order.userPhone),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.darkCharcoal.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderSoft, width: 0.8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.phone_in_talk_rounded, size: 13, color: AppColors.darkCharcoal),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // WhatsApp Button
                Tooltip(
                  message: 'WhatsApp ${order.userName}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _contactService.launchWhatsApp(
                      order.userPhone,
                      order.toWhatsAppMessage(),
                    ),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3), width: 0.8),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/member_whats_app.png',
                        width: 14,
                        height: 14,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Status Button
                SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkButton,
                      foregroundColor: AppColors.warmGold,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showOrderStatusDialog(context, order),
                    icon: const Icon(Icons.edit_note_rounded, size: 14),
                    label: const Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                              icon: Image.asset(
                                'assets/member_whats_app.png',
                                width: 18,
                                height: 18,
                                fit: BoxFit.contain,
                              ),
                              onPressed: () => _contactService.launchWhatsApp(
                                order.userPhone,
                                order.toWhatsAppMessage(),
                              ),
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
                                          'Sorl #: ${item.refNo}',
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
  // --- TABLET MASTER-DETAIL RIGHT PANE ---
  // =========================================================================
  Widget _buildTabletDetailPane(OrderModel order, OrderProvider orderProvider) {
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

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Detail Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFECEFF3), width: 1.2),
              ),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkHeader,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.secondaryText),
                          tooltip: 'Copy Order Number',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: order.orderNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order number copied: ${order.orderNumber}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (order.createdAt != null)
                      Text(
                        'Placed on ${_formatDateTime(order.createdAt!)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                  ],
                ),
                const Spacer(),
                // Status Badge
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
                      Icon(statusIcon, size: 15, color: badgeColor),
                      const SizedBox(width: 5),
                      Text(
                        order.status,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkButton,
                    foregroundColor: AppColors.warmGold,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => _showOrderStatusDialog(context, order),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text(
                    'Change Status',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Detail Cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Customer and Financial Summary side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Card
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEDEFF2)),
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
                            const Text(
                              'Customer Information',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkHeader,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 17, color: AppColors.secondaryText),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.userName,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone_rounded, size: 17, color: AppColors.secondaryText),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    PhoneHelper.formatForDisplay(order.userPhone),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green.shade700,
                                    side: BorderSide(color: Colors.green.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _contactService.launchPhoneCall(order.userPhone),
                                  icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                                  label: const Text('Call', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _contactService.launchWhatsApp(
                                    order.userPhone,
                                    order.toWhatsAppMessage(),
                                  ),
                                  icon: Image.asset(
                                    'assets/member_whats_app.png',
                                    width: 14,
                                    height: 14,
                                    color: Colors.white,
                                    errorBuilder: (c, e, s) => const Icon(Icons.chat_bubble, size: 14, color: Colors.white),
                                  ),
                                  label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                ),
                              ],
                            ),
                            if (order.shippingAddress != null && order.shippingAddress!.isNotEmpty) ...[
                              const SizedBox(height: 10),
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
                                    const Icon(Icons.location_on_rounded, size: 16, color: AppColors.secondaryText),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Delivery: ${order.shippingAddress!}',
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFFD97706)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Customer Note: "${order.customerNote!}"',
                                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF92400E)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (order.adminRemark != null && order.adminRemark!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.support_agent_rounded, size: 15, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Admin Remark: "${order.adminRemark!}"',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Order Financial Summary Card
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEDEFF2)),
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
                            const Text(
                              'Payment & Fulfillment',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkHeader,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text('Total Distinct Parts', style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText)),
                                ),
                                const SizedBox(width: 8),
                                Text('${items.length}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text('Total Units Ordered', style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText)),
                                ),
                                const SizedBox(width: 8),
                                Text('${order.totalItemUnits} pcs', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ],
                            ),
                            const Divider(height: 18, color: Color(0xFFECEFF3)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Estimated Total',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkHeader,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '₹ ${order.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.darkCharcoal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.darkHeader),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Direct store confirmation & fulfillment.',
                                      style: TextStyle(fontSize: 11, color: AppColors.darkHeader, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Order Items Breakdown Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEDEFF2)),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ordered Spare Parts',
                            style: TextStyle(
                              fontSize: 14,
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
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  color: const Color(0xFFF4F6F9),
                                  child: item.productImage.isNotEmpty
                                      ? Image.network(
                                          item.productImage,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => const Icon(
                                            Icons.precision_manufacturing_outlined,
                                            color: AppColors.warmGold,
                                            size: 22,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.precision_manufacturing_outlined,
                                          color: AppColors.warmGold,
                                          size: 22,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkHeader),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 4,
                                      children: [
                                        if (item.companyName.isNotEmpty) ...[
                                          Text(
                                            item.companyName,
                                            style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                                          ),
                                          const Text('•', style: TextStyle(color: AppColors.secondaryText, fontSize: 10)),
                                        ],
                                        Text(
                                          'Qty: ${item.quantity}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.darkCharcoal, fontWeight: FontWeight.w700),
                                        ),
                                        if (item.refNo != null && item.refNo!.isNotEmpty) ...[
                                          const Text('•', style: TextStyle(color: AppColors.secondaryText, fontSize: 10)),
                                          Text(
                                            'Ref: ${item.refNo}',
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹ ${item.totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkHeader),
                                  ),
                                  if (item.quantity > 1 && item.unitPrice > 0)
                                    Text(
                                      '₹ ${item.unitPrice.toStringAsFixed(0)} ea',
                                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoOrderSelected() {
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.touch_app_rounded, size: 54, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text(
            'Select an order to view full details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryText,
            ),
          ),
        ],
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
      {'status': 'CONFIRMED', 'label': 'Confirmed & Ready for Pickup', 'icon': Icons.thumb_up_alt_rounded, 'color': Colors.blue},
      {'status': 'DELIVERED', 'label': 'Completed / Collected', 'icon': Icons.check_circle_rounded, 'color': Colors.green},
      {'status': 'CANCELLED', 'label': 'Cancelled / Rejected', 'icon': Icons.cancel_rounded, 'color': Colors.red},
    ];

    final remarkController = TextEditingController(text: order.adminRemark ?? '');
    String selectedStatus = order.status;
    bool isSaving = false;

    const quickRemarks = [
      'Verified with customer',
      'Ready for store pickup',
      'Verified & packed for counter pickup',
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
