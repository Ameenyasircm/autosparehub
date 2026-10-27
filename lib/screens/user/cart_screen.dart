import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cart_item_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';
import 'order_success_screen.dart';
import 'user_login_screen.dart';
import 'user_orders_screen.dart';

/// Customer shopping cart screen matching Image 2 with precision:
/// - Dark AppBar with "My Cart" and white back button
/// - Light grey background
/// - Item cards with product thumbnail, Part No, category pill badge
/// - Bold item price and warm peach/cream stepper
/// - Obsidian "Order Submit  (X Item)" button with gold text
/// - Bottom navigation bar (Home, My Orders, Profile)
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
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

    // 1. Unregistered Guest -> Open Login/Register Screen
    if (!authProvider.isRegistered) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserLoginScreen(
            onAuthenticated: () => _handleCheckout(),
          ),
        ),
      );
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
                Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 26),
                SizedBox(width: 10),
                Text('Approval Pending', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your customer account is currently awaiting administrator verification. Once approved, your order will be submitted right away.',
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Text(
                    'നിങ്ങളുടെ അക്കൗണ്ട് അഡ്മിന്റെ പരിശോധനയിലാണ്. അഡ്മിൻ അനുമതി നൽകിയ ശേഷം മാത്രമേ ഓർഡറുകൾ നൽകാൻ സാധിക്കൂ.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.darkCharcoal, height: 1.4),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.darkCharcoal)),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 3. Rejected -> Prompt to view status
    if (authProvider.isRejected) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UserLoginScreen()),
      );
      return;
    }

    // 4. Approved -> Submit order
    final customer = authProvider.currentCustomer!;
    final orderProvider = context.read<OrderProvider>();

    final order = await orderProvider.placeCartOrder(
      userId: customer.id,
      userName: customer.name,
      userPhone: customer.phone,
      cartItems: cartProvider.items,
      shippingAddress: null,
      customerNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
    );

    if (!mounted) return;

    if (order != null) {
      await cartProvider.clearCart(isOrderPlaced: true);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(order: order, fromCart: true),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit order request. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final isPlacing = orderProvider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkHeader,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Cart',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        actions: [
          if (cartProvider.isNotEmpty)
            TextButton(
              onPressed: () => cartProvider.clearCart(),
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
      body: cartProvider.isEmpty
          ? _buildEmptyCart(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- ITEM CARDS LIST ---
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cartProvider.items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cartProvider.items[index];
                      return _buildCartItemCard(item, cartProvider);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Optional customer note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Remarks / Model Note (Optional)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, color: AppColors.darkCharcoal),
                          decoration: InputDecoration(
                            hintText: 'e.g. Need 2018 model compatible, urgent dispatch',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                            filled: true,
                            fillColor: AppColors.backgroundLight,
                            contentPadding: const EdgeInsets.all(12),
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

                  // --- "Order Submit  (X Item)" BUTTON (EXACT TO IMAGE 2) ---
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkButton,
                        foregroundColor: AppColors.warmGold,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isPlacing ? null : _handleCheckout,
                      child: isPlacing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warmGold),
                            )
                          : Text(
                              'Order Submit  (${cartProvider.totalItemCount} Item)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.warmGold,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- CART ITEM CARD (EXACT MATCH TO IMAGE 2) ---
  Widget _buildCartItemCard(CartItemModel item, CartProvider cartProvider) {
    final p = item.product;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 68,
                  height: 68,
                  color: Colors.grey.shade50,
                  child: p.imageUrl.isNotEmpty
                      ? Image.network(
                          p.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.precision_manufacturing_outlined,
                            color: AppColors.primaryGold,
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.precision_manufacturing_outlined,
                          color: AppColors.primaryGold,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Title, Part No & Category Pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.refNo != null && p.refNo!.isNotEmpty
                          ? 'Part No. ${p.refNo}'
                          : 'Part No. OF-1024',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Category Tag Pill (Warm gold outline + cream fill)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.badgeGoldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.badgeGoldBorder, width: 1),
                      ),
                      child: Text(
                        p.categoryName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.badgeGoldText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Price & Stepper Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Total Line Item Price
              Text(
                '₹${(item.totalPrice).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkCharcoal,
                ),
              ),

              // Stepper: - [5] + in warm peach/cream container
              Container(
                decoration: BoxDecoration(
                  color: AppColors.stepperBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => cartProvider.decrementQuantity(p.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 32,
                        height: 28,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.remove,
                          size: 16,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => cartProvider.incrementQuantity(p.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 32,
                        height: 28,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 56,
                color: AppColors.primaryGold,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your Cart is Empty',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse genuine spare parts and submit your request directly to the supplier.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkButton,
                foregroundColor: AppColors.warmGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Browse Spare Parts', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // --- BOTTOM NAVIGATION BAR (MATCHING IMAGE 2 & 5) ---
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Home Tab
          InkWell(
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.home_outlined, size: 22, color: AppColors.darkCharcoal),
                SizedBox(height: 3),
                Text('Home', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal)),
              ],
            ),
          ),

          // My Orders Tab
          InkWell(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const UserOrdersScreen()),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.format_list_bulleted_rounded, size: 22, color: AppColors.darkCharcoal),
                SizedBox(height: 3),
                Text('My Orders', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal)),
              ],
            ),
          ),

          // Profile Tab
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserLoginScreen()),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.person_outline_rounded, size: 22, color: AppColors.darkCharcoal),
                SizedBox(height: 3),
                Text('Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
