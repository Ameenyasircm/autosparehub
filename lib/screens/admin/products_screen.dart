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

/// Attractive e-commerce standard spare parts catalog with 2-column Grid / List view toggle,
/// advanced sorting, live filters, and rich automotive product cards.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  bool _isGridView = true;

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

  void _showSortSheet(BuildContext context, ProductProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: const [
                      Icon(Icons.sort_rounded, color: AppColors.primaryGold),
                      SizedBox(width: 8),
                      Text(
                        'Sort Products By',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _buildSortTile(
                  title: 'Newest Added First',
                  option: ProductSortOption.newest,
                  provider: provider,
                  ctx: ctx,
                ),
                _buildSortTile(
                  title: 'Price: Low to High',
                  option: ProductSortOption.priceLowToHigh,
                  provider: provider,
                  ctx: ctx,
                ),
                _buildSortTile(
                  title: 'Price: High to Low',
                  option: ProductSortOption.priceHighToLow,
                  provider: provider,
                  ctx: ctx,
                ),
                _buildSortTile(
                  title: 'Product Name: A to Z',
                  option: ProductSortOption.nameAZ,
                  provider: provider,
                  ctx: ctx,
                ),
                _buildSortTile(
                  title: 'Highest Stock First',
                  option: ProductSortOption.stockHighToLow,
                  provider: provider,
                  ctx: ctx,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortTile({
    required String title,
    required ProductSortOption option,
    required ProductProvider provider,
    required BuildContext ctx,
  }) {
    final isSelected = provider.sortOption == option;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          color: isSelected ? AppColors.darkCharcoal : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primaryGold)
          : null,
      onTap: () {
        provider.setSortOption(option);
        Navigator.pop(ctx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final totalCount = provider.products.length;
    final filteredCount = provider.filteredProducts.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Spare Parts Catalog',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Text(
                '$totalCount',
                style: const TextStyle(
                  color: AppColors.lightGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppColors.lightGold,
            ),
            tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh Products',
            onPressed: () => provider.fetchProducts(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGold,
        foregroundColor: AppColors.darkCharcoal,
        elevation: 4,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _openProductForm(),
      ),
      body: Column(
        children: [
          // --- TOP SEARCH & HORIZONTAL FILTER STRIPS ---
          Container(
            color: AppColors.darkCharcoal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              children: [
                // Modern Search Input
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  onChanged: (val) => provider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search part name, OEM ref, application...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold, size: 20),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

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

          // --- SUBHEADER TOOLBAR (Live Count, Active Filters & Sort trigger) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Count and Active filter clear
                Row(
                  children: [
                    Text(
                      'Showing $filteredCount of $totalCount parts',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    if (provider.selectedCompanyId != 'ALL' ||
                        provider.selectedCategoryId != 'ALL' ||
                        provider.searchQuery.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          provider.clearFilters();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Clear Filters ×',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Sort Dropdown Button
                InkWell(
                  onTap: () => _showSortSheet(context, provider),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.swap_vert_rounded, size: 16, color: AppColors.primaryGold),
                        SizedBox(width: 4),
                        Text(
                          'Sort',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),
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
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 44,
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Products Found',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                provider.searchQuery.isNotEmpty ||
                        provider.selectedCompanyId != 'ALL' ||
                        provider.selectedCategoryId != 'ALL'
                    ? 'No products match your active search or filters.'
                    : 'Your catalog is empty. Tap "Add Product" to get started.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              if (provider.searchQuery.isNotEmpty ||
                  provider.selectedCompanyId != 'ALL' ||
                  provider.selectedCategoryId != 'ALL') ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkCharcoal,
                    side: const BorderSide(color: AppColors.primaryGold),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    provider.clearFilters();
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Reset All Filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _isGridView
        ? _buildGridView(list, provider)
        : _buildListView(list, provider);
  }

  // --- 2-COLUMN E-COMMERCE GRID VIEW ---
  Widget _buildGridView(List<ProductModel> list, ProductProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 84),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final product = list[index];
        return _buildGridCard(product, provider);
      },
    );
  }

  Widget _buildGridCard(ProductModel product, ProductProvider provider) {
    return Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HERO IMAGE WITH BADGES ---
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: AspectRatio(
                      aspectRatio: 1.15,
                      child: Container(
                        color: Colors.grey.shade100,
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Brand Tag (Top Left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.darkCharcoal.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.companyName.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.lightGold,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),

                  // Stock Badge (Top Right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildStockBadge(product.stockQuantity),
                  ),

                  // Ref No Pill (Bottom Left if present)
                  if (product.refNo != null && product.refNo!.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          product.refNo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // --- CARD DETAILS ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      Text(
                        product.categoryName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondaryGold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Product Name
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Application fitment snippet
                      Text(
                        product.application,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                          height: 1.2,
                        ),
                      ),

                      const Spacer(),

                      // Price and Action Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Price
                          Expanded(
                            child: product.price != null
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'PRICE',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        '₹ ${product.price!.toStringAsFixed(2)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.darkCharcoal,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Price N/A',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),

                          // Quick Action Menu
                          _buildActionMenu(product, provider),
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

  // --- COMPACT LIST VIEW ---
  Widget _buildListView(List<ProductModel> list, ProductProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 84),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final product = list[index];
        return _buildListCard(product, provider);
      },
    );
  }

  Widget _buildListCard(ProductModel product, ProductProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 90,
                        height: 90,
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
                    if (!product.isActive)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Inactive',
                            style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Brand & Stock Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${product.companyName} • ${product.categoryName}'.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondaryGold,
                            ),
                          ),
                          _buildStockBadge(product.stockQuantity),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Product Title
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),

                      const SizedBox(height: 3),

                      // Application compatibility snippet
                      Text(
                        product.application,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      if (product.refNo != null && product.refNo!.isNotEmpty) ...[
                        const SizedBox(height: 3),
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

                      const SizedBox(height: 6),

                      // Price Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (product.price != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primaryGold.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '₹ ${product.price!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            )
                          else
                            const Text(
                              'Price: Not Set',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          _buildActionMenu(product, provider),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockBadge(int? stock) {
    if (stock == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('Stock: —', style: TextStyle(fontSize: 9, color: Colors.grey)),
      );
    }

    final isOutOfStock = stock <= 0;
    final isLowStock = stock > 0 && stock <= 5;

    final badgeColor = isOutOfStock
        ? AppColors.error
        : isLowStock
            ? Colors.orange.shade800
            : AppColors.success;

    final label = isOutOfStock
        ? 'Out of Stock'
        : isLowStock
            ? 'Low ($stock)'
            : 'In Stock ($stock)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColor),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(ProductModel product, ProductProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 18),
      padding: EdgeInsets.zero,
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
              Icon(Icons.edit_outlined, size: 16, color: AppColors.primaryGold),
              SizedBox(width: 8),
              Text('Edit Product', style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                product.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 16,
                color: Colors.grey,
              ),
              SizedBox(width: 8),
              Text(
                product.isActive ? 'Mark Inactive' : 'Mark Active',
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(fontSize: 12.5, color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}
