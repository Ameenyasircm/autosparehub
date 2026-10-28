import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product_model.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/user_auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../order_success_screen.dart';

/// Modal bottom sheet allowing an approved customer to choose quantity, enter shipping address,
/// and place a spare part order.
class OrderPlacementSheet extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onOrderPlaced;

  const OrderPlacementSheet({
    super.key,
    required this.product,
    this.onOrderPlaced,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductModel product,
    VoidCallback? onOrderPlaced,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => OrderPlacementSheet(product: product, onOrderPlaced: onOrderPlaced),
    );
  }

  @override
  State<OrderPlacementSheet> createState() => _OrderPlacementSheetState();
}

class _OrderPlacementSheetState extends State<OrderPlacementSheet> {
  final _noteController = TextEditingController();
  int _quantity = 1;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _maxStock => widget.product.stockQuantity != null && widget.product.stockQuantity! > 0
      ? widget.product.stockQuantity!
      : 99;

  double get _totalPrice => (widget.product.price ?? 0.0) * _quantity;

  Future<void> _submitOrder() async {
    final customer = context.read<UserAuthProvider>().currentCustomer;
    if (customer == null || !customer.isApproved) return;

    final orderProvider = context.read<OrderProvider>();
    final order = await orderProvider.placeOrder(
      userId: customer.id,
      userName: customer.name,
      userPhone: customer.phoneNumber,
      product: widget.product,
      quantity: _quantity,
      shippingAddress: null,
      customerNote: _noteController.text.trim(),
    );

    if (order != null && mounted) {
      Navigator.of(context).pop();
      widget.onOrderPlaced?.call();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(order: order),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final price = widget.product.price ?? 0.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey.shade100,
                  child: Image.network(
                    widget.product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.car_repair, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.product.companyName} • ${widget.product.categoryName}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryGold, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹ ${price.toStringAsFixed(2)} per unit',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.dividerLight),
          const SizedBox(height: 12),

          // Quantity Stepper Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Quantity',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _quantity < _maxStock ? () => setState(() => _quantity++) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Direct Contact / No Delivery Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Icon(Icons.phone_in_talk_outlined, size: 16, color: AppColors.darkCharcoal),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No delivery service. Admin will contact you directly.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'ഞങ്ങൾക്ക് ഡെലിവറി സർവീസ് ലഭ്യമല്ല. ഓർഡർ ലഭിച്ച ശേഷം അഡ്മിൻ നേരിട്ട് ബന്ധപ്പെടുന്നതാണ്.',
                  style: TextStyle(fontSize: 11, color: AppColors.secondaryText, height: 1.35),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Total Price Summary Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Payable Amount',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                Text(
                  '₹ ${_totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ],
            ),
          ),

          if (orderProvider.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              orderProvider.errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // Submit Order Button
          Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primaryGold, AppColors.lightGold]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: orderProvider.isPlacingOrder ? null : _submitOrder,
              child: orderProvider.isPlacingOrder
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(AppColors.darkCharcoal)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.shopping_bag_outlined, color: AppColors.darkCharcoal, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Confirm & Place Order',
                          style: TextStyle(
                            color: AppColors.darkCharcoal,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
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
}
