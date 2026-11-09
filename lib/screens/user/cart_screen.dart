import 'package:flutter/material.dart';
import 'package:auto_spare_hub/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import 'widgets/order_placement_sheet.dart';
import '../../models/cart_item_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';
import 'order_success_screen.dart';
import 'user_home_screen.dart';
import 'user_login_screen.dart';
import 'user_product_detail_screen.dart';
import 'widgets/approval_pending_dialog.dart';
import 'widgets/order_access_guard.dart';

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

class _CartScreenState extends State<CartScreen> with SingleTickerProviderStateMixin {
  final _noteController = TextEditingController();
  late final AnimationController _animController;
  late final Animation<double> _floatingAnim;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatingAnim = Tween<double>(begin: -7.0, end: 7.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );

    _pulseScale = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );

    _pulseOpacity = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Login / approval checks shared by Checkout and Buy Now. Returns true
  /// when the customer is approved and can order; otherwise shows the right
  /// screen or message and returns false. [retry] runs after login.
  Future<bool> _ensureApprovedCustomer(VoidCallback retry) async {
    final authProvider = context.read<UserAuthProvider>();
    // 1. Unregistered Guest -> Open Login/Register Screen
    if (!authProvider.isRegistered) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserLoginScreen(
            onAuthenticated: retry,
          ),
        ),
      );
      return false;
    }

    // 2. Pending Approval -> Refresh and notify
    if (authProvider.isPending) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBarAutoHide(
        const SnackBar(
          content: Text('Checking latest admin approval status...'),
          duration: Duration(seconds: 1),
        ),
      );

      await authProvider.refreshApprovalStatus();
      if (!mounted) return false;

      if (!authProvider.isApproved) {
        ApprovalPendingDialog.show(
          context,
          phone: authProvider.currentCustomer?.phone ?? '',
        );
        return false;
      }
    }

    // 3. Rejected -> Prompt to view status
    if (authProvider.isRejected) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UserLoginScreen()),
      );
      return false;
    }
    return true;
  }

  /// Orders just this cart item (with its cart quantity). On success the item
  /// is removed from the cart; the rest of the cart stays.
  Future<void> _buyNow(CartItemModel item) async {
    void retry() => _buyNow(item);
    if (!await _ensureApprovedCustomer(retry)) return;
    if (!mounted) return;
    final cartProvider = context.read<CartProvider>();
    await OrderPlacementSheet.show(
      context,
      product: item.product,
      initialQuantity: item.quantity,
      onOrderPlaced: () => cartProvider.removeFromCart(item.product.id),
    );
  }

  void _openProductDetail(CartItemModel item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProductDetailScreen(product: item.product)),
    );
  }

  void _handleCheckout() async {
    final authProvider = context.read<UserAuthProvider>();
    final cartProvider = context.read<CartProvider>();

    if (cartProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBarAutoHide(
        const SnackBar(content: Text('Your cart is empty. Add parts before checkout.')),
      );
      return;
    }

    if (!await _ensureApprovedCustomer(_handleCheckout)) return;
    if (!mounted) return;
    // Server check: account still exists and is approved (login is cached).
    if (!await ensureOrderAccess(context)) return;
    if (!mounted) return;

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
      ScaffoldMessenger.of(context).showSnackBarAutoHide(
        const SnackBar(
          content: Text('Failed to submit order request. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final isPlacing = orderProvider.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F2F4), // Clean Flipkart light-grey surface
      appBar: AppBar(
        backgroundColor: AppColors.darkHeader,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          cartProvider.isNotEmpty ? 'My Cart (${cartProvider.distinctItemCount})' : 'My Cart',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cartProvider.isNotEmpty)
              _buildStickyCheckoutBar(context, cartProvider, isPlacing),
            _buildBottomNav(context),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: cartProvider.isEmpty
            ? _buildEmptyCart(context)
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Item Cards List (Flipkart Style Dual-Column Layout)
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

                    const SizedBox(height: 14),

                    // Optional Customer Remarks Card
                    _buildRemarksCard(),

                    const SizedBox(height: 14),

                    // Authentic Price Details Breakdown (Real Data Only)
                    _buildPriceDetailsCard(cartProvider),
                  ],
                ),
              ),
      ),
    );
  }

  // --- 1. CART ITEM CARD (FLIPKART DUAL-COLUMN LAYOUT) ---
  Widget _buildCartItemCard(CartItemModel item, CartProvider cartProvider) {
    final p = item.product;
    final unitPrice = p.price ?? 0.0;
    final hasRefNo = p.refNo != null && p.refNo!.trim().isNotEmpty;
    final hasApp = p.application.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Info Row: [Thumbnail + Stepper] on left, [Title + Genuine Details + Price] on right
          // Tapping it opens the product details (the -/+ stepper keeps its own taps).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openProductDetail(item),
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Image (82x82) + Quantity Stepper directly beneath
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 82,
                      height: 82,
                      color: const Color(0xFFF7F8FA),
                      child: p.imageUrl.isNotEmpty
                          ? Image.network(
                              p.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.precision_manufacturing_outlined,
                                color: AppColors.primaryGold,
                                size: 36,
                              ),
                            )
                          : const Icon(
                              Icons.precision_manufacturing_outlined,
                              color: AppColors.primaryGold,
                              size: 36,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Flipkart-style Quantity Stepper directly under image
                  Container(
                    width: 82,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => cartProvider.decrementQuantity(p.id),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                          child: const SizedBox(
                            width: 25,
                            height: 30,
                            child: Icon(Icons.remove, size: 14, color: AppColors.darkCharcoal),
                          ),
                        ),
                        Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                        InkWell(
                          onTap: () => cartProvider.incrementQuantity(p.id),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                          child: const SizedBox(
                            width: 25,
                            height: 30,
                            child: Icon(Icons.add, size: 14, color: AppColors.darkCharcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Right Column: Title, Brand & Category, Part No, Application, Genuine Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Brand & Category
                    Text(
                      '${p.companyName} • ${p.categoryName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),

                    if (hasRefNo) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Sorl No: ${p.refNo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],

                    if (hasApp) ...[
                      const SizedBox(height: 3),
                      Text(
                        'App No: ${p.application}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Authentic Price Display
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${unitPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.darkCharcoal,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (item.quantity > 1) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(Total: ₹${item.totalPrice.toStringAsFixed(0)})',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),

          const SizedBox(height: 12),

          // Action Buttons: Remove & Buy Now (orders only this item)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkCharcoal,
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => cartProvider.removeFromCart(p.id),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: const Text(
                      'Remove',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkCharcoal,
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => _buyNow(item),
                    icon: const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.primaryGold),
                    label: const Text(
                      'Buy Now',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. OPTIONAL REMARKS CARD ---
  Widget _buildRemarksCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notes_rounded, size: 16, color: AppColors.darkCharcoal),
              SizedBox(width: 6),
              Text(
                'Order Remarks / Model Note (Optional)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: AppColors.darkCharcoal),
            decoration: InputDecoration(
              hintText: 'e.g. Need 2018 model compatible, urgent dispatch',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. PRICE DETAILS CARD (AUTHENTIC CART DATA ONLY) ---
  Widget _buildPriceDetailsCard(CartProvider cartProvider) {
    final subtotal = cartProvider.subtotalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRICE DETAILS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Distinct Items',
            '${cartProvider.distinctItemCount} parts',
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Total Quantity',
            '${cartProvider.totalItemCount} units',
          ),
          const Divider(height: 20, color: Color(0xFFEEEEEE)),
          _buildPriceRow(
            'Total Amount',
            '₹${subtotal.toStringAsFixed(0)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14.5 : 12.5,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: isTotal ? AppColors.darkCharcoal : const Color(0xFF5A6271),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 12.5,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            color: isTotal ? AppColors.darkCharcoal : const Color(0xFF2C323E),
          ),
        ),
      ],
    );
  }

  // --- 4. STICKY BOTTOM CHECKOUT BAR (FLIPKART STYLE) ---
  Widget _buildStickyCheckoutBar(BuildContext context, CartProvider cartProvider, bool isPlacing) {
    final subtotal = cartProvider.subtotalAmount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total Amount on left
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${subtotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ],
          ),

          // Vibrant Yellow / Gold CTA button (Flipkart style)
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC200), // Flipkart vibrant yellow CTA
                foregroundColor: AppColors.darkCharcoal,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              onPressed: isPlacing ? null : _handleCheckout,
              child: isPlacing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkCharcoal),
                    )
                  : Text(
                      'Proceed to Order (${cartProvider.totalItemCount})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkCharcoal,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Pulsing Halo & Floating Cart Illustration
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsating warm halo ring
                    Transform.scale(
                      scale: _pulseScale.value,
                      child: Container(
                        width: 136,
                        height: 136,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.warmGold.withValues(alpha: 0.08 * _pulseOpacity.value),
                          border: Border.all(
                            color: AppColors.warmGold.withValues(alpha: 0.28 * _pulseOpacity.value),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Deep Slate Obsidian container with elevation shadow
                    Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.darkHeader,
                            Color(0xFF282E3A),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkHeader.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    // Floating cart icon with mini badge
                    Transform.translate(
                      offset: Offset(0, _floatingAnim.value),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: AppColors.warmGold,
                          ),
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: BoxDecoration(
                                color: AppColors.warmGold,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.darkHeader, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 12,
                                color: AppColors.darkHeader,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 22),

            // Clear, Understandable Headline
            const Text(
              'Your Cart is Empty',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Plain, helpful garage explanation
            const Text(
              'No spare parts have been added to your order list yet.\nBrowse our catalog to select parts for your garage or vehicle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 22),

            // 3-Step Simple Garage Order Guide
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  _buildEmptyGuideRow(
                    icon: Icons.category_outlined,
                    title: '1. Select Category',
                    subtitle: 'Brakes, Filters, Engine, Electrical, etc.',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Colors.grey.shade100, height: 1),
                  ),
                  _buildEmptyGuideRow(
                    icon: Icons.add_shopping_cart_rounded,
                    title: '2. Add to Cart',
                    subtitle: 'Set quantities matching your job requirements',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Colors.grey.shade100, height: 1),
                  ),
                  _buildEmptyGuideRow(
                    icon: Icons.send_rounded,
                    title: '3. Submit Order',
                    subtitle: 'Direct pricing & prompt order processing',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkButton,
                  foregroundColor: AppColors.warmGold,
                  elevation: 2,
                  shadowColor: AppColors.darkButton.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                // Back to the existing home screen (no second copy on the stack).
                onPressed: () => UserHomeScreen.openTab(context, UserHomeScreen.tabHome),
                // icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'Browse Spare Parts',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

  Widget _buildEmptyGuideRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.badgeGoldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.badgeGoldBorder.withValues(alpha: 0.4), width: 1),
          ),
          child: Icon(icon, size: 17, color: AppColors.badgeGoldText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
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
            onTap: () => UserHomeScreen.openTab(context, UserHomeScreen.tabHome),
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
            onTap: () => UserHomeScreen.openTab(context, UserHomeScreen.tabOrders),
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
            // Profile tab shows the account when logged in, login option otherwise.
            onTap: () => UserHomeScreen.openTab(context, UserHomeScreen.tabProfile),
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
