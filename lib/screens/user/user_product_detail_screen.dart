import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import 'cart_screen.dart';

/// Product detail sheet and screen matching Image 4 with precision:
/// - Crisp centered product image
/// - Product title, Part No, Brand, Product ID
/// - Key-value Product Specifications
/// - Description section
/// - Requested quantity stepper with warm orange/gold container
/// - Total Price and "+ Add to Request" obsidian action button
class UserProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const UserProductDetailScreen({super.key, required this.product});

  static Future<void> show(BuildContext context, ProductModel product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserProductDetailSheet(product: product),
    );
  }

  @override
  State<UserProductDetailScreen> createState() => _UserProductDetailScreenState();
}

class _UserProductDetailScreenState extends State<UserProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkHeader,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                if (cart.totalItemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.warmGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
          ),
          padding: const EdgeInsets.all(20),
          child: _ProductDetailContent(
            product: widget.product,
            quantity: _quantity,
            onQuantityChanged: (q) => setState(() => _quantity = q),
            onAdded: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet matching Image 4
class UserProductDetailSheet extends StatefulWidget {
  final ProductModel product;

  const UserProductDetailSheet({super.key, required this.product});

  @override
  State<UserProductDetailSheet> createState() => _UserProductDetailSheetState();
}

class _UserProductDetailSheetState extends State<UserProductDetailSheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              physics: const BouncingScrollPhysics(),
              child: _ProductDetailContent(
                product: widget.product,
                quantity: _quantity,
                onQuantityChanged: (q) => setState(() => _quantity = q),
                onAdded: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable Product Detail Content adhering strictly to Image 4
class _ProductDetailContent extends StatelessWidget {
  final ProductModel product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback? onAdded;

  const _ProductDetailContent({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    this.onAdded,
  });

  void _handleAdd(BuildContext context) {
    final cart = context.read<CartProvider>();
    cart.addToCart(product, quantity: quantity);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $quantity × ${product.name} to Request'),
        backgroundColor: AppColors.darkButton,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: AppColors.warmGold,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
    );

    onAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final unitPrice = product.price ?? 0.0;
    final totalPrice = unitPrice * quantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Photo
        Center(
          child: Container(
            height: 165,
            width: double.infinity,
            alignment: Alignment.center,
            child: Image.network(
              product.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.precision_manufacturing_outlined,
                size: 72,
                color: AppColors.primaryGold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Product Title
        Text(
          product.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),

        // Part No
        Text(
          product.refNo != null && product.refNo!.isNotEmpty
              ? 'Part No. ${product.refNo}'
              : 'Part No. N/A',
          style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 2),

        // Brand
        Text(
          'Brand: ${product.companyName.isNotEmpty ? product.companyName : 'Generic / OEM'}',
          style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 2),

        // Product ID
        Text(
          'Product ID: ${product.id}',
          style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
        ),

        const SizedBox(height: 20),

        // --- PRODUCT SPECIFICATIONS ---
        const Text(
          'Product Specifications',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        const SizedBox(height: 10),

        _buildSpecRow('Part category', product.categoryName),
        _buildSpecRow(
          'Vehicle compatibility',
          product.application.isNotEmpty ? product.application : 'See compatible models',
        ),
        _buildSpecRow(
          'Material',
          product.displacement != null && product.displacement!.isNotEmpty
              ? product.displacement!
              : 'As specified by supplier',
        ),

        const SizedBox(height: 18),

        // --- DESCRIPTION ---
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.description != null && product.description!.trim().isNotEmpty
              ? product.description!
              : 'Genuine automotive spare part manufactured to exacting vehicle specifications for optimal fitment and reliable performance.',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.secondaryText,
            height: 1.45,
          ),
        ),

        const SizedBox(height: 24),

        // --- REQUESTED QUANTITY & STEPPER ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Requested quantity',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Select how many you need',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),

            // Stepper: - [Qty] + (Warm orange/gold background with white qty box)
            Container(
              decoration: BoxDecoration(
                color: AppColors.warmGold,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: quantity > 1 ? () => onQuantityChanged(quantity - 1) : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.remove,
                        size: 18,
                        color: AppColors.darkButton,
                      ),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => onQuantityChanged(quantity + 1),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add,
                        size: 18,
                        color: AppColors.darkButton,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // --- BOTTOM ACTION ROW ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Price & Total Price label
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Total Price',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // "+ Add to Request" Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkButton,
                foregroundColor: AppColors.warmGold,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () => _handleAdd(context),
              icon: const Icon(Icons.add, size: 18, color: AppColors.warmGold),
              label: const Text(
                'Add to Request',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warmGold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            key,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.secondaryText,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
