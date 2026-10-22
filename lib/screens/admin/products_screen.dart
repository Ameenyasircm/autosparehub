import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

/// Professional automotive spare parts catalog list screen with search,
/// company/category filters, and CRUD controls.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  void _openProductForm([ProductModel? product]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(productToEdit: product),
      ),
    );
    if (!mounted) return;
    context.read<AdminDashboardProvider>().fetchDashboardCounts();
  }

  void _confirmDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${product.name}" (${product.id})?',
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final provider = context.read<ProductProvider>();
              final success = await provider.deleteProduct(product.id);

              if (mounted) {
                if (success) {
                  context.read<AdminDashboardProvider>().fetchDashboardCounts();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Product "${product.name}" deleted.'),
                      backgroundColor: AppColors.darkCharcoal,
                    ),
                  );
                } else if (provider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage!),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: const Text(
          'Spare Parts Catalog',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.lightGold),
            tooltip: 'Refresh Products',
            onPressed: () => provider.fetchProducts(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGold,
        foregroundColor: AppColors.darkCharcoal,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _openProductForm(),
      ),
      body: Column(
        children: [
          // --- SEARCH BAR & FILTERS HEADER ---
          Container(
            color: AppColors.darkCharcoal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => provider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search by Part Name, Ref No, Application...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Company Filter Chips (Horizontal Scroll)
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildFilterChip(
                        label: 'All Brands',
                        isSelected: provider.selectedCompanyId == 'ALL',
                        onTap: () => provider.setSelectedCompanyId('ALL'),
                      ),
                      ...companyProvider.companies.map((c) {
                        return _buildFilterChip(
                          label: c.name,
                          isSelected: provider.selectedCompanyId == c.id,
                          onTap: () => provider.setSelectedCompanyId(c.id),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Category Filter Chips (Horizontal Scroll)
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildFilterChip(
                        label: 'All Categories',
                        isSelected: provider.selectedCategoryId == 'ALL',
                        onTap: () => provider.setSelectedCategoryId('ALL'),
                      ),
                      ...categoryProvider.categories.map((cat) {
                        return _buildFilterChip(
                          label: cat.name,
                          isSelected: provider.selectedCategoryId == cat.id,
                          onTap: () => provider.setSelectedCategoryId(cat.id),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- PRODUCTS LIST BODY ---
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryGold,
              backgroundColor: AppColors.darkCharcoal,
              onRefresh: () => provider.fetchProducts(),
              child: _buildBody(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGold : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primaryGold : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.darkCharcoal : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ProductProvider provider) {
    if (provider.isLoading && provider.products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
        ),
      );
    }

    if (provider.errorMessage != null && provider.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkCharcoal,
                  foregroundColor: AppColors.primaryGold,
                ),
                onPressed: () => provider.fetchProducts(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final list = provider.filteredProducts;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 40,
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Products Found',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                provider.searchQuery.isNotEmpty ||
                        provider.selectedCompanyId != 'ALL' ||
                        provider.selectedCategoryId != 'ALL'
                    ? 'No products match your active search or filters.'
                    : 'Your catalog is empty. Tap "Add Product" to get started.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final product = list[index];
        return _buildProductCard(product, provider);
      },
    );
  }

  Widget _buildProductCard(ProductModel product, ProductProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 84,
                    height: 84,
                    color: Colors.grey.shade100,
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Doc ID and Active Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.darkCharcoal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.id,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (product.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: product.isActive ? AppColors.success : AppColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Product Title
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Brand & Category subtitle
                      Text(
                        '${product.companyName} • ${product.categoryName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryGold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Application compatibility snippet
                      Text(
                        product.application,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey,
                        ),
                      ),

                      if (product.refNo != null && product.refNo!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.tag_rounded, size: 12, color: Colors.grey),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                product.refNo!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Action Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openProductForm(product);
                    } else if (val == 'toggle') {
                      provider.toggleProductActive(product.id, !product.isActive);
                    } else if (val == 'delete') {
                      _confirmDelete(product);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryGold),
                          SizedBox(width: 8),
                          Text('Edit Product', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            product.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            product.isActive ? 'Mark Inactive' : 'Mark Active',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(fontSize: 13, color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
