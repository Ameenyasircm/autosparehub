import 'package:flutter/material.dart';
import 'package:auto_spare_hub/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_helper.dart';
import 'cart_screen.dart';

/// Product detail sheet and screen matching Image 4 with precision:
/// - Crisp centered product image
/// - Product title, Part No, Brand, Product ID
/// - Key-value Product Specifications
/// - Description section
/// - Requested quantity stepper with warm orange/gold container
/// - Total Price and "+ Add to Cart" obsidian action button
class UserProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const UserProductDetailScreen({super.key, required this.product});

  static Future<void> show(BuildContext context, ProductModel product) {
    final isTablet = ResponsiveHelper.isTablet(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: isTablet ? const BoxConstraints(maxWidth: 580) : null,
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
    final isTablet = ResponsiveHelper.isTablet(context);

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
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isTablet ? 960 : 600),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder, width: 1.2),
                ),
                padding: EdgeInsets.all(isTablet ? 28 : 20),
                child: _ProductDetailContent(
                  product: widget.product,
                  quantity: _quantity,
                  onQuantityChanged: (q) => setState(() => _quantity = q),
                  onAdded: () => Navigator.of(context).pop(),
                  twoColumn: isTablet,
                ),
              ),
            ),
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
    return SafeArea(
      child: Container(
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
  final bool twoColumn;

  const _ProductDetailContent({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    this.onAdded,
    this.twoColumn = false,
  });

  void _handleAdd(BuildContext context) {
    final cart = context.read<CartProvider>();
    cart.addToCart(product, quantity: quantity);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBarAutoHide(
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

  Widget _buildImageShowcase({double height = 165, bool framed = false}) {
    return Container(
      height: height,
      width: double.infinity,
      padding: framed ? const EdgeInsets.all(20) : EdgeInsets.zero,
      alignment: Alignment.center,
      decoration: framed
          ? BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFECEFF3), width: 1.2),
            )
          : null,
      child: Image.network(
        product.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.precision_manufacturing_outlined,
          size: framed ? 88 : 72,
          color: AppColors.primaryGold,
        ),
      ),
    );
  }

  Widget _buildDetailsColumn(BuildContext context, double totalPrice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        // --- BOTTOM ACTION ROW ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Price & Total Price label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${totalPrice.toStringAsFixed(0)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            ),
            const SizedBox(width: 12),

            // "+ Add to Cart" Button
            Flexible(
              flex: 0,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkButton,
                  foregroundColor: AppColors.warmGold,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _handleAdd(context),
                icon: const Icon(Icons.add, size: 18, color: AppColors.warmGold),
                label: const Text(
                  'Add to Cart',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warmGold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final unitPrice = product.price ?? 0.0;
    final totalPrice = unitPrice * quantity;

    if (twoColumn) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: _buildImageShowcase(height: 300, framed: true),
          ),
          const SizedBox(width: 28),
          Expanded(
            flex: 6,
            child: _buildDetailsColumn(context, totalPrice),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _buildImageShowcase(height: 165)),
        const SizedBox(height: 16),
        _buildDetailsColumn(context, totalPrice),
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
          const SizedBox(width: 12),
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
