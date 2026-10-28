import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';
import 'user_login_screen.dart';
import 'widgets/change_password_dialog.dart';

/// Customer screen displaying the history, live status, and detailed itemized
/// breakdowns of placed automotive spare part orders.
class UserOrdersScreen extends StatefulWidget {
  final bool showAppBar;
  const UserOrdersScreen({super.key, this.showAppBar = true});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen> {
  String? _lastFetchedCustomerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFetchOrders();
    });
  }

  void _checkAndFetchOrders() {
    if (!mounted) return;
    final customer = context.read<UserAuthProvider>().currentCustomer;
    if (customer != null && _lastFetchedCustomerId != customer.id) {
      _lastFetchedCustomerId = customer.id;
      context.read<OrderProvider>().fetchCustomerOrders(customer.id, userPhone: customer.phone);
    }
  }

  void _showOrderDetailsSheet(BuildContext context, OrderModel order) {
    final statusColor = order.isDelivered
        ? AppColors.success
        : order.isCancelled
            ? AppColors.error
            : order.isDispatched
                ? Colors.blue.shade700
                : AppColors.secondaryGold;

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
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
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
                                        'Ref: ${item.refNo}',
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
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
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
              : RefreshIndicator(
                  color: AppColors.primaryGold,
                  backgroundColor: AppColors.darkCharcoal,
                  onRefresh: () => orderProvider.fetchCustomerOrders(customer.id, userPhone: customer.phone),
                  child: orders.isEmpty
                      ? (orderProvider.isCustomerOrdersLoading
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
                                  ],
                                ),
                              ),
                            ))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return _buildOrderCard(order);
                          },
                        ),
                ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColor = order.isDelivered
        ? AppColors.success
        : order.isCancelled
            ? AppColors.error
            : order.isDispatched
                ? Colors.blue.shade700
                : AppColors.secondaryGold;

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
            // Order Header
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
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
            if (order.adminRemark != null && order.adminRemark!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
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
