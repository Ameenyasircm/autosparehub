import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cart_item_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';
import 'user_orders_screen.dart';
import 'widgets/customer_registration_sheet.dart';

/// Customer shopping cart screen displaying selected spare parts,
/// quantity controls, subtotal computation, delivery address entry,
/// and approval-gated order placement.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleCheckout() async {
    final authProvider = context.read<UserAuthProvider>();
    final cartProvider = context.read<CartProvider>();

    if (cartProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty. Add parts before checkout.')),
      );
      return;
    }

    // 1. Unregistered Guest -> Prompt 10-digit registration
    if (!authProvider.isRegistered) {
      CustomerRegistrationSheet.show(context);
      return;
    }

    // 2. Pending Approval -> Refresh and notify
    if (authProvider.isPending) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Checking latest admin approval status...'),
          duration: Duration(seconds: 1),
        ),
      );

      await authProvider.refreshApprovalStatus();
      if (!mounted) return;

      if (!authProvider.isApproved) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: const [
                Icon(Icons.hourglass_empty_rounded, color: AppColors.primaryGold, size: 26),
                SizedBox(width: 10),
                Text('Approval Pending', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: const Text(
              'Your customer account is currently awaiting administrator verification. Once approved, your order will be submitted right away.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 3. Rejected -> Prompt to view status
    if (authProvider.isRejected) {
      CustomerRegistrationSheet.show(context);
      return;
    }

    // 4. Approved -> Validate form and submit order
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final customer = authProvider.currentCustomer!;
    final orderProvider = context.read<OrderProvider>();

    final order = await orderProvider.placeCartOrder(
      userId: customer.id,
      userName: customer.name,
      userPhone: customer.phone,
      cartItems: cartProvider.items,
      shippingAddress: _addressController.text.trim(),
      customerNote: _noteController.text.trim(),
    );

    if (!mounted) return;

    if (order != null) {
      await cartProvider.clearCart();
      _showOrderSuccessDialog(order.orderNumber);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.errorMessage ?? 'Failed to place order. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showOrderSuccessDialog(String orderNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 54,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Placed Successfully!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                orderNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Our operations team has received your spare parts order and will contact you for dispatch confirmation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(); // Back to catalog
            },
            child: const Text('Back to Catalog', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkCharcoal,
              foregroundColor: AppColors.primaryGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const UserOrdersScreen()),
              );
            },
            child: const Text('View My Orders', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final authProvider = context.watch<UserAuthProvider>();

    final items = cartProvider.items;
    final isPlacing = orderProvider.isPlacingOrder;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Shopping Cart (${cartProvider.totalItemCount})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Clear Cart?', style: TextStyle(fontWeight: FontWeight.w800)),
                    content: const Text('Are you sure you want to remove all items from your cart?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          cartProvider.clearCart();
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      bottomNavigationBar: items.isEmpty ? null : _buildStickyCheckoutBar(context, cartProvider, isPlacing),
      body: items.isEmpty
          ? _buildEmptyCart(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- CART ITEMS LIST ---
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildCartItemCard(items[index], cartProvider);
                      },
                    ),

                    const SizedBox(height: 20),

                    // --- DELIVERY INFORMATION FORM ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                            children: const [
                              Icon(Icons.local_shipping_outlined, color: AppColors.primaryGold, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Delivery Information',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // Customer Contact Preview
                          if (authProvider.isRegistered)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                                    child: Text(
                                      authProvider.currentCustomer!.name.isNotEmpty
                                          ? authProvider.currentCustomer!.name[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: AppColors.darkCharcoal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          authProvider.currentCustomer!.name,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                        Text(
                                          '+91 ${authProvider.currentCustomer!.phone}',
                                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: authProvider.isApproved
                                          ? AppColors.success.withValues(alpha: 0.12)
                                          : Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      authProvider.isApproved ? 'Approved' : 'Pending',
                                      style: TextStyle(
                                        color: authProvider.isApproved ? AppColors.success : Colors.amber.shade800,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Shipping Address Field
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Workshop / Shipping Address *',
                              hintText: 'Shop / Garage Name, Street, City, State, PIN',
                              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primaryGold),
                              filled: true,
                              fillColor: AppColors.backgroundLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter workshop or shipping address';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // Customer Note Field
                          TextFormField(
                            controller: _noteController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Order Notes (Optional)',
                              hintText: 'e.g. Urgent bus transport / parcel office dispatch',
                              prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.secondaryText),
                              filled: true,
                              fillColor: AppColors.backgroundLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- PRICE SUMMARY BREAKDOWN ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price Breakdown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSummaryRow(
                            'Parts Subtotal (${cartProvider.totalItemCount} units)',
                            '₹ ${cartProvider.subtotalAmount.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Logistics & Transport',
                            'To Pay (Bus / Parcel)',
                            isSecondary: true,
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Estimated Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                              Text(
                                '₹ ${cartProvider.subtotalAmount.toStringAsFixed(2)}',
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

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isSecondary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSecondary ? AppColors.secondaryText : AppColors.darkCharcoal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSecondary ? FontWeight.w600 : FontWeight.w700,
            color: isSecondary ? Colors.blueGrey : AppColors.darkCharcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemCard(CartItemModel item, CartProvider cartProvider) {
    final p = item.product;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 70,
              height: 70,
              color: Colors.grey.shade100,
              child: p.imageUrl.isNotEmpty
                  ? Image.network(
                      p.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.car_repair_rounded,
                        color: AppColors.primaryGold,
                        size: 32,
                      ),
                    )
                  : const Icon(
                      Icons.car_repair_rounded,
                      color: AppColors.primaryGold,
                      size: 32,
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Details & Quantity Stepper
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Remove',
                      onPressed: () => cartProvider.removeFromCart(p.id),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.companyName} • ${p.categoryName}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                ),
                if (p.refNo != null && p.refNo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ref: ${p.refNo}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 8),

                // Price and Quantity Counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹ ${(p.price ?? 0.0).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),

                    // Stepper: - [Qty] +
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => cartProvider.decrementQuantity(p.id),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Icon(Icons.remove, size: 16, color: AppColors.darkCharcoal),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                          InkWell(
                            onTap: () => cartProvider.incrementQuantity(p.id),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Icon(Icons.add, size: 16, color: AppColors.darkCharcoal),
                            ),
                          ),
                        ],
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

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: AppColors.primaryGold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Cart is Empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore our genuine automotive spare parts catalog and add items to place an order.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                foregroundColor: AppColors.primaryGold,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Browse Spare Parts', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyCheckoutBar(BuildContext context, CartProvider cartProvider, bool isPlacing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Subtotal
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cartProvider.totalItemCount} Items Subtotal',
                  style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                ),
                Text(
                  '₹ ${cartProvider.subtotalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Checkout Button
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: AppColors.primaryGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isPlacing ? null : () => _handleCheckout(),
                  icon: isPlacing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGold),
                        )
                      : const Icon(Icons.shopping_bag_outlined, size: 20),
                  label: Text(
                    isPlacing ? 'Submitting...' : 'Place Order',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
