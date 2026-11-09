import 'package:flutter/material.dart';
import 'package:auto_spare_hub/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';
import 'user_login_screen.dart';
import 'widgets/change_password_dialog.dart';

/// Visual styling metadata for each order status in customer-facing screens.
class OrderStatusVisuals {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;

  const OrderStatusVisuals({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  static OrderStatusVisuals fromStatus(String rawStatus) {
    switch (rawStatus.toUpperCase()) {
      case 'PENDING':
        return const OrderStatusVisuals(
          key: 'PENDING',
          label: 'Requested',
          description: 'Order placed. Waiting for store review and confirmation.',
          icon: Icons.hourglass_top_rounded,
          primaryColor: Color(0xFFD97706), // Warm amber
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFFDE68A),
        );
      case 'CONFIRMED':
        return const OrderStatusVisuals(
          key: 'CONFIRMED',
          label: 'Confirmed',
          description: 'Order accepted! Parts verified & ready for store pickup.',
          icon: Icons.check_circle_outline_rounded,
          primaryColor: Color(0xFF0284C7), // Ocean sky blue
          backgroundColor: Color(0xFFE0F2FE),
          borderColor: Color(0xFFBAE6FD),
        );
      case 'DISPATCHED':
        return const OrderStatusVisuals(
          key: 'DISPATCHED',
          label: 'Ready for Pickup',
          description: 'Parts packed & ready for direct store pickup.',
          icon: Icons.storefront_rounded,
          primaryColor: Color(0xFF7C3AED), // Deep purple
          backgroundColor: Color(0xFFEDE9FE),
          borderColor: Color(0xFFDDD6FE),
        );
      case 'DELIVERED':
        return const OrderStatusVisuals(
          key: 'DELIVERED',
          label: 'Completed',
          description: 'Order fulfilled & collected from store. Thank you!',
          icon: Icons.task_alt_rounded,
          primaryColor: Color(0xFF059669), // Emerald green
          backgroundColor: Color(0xFFD1FAE5),
          borderColor: Color(0xFFA7F3D0),
        );
      case 'CANCELLED':
        return const OrderStatusVisuals(
          key: 'CANCELLED',
          label: 'Cancelled',
          description: 'Order cancelled or rejected.',
          icon: Icons.cancel_outlined,
          primaryColor: Color(0xFFDC2626), // Rose red
          backgroundColor: Color(0xFFFEE2E2),
          borderColor: Color(0xFFFECACA),
        );
      default:
        return OrderStatusVisuals(
          key: rawStatus.toUpperCase(),
          label: rawStatus.isEmpty ? 'Pending' : rawStatus,
          description: 'Order status update pending.',
          icon: Icons.help_outline_rounded,
          primaryColor: AppColors.secondaryGold,
          backgroundColor: AppColors.secondaryGold.withValues(alpha: 0.12),
          borderColor: AppColors.secondaryGold.withValues(alpha: 0.3),
        );
    }
  }
}

/// Customer screen displaying the history, live status, and detailed itemized
/// breakdowns of placed automotive spare part orders.
class UserOrdersScreen extends StatefulWidget {
  final bool showAppBar;
  const UserOrdersScreen({super.key, this.showAppBar = true});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen> {
  bool _isRefreshing = false;

  /// Manual refresh (button). Orders are also live, this just forces a fresh read.
  Future<void> _refreshOrders() async {
    final customer = context.read<UserAuthProvider>().currentCustomer;
    if (customer == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    await context
        .read<OrderProvider>()
        .fetchCustomerOrders(customer.id, userPhone: customer.phone);
    if (mounted) setState(() => _isRefreshing = false);
  }

  Widget _buildRefreshButton({Color color = AppColors.darkHeader}) {
    return IconButton(
      tooltip: 'Refresh orders',
      onPressed: _isRefreshing ? null : _refreshOrders,
      icon: _isRefreshing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(Icons.refresh_rounded, color: color),
    );
  }

  String? _lastFetchedCustomerId;
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFetchOrders(force: true);
    });
  }

  void _checkAndFetchOrders({bool force = false}) {
    if (!mounted) return;
    final customer = context.read<UserAuthProvider>().currentCustomer;
    if (customer != null && (force || _lastFetchedCustomerId != customer.id)) {
      _lastFetchedCustomerId = customer.id;
      context.read<OrderProvider>().listenToCustomerOrders(customer.id, userPhone: customer.phone);
    }
  }

  void _showOrderDetailsSheet(BuildContext context, OrderModel order) {
    final visuals = OrderStatusVisuals.fromStatus(order.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
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
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      if (order.createdAt != null)
                        Text(
                          'Placed on ${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year} at ${order.createdAt!.hour.toString().padLeft(2, '0')}:${order.createdAt!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: visuals.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: visuals.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(visuals.icon, size: 13, color: visuals.primaryColor),
                        const SizedBox(width: 5),
                        Text(
                          visuals.label,
                          style: TextStyle(
                            color: visuals.primaryColor,
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
            const Divider(height: 1, color: AppColors.dividerLight),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Explanation Banner
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: visuals.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: visuals.borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: visuals.borderColor),
                            ),
                            child: Icon(visuals.icon, color: visuals.primaryColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status: ${visuals.label}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: visuals.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  visuals.description,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: visuals.primaryColor.withValues(alpha: 0.9),
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- ORDERED ITEMS LIST ---
                    Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: AppColors.primaryGold, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Ordered Spare Parts (${order.distinctItems.length} items)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.distinctItems.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = order.distinctItems[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey.shade100,
                                  child: item.productImage.isNotEmpty
                                      ? Image.network(
                                          item.productImage,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Icon(
                                            Icons.car_repair_rounded,
                                            color: AppColors.primaryGold,
                                          ),
                                        )
                                      : const Icon(Icons.car_repair_rounded, color: AppColors.primaryGold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.companyName} • ${item.categoryName}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                    ),
                                    if (item.refNo != null && item.refNo!.isNotEmpty)
                                      Text(
                                        'Sorl #: ${item.refNo}',
                                        style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Qty: ${item.quantity}   •   ₹ ${item.unitPrice.toStringAsFixed(0)} each',
                                      style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹ ${item.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // --- SHIPPING & DELIVERY INFO ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.handshake_outlined, color: AppColors.primaryGold, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Fulfillment & Contact',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.dividerLight),
                          const SizedBox(height: 10),
                          Text(
                            order.shippingAddress != null && order.shippingAddress!.isNotEmpty
                                ? order.shippingAddress!
                                : 'Direct Pickup / Phone Confirmation (No Delivery)',
                            style: const TextStyle(fontSize: 13, color: AppColors.darkCharcoal, height: 1.3),
                          ),
                          if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.note_alt_outlined, size: 16, color: AppColors.secondaryText),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Note: "${order.customerNote!}"',
                                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.secondaryText),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (order.adminRemark != null && order.adminRemark!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.primaryGold),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Admin Update / Remark:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.darkCharcoal,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          order.adminRemark!,
                                          style: const TextStyle(fontSize: 12.5, color: AppColors.darkCharcoal),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- PAYMENT & TOTAL SUMMARY ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Units (${order.totalItemUnits} pcs)',
                                style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                              ),
                              Text(
                                '₹ ${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: AppColors.dividerLight),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                              Text(
                                '₹ ${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<UserAuthProvider>();
    final customer = auth.currentCustomer;
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.customerOrders;

    final filteredOrders = _selectedStatusFilter == 'ALL'
        ? orders
        : orders.where((o) {
            switch (_selectedStatusFilter) {
              case 'PENDING':
                return o.isPending;
              case 'CONFIRMED':
                return o.isConfirmed;
              case 'DISPATCHED':
                return o.isDispatched;
              case 'DELIVERED':
                return o.isDelivered;
              case 'CANCELLED':
                return o.isCancelled;
              default:
                return true;
            }
          }).toList();

    if (customer != null && _lastFetchedCustomerId != customer.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndFetchOrders();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: AppColors.darkHeader,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'My Spare Part Orders',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
              ),
              actions: [
                _buildRefreshButton(color: Colors.white),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: 'Account Options',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    if (value == 'change_password') {
                      ChangeUserPasswordDialog.show(context);
                    } else if (value == 'logout') {
                      final auth = context.read<UserAuthProvider>();
                      await auth.logout();
                      if (context.mounted) {
                        context.read<CartProvider>().onUserLogout();
                        context.read<OrderProvider>().clearCustomerOrders();
                        _lastFetchedCustomerId = null;
                        _selectedStatusFilter = 'ALL';
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBarAutoHide(
                          const SnackBar(content: Text('Logged out successfully.')),
                        );
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'change_password',
                      child: Row(
                        children: const [
                          Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.primaryGold),
                          SizedBox(width: 8),
                          Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: const [
                          Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: SafeArea(
        top: !widget.showAppBar,
        child: !auth.isSessionInitialized
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.warmGold),
                  SizedBox(height: 14),
                  Text(
                    'Loading account...',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : customer == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppColors.darkButton,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.warmGold,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'View Your Orders',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkHeader,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Log in to check your orders, track their status, and read delivery updates.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
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
                              'Login to View Orders',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                      ],
                    ),
                  ),
                )
              : orders.isEmpty
                  ? RefreshIndicator(
                      color: AppColors.primaryGold,
                      backgroundColor: AppColors.darkCharcoal,
                      onRefresh: () => orderProvider.fetchCustomerOrders(customer.id, userPhone: customer.phone),
                      child: orderProvider.isCustomerOrdersLoading
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: AppColors.warmGold),
                                  SizedBox(height: 14),
                                  Text(
                                    'Loading your orders...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.secondaryText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              child: Container(
                                alignment: Alignment.center,
                                height: MediaQuery.of(context).size.height * 0.65,
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.shopping_bag_outlined, size: 54, color: Colors.grey),
                                    SizedBox(height: 14),
                                    Text(
                                      'No Orders Placed Yet',
                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'When you order automotive spare parts, their tracking status will appear here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                    SizedBox(height: 12),
                                    _EmptyOrdersRefreshSlot(),
                                  ],
                                ),
                              ),
                            ),
                    )
                  : Column(
                      children: [
                        // Horizontal Status Filter Row
                        _buildStatusFilterBar(orders),

                        // Filtered Orders List or Empty Filter Notice
                        Expanded(
                          child: RefreshIndicator(
                            color: AppColors.primaryGold,
                            backgroundColor: AppColors.darkCharcoal,
                            onRefresh: () => orderProvider.fetchCustomerOrders(customer.id, userPhone: customer.phone),
                            child: filteredOrders.isEmpty
                                ? SingleChildScrollView(
                                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                    child: Container(
                                      alignment: Alignment.center,
                                      height: MediaQuery.of(context).size.height * 0.55,
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: OrderStatusVisuals.fromStatus(_selectedStatusFilter).backgroundColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: OrderStatusVisuals.fromStatus(_selectedStatusFilter).borderColor,
                                              ),
                                            ),
                                            child: Icon(
                                              OrderStatusVisuals.fromStatus(_selectedStatusFilter).icon,
                                              size: 36,
                                              color: OrderStatusVisuals.fromStatus(_selectedStatusFilter).primaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No ${OrderStatusVisuals.fromStatus(_selectedStatusFilter).label} Orders',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.darkCharcoal,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'You currently do not have any orders with status "${OrderStatusVisuals.fromStatus(_selectedStatusFilter).label}".',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12.5),
                                          ),
                                          const SizedBox(height: 18),
                                          OutlinedButton.icon(
                                            onPressed: () => setState(() => _selectedStatusFilter = 'ALL'),
                                            icon: const Icon(Icons.all_inbox_rounded, size: 16),
                                            label: const Text('Show All Orders'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.darkCharcoal,
                                              side: const BorderSide(color: AppColors.primaryGold),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                    itemCount: filteredOrders.length,
                                    itemBuilder: (context, index) {
                                      final order = filteredOrders[index];
                                      return _buildOrderCard(order);
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
      ),
    );
  }

  /// Builds the horizontal status filter row with counts and distinct status colors.
  Widget _buildStatusFilterBar(List<OrderModel> allOrders) {
    final totalCount = allOrders.length;
    final pendingCount = allOrders.where((o) => o.isPending).length;
    final confirmedCount = allOrders.where((o) => o.isConfirmed).length;
    final deliveredCount = allOrders.where((o) => o.isDelivered).length;
    final cancelledCount = allOrders.where((o) => o.isCancelled).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.dividerLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          children: [
            _buildFilterPill(
              label: 'All',
              filterKey: 'ALL',
              count: totalCount,
              icon: Icons.all_inbox_rounded,
              color: AppColors.darkHeader,
            ),
            const SizedBox(width: 8),
            _buildFilterPill(
              label: 'Requested',
              filterKey: 'PENDING',
              count: pendingCount,
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFD97706),
            ),
            const SizedBox(width: 8),
            _buildFilterPill(
              label: 'Confirmed',
              filterKey: 'CONFIRMED',
              count: confirmedCount,
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF0284C7),
            ),
            const SizedBox(width: 8),
            _buildFilterPill(
              label: 'Completed',
              filterKey: 'DELIVERED',
              count: deliveredCount,
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF059669),
            ),
            const SizedBox(width: 8),
            _buildFilterPill(
              label: 'Cancelled',
              filterKey: 'CANCELLED',
              count: cancelledCount,
              icon: Icons.cancel_outlined,
              color: const Color(0xFFDC2626),
            ),
          ],
        ),
            ),
          ),
          _buildRefreshButton(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Individual status filter button with responsive selected state and count badge.
  Widget _buildFilterPill({
    required String label,
    required String filterKey,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final bool isSelected = _selectedStatusFilter == filterKey;

    return GestureDetector(
      onTap: () {
        if (_selectedStatusFilter != filterKey) {
          setState(() {
            _selectedStatusFilter = filterKey;
          });
        }
      },
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
                    ? AppColors.warmGold.withValues(alpha: 0.22)
                    : const Color(0xFFEDEFF2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
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

  Widget _buildOrderCard(OrderModel order) {
    final visuals = OrderStatusVisuals.fromStatus(order.status);
    final distinctItems = order.distinctItems;
    final isMultiItem = distinctItems.length > 1;

    return InkWell(
      key: ValueKey(order.id.isNotEmpty ? order.id : order.orderNumber),
      onTap: () => _showOrderDetailsSheet(context, order),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: visuals.borderColor.withValues(alpha: 0.9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: visuals.primaryColor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header: Order # + Date + Colored Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.darkCharcoal),
                    ),
                    if (order.createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}',
                        style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: visuals.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: visuals.borderColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(visuals.icon, size: 11.5, color: visuals.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        visuals.label,
                        style: TextStyle(
                          color: visuals.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.dividerLight),
            const SizedBox(height: 10),

            // Product Item Details
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey.shade100,
                    child: order.productImage.isNotEmpty
                        ? Image.network(
                            order.productImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.car_repair, color: Colors.grey),
                          )
                        : const Icon(Icons.car_repair, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMultiItem
                            ? '${distinctItems.first.productName} & ${distinctItems.length - 1} more'
                            : order.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isMultiItem
                            ? '${distinctItems.length} parts • ${order.totalItemUnits} units'
                            : '${order.companyName} • Qty: ${order.quantity}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹ ${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.darkCharcoal),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Details', style: TextStyle(fontSize: 11, color: AppColors.primaryGold, fontWeight: FontWeight.w700)),
                        Icon(Icons.chevron_right, size: 14, color: AppColors.primaryGold),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Subtle Status Explanation Banner
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: visuals.backgroundColor.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: visuals.borderColor.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(visuals.icon, size: 13, color: visuals.primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      visuals.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: visuals.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            if (order.adminRemark != null && order.adminRemark!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.support_agent_rounded, size: 14, color: AppColors.primaryGold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 11.5, color: AppColors.darkCharcoal),
                          children: [
                            const TextSpan(
                              text: 'Admin Note: ',
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
          ],
        ),
      ),
    );
  }
}

/// Refresh button for the empty "No Orders" view (kept as a const-friendly
/// widget so the surrounding const list stays const).
class _EmptyOrdersRefreshSlot extends StatelessWidget {
  const _EmptyOrdersRefreshSlot();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_UserOrdersScreenState>();
    if (state == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: state._isRefreshing ? null : state._refreshOrders,
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Refresh'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkHeader,
        side: const BorderSide(color: AppColors.borderLight),
      ),
    );
  }
}
