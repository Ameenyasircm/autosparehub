import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';
import 'cart_screen.dart';
import 'widgets/customer_registration_sheet.dart';
import 'widgets/order_placement_sheet.dart';

/// Customer storefront product detail screen featuring e-commerce specifications,
/// vehicle compatibility verification, and approval-gated order placement.
class UserProductDetailScreen extends StatelessWidget {
  final ProductModel product;

  const UserProductDetailScreen({super.key, required this.product});

  void _handleOrderTap(BuildContext context) async {
    final authProvider = context.read<UserAuthProvider>();

    // Case 1: Unregistered Guest -> Show Registration Modal
    if (!authProvider.isRegistered) {
      CustomerRegistrationSheet.show(context);
      return;
    }

    // Case 2: Registered but status is Pending -> Re-sync with Firestore
    if (authProvider.isPending) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Checking latest admin approval status...'),
          duration: Duration(seconds: 1),
        ),
      );

      await authProvider.refreshApprovalStatus();

      if (!context.mounted) return;

      if (authProvider.isApproved) {
        // Now approved! Sync cart and proceed to order placement
        if (authProvider.currentCustomer != null) {
          context.read<CartProvider>().loadCartForUser(authProvider.currentCustomer!.id);
        }
        OrderPlacementSheet.show(context, product: product);
      } else {
        // Still pending approval
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your registration has been submitted and is awaiting administrator verification. Once approved, you can place orders immediately.',
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
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Case 3: Approved Buyer -> Open Order Placement Sheet directly
    if (authProvider.isApproved) {
      OrderPlacementSheet.show(context, product: product);
      return;
    }

    // Case 4: Rejected Buyer -> Prompt registration sheet to review / re-apply
    if (authProvider.isRejected) {
      CustomerRegistrationSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final isOutOfStock = product.stockQuantity != null && product.stockQuantity! <= 0;

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
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5),
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                    tooltip: 'Shopping Cart',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    },
                  ),
                  if (cart.totalItemCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGold,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '${cart.totalItemCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.darkCharcoal,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: _buildStickyBottomBar(context, authProvider, isOutOfStock),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- PRODUCT PHOTO HERO ---
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 54, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- HEADER CARD (Name, Brand, Price & Stock) ---
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
                  // Tags row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildPill(product.companyName.toUpperCase(), AppColors.darkCharcoal, AppColors.lightGold),
                          _buildPill(product.categoryName, Colors.grey.shade100, AppColors.darkCharcoal),
                        ],
                      ),
                      _buildStockBadge(product.stockQuantity),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Product Title
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                    ),
                  ),

                  if (product.refNo != null && product.refNo!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.tag_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'OEM Reference: ${product.refNo!}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELLING PRICE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            product.price != null
                                ? '₹ ${product.price!.toStringAsFixed(2)}'
                                : 'Price on Request',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Guaranteed Fitment',
                          style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- VEHICLE COMPATIBILITY ---
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
                  Row(
                    children: const [
                      Icon(Icons.directions_car_outlined, color: AppColors.primaryGold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Vehicle Application Compatibility',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.application,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- TECHNICAL SPECIFICATIONS ---
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
                  Row(
                    children: const [
                      Icon(Icons.tune_outlined, color: AppColors.primaryGold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Technical Specifications',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSpecRow('Part Reference (Ref No)', product.refNo),
                  _buildSpecRow('Displacement', product.displacement),
                  _buildSpecRow('Max Pressure', product.maxPressure),
                  _buildSpecRow('Controlled Flow', product.controlledFlow),
                  _buildSpecRow('Speed Range', product.speedRange),
                  _buildSpecRow('Rotation Direction', product.rotation),
                  _buildSpecRow('Fuel Feed Hole', product.fuelFeedHole, isLast: true),
                ],
              ),
            ),

            if (product.description != null && product.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
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
                    Row(
                      children: const [
                        Icon(Icons.description_outlined, color: AppColors.primaryGold, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Description & Notes',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.description!,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(
    BuildContext context,
    UserAuthProvider authProvider,
    bool isOutOfStock,
  ) {
    String ctaLabel = 'Order Part';
    IconData ctaIcon = Icons.shopping_bag_outlined;

    if (!authProvider.isRegistered) {
      ctaLabel = 'Register to Order';
      ctaIcon = Icons.person_add_outlined;
    } else if (authProvider.isPending) {
      ctaLabel = 'Approval Pending (Check Status)';
      ctaIcon = Icons.hourglass_top_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: Row(
          children: [
            // Price snippet
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Price', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  product.price != null
                      ? '₹ ${product.price!.toStringAsFixed(0)}'
                      : 'N/A',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.darkCharcoal),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Add to Cart Button
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkCharcoal,
                    side: BorderSide(
                      color: isOutOfStock ? Colors.grey.shade300 : AppColors.darkCharcoal,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isOutOfStock
                      ? null
                      : () {
                          context.read<CartProvider>().addToCart(product);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${product.name} to cart'),
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'View Cart',
                                textColor: AppColors.primaryGold,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const CartScreen()),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
                  label: const Text(
                    'Add to Cart',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Buy Now / Order Button
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOutOfStock ? Colors.grey.shade300 : AppColors.darkCharcoal,
                    foregroundColor: isOutOfStock ? Colors.grey : AppColors.primaryGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isOutOfStock ? null : () => _handleOrderTap(context),
                  icon: Icon(ctaIcon, size: 17),
                  label: Text(
                    isOutOfStock ? 'Out of Stock' : (authProvider.isApproved ? 'Buy Now' : ctaLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: text, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildStockBadge(int? stock) {
    final isOut = stock != null && stock <= 0;
    final color = isOut ? AppColors.error : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isOut ? 'Out of Stock' : 'In Stock (${stock ?? 'Available'})',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildSpecRow(String label, String? value, {bool isLast = false}) {
    final display = (value != null && value.trim().isNotEmpty) ? value : '—';
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
          Flexible(
            child: Text(
              display,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: display == '—' ? Colors.grey : AppColors.darkCharcoal,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
