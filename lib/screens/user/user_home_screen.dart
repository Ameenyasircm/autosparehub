import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';
import 'cart_screen.dart';
import 'user_orders_screen.dart';
import 'user_product_detail_screen.dart';
import 'widgets/customer_registration_sheet.dart';

/// Customer Storefront Home Screen displaying automotive spare parts catalog,
/// live keyword search, category filter strip, and conditional company filter (>= 2 companies).
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserAuthProvider>().initSession();
      context.read<ProductProvider>().fetchProducts();

      final compProvider = context.read<CompanyProvider>();
      if (compProvider.companies.isEmpty) compProvider.fetchCompanies();

      final catProvider = context.read<CategoryProvider>();
      if (catProvider.categories.isEmpty) catProvider.fetchCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final authProvider = context.watch<UserAuthProvider>();

    // Condition: "filter with company name only needed if there is 2 or more company"
    final bool showCompanyFilter = companyProvider.companies.length >= 2;
    final products = productProvider.filteredProducts.where((p) => p.isActive).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/AutoSpareLogo.jpg',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.directions_car,
                    color: AppColors.primaryGold,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'AutoSpare Store',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        actions: [
          // User Status Badge
          _buildCustomerStatusBadge(context, authProvider),
          const SizedBox(width: 4),

          // Cart Button with dynamic count badge
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

          // Orders Shortcut Button
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.lightGold),
            tooltip: 'My Orders',
            onPressed: () {
              if (authProvider.isRegistered) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserOrdersScreen()),
                );
              } else {
                CustomerRegistrationSheet.show(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // --- TOP SEARCH & FILTERS HEADER ---
          Container(
            color: AppColors.darkCharcoal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Keyword Search Field
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  onChanged: (val) => productProvider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search spare parts, OEM numbers, vehicle model...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              productProvider.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Category Filter Strip (Always Available)
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildFilterChip(
                        label: 'All Categories',
                        isSelected: productProvider.selectedCategoryId == 'ALL',
                        onTap: () => productProvider.setSelectedCategoryId('ALL'),
                      ),
                      ...categoryProvider.categories.map((cat) {
                        return _buildFilterChip(
                          label: cat.name,
                          isSelected: productProvider.selectedCategoryId == cat.id,
                          onTap: () => productProvider.setSelectedCategoryId(cat.id),
                        );
                      }),
                    ],
                  ),
                ),

                // Conditional Company Filter Strip (Rendered ONLY if >= 2 companies exist)
                if (showCompanyFilter) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildFilterChip(
                          label: 'All Makes',
                          isSelected: productProvider.selectedCompanyId == 'ALL',
                          onTap: () => productProvider.setSelectedCompanyId('ALL'),
                          isMake: true,
                        ),
                        ...companyProvider.companies.map((comp) {
                          return _buildFilterChip(
                            label: comp.name,
                            isSelected: productProvider.selectedCompanyId == comp.id,
                            onTap: () => productProvider.setSelectedCompanyId(comp.id),
                            isMake: true,
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // --- STOREFRONT SUBHEADER (Catalog count & filter clear) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${products.length} Parts Available',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.darkCharcoal),
                ),
                if (productProvider.selectedCompanyId != 'ALL' ||
                    productProvider.selectedCategoryId != 'ALL' ||
                    productProvider.searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      productProvider.clearFilters();
                    },
                    child: const Text(
                      'Clear Filters ×',
                      style: TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // --- 2-COLUMN STOREFRONT PRODUCT GRID ---
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryGold,
              backgroundColor: AppColors.darkCharcoal,
              onRefresh: () => productProvider.fetchProducts(),
              child: products.isEmpty
                  ? _buildEmptyState(productProvider)
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.60,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _buildProductCard(context, product);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerStatusBadge(BuildContext context, UserAuthProvider auth) {
    if (!auth.isRegistered) {
      return TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightGold,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: () => CustomerRegistrationSheet.show(context),
        icon: const Icon(Icons.person_outline, size: 16),
        label: const Text('Register', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );
    }

    if (auth.isPending) {
      return GestureDetector(
        onTap: () {
          final requestedDate = auth.currentCustomer?.requestedAt;
          final dateStr = requestedDate != null
              ? '${requestedDate.day}/${requestedDate.month}/${requestedDate.year}'
              : 'Recently';
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: const [
                  Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text('Approval Pending', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${auth.currentCustomer?.name ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text('Mobile: +91 ${auth.currentCustomer?.phone ?? ''}', style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                  const SizedBox(height: 4),
                  Text('Submitted: $dateStr', style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText)),
                  const SizedBox(height: 12),
                  const Text(
                    'Your account is currently waiting for administrator authorization. Once approved, you can place orders immediately.',
                    style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: AppColors.primaryGold,
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await auth.refreshApprovalStatus();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            auth.isApproved
                                ? 'Congratulations! Your account is approved!'
                                : 'Still pending administrator review.',
                          ),
                          backgroundColor: auth.isApproved ? AppColors.success : AppColors.darkCharcoal,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Check Status'),
                ),
              ],
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.shade900.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade400, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 12),
              SizedBox(width: 4),
              Text(
                'Pending ⏳',
                style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    if (auth.isRejected) {
      return GestureDetector(
        onTap: () => CustomerRegistrationSheet.show(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline, color: AppColors.error, size: 12),
              SizedBox(width: 4),
              Text(
                'Rejected',
                style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.verified_user_rounded, color: AppColors.success, size: 12),
          SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isMake = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryGold
                : Colors.white.withValues(alpha: isMake ? 0.08 : 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primaryGold : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.darkCharcoal : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserProductDetailScreen(product: product),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with floating brand tag
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                    child: AspectRatio(
                      aspectRatio: 1.2,
                      child: Container(
                        color: Colors.grey.shade100,
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.car_repair, color: Colors.grey, size: 36),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.darkCharcoal.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.companyName.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.lightGold,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Product Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.categoryName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.secondaryGold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.application,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      // Price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product.price != null
                                  ? '₹ ${product.price!.toStringAsFixed(2)}'
                                  : 'Price on Req',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
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
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 14,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildEmptyState(ProductProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 50, color: Colors.grey),
            const SizedBox(height: 14),
            const Text(
              'No Matching Spare Parts',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try searching with another keyword, OEM part number, or reset your filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                provider.clearFilters();
              },
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
