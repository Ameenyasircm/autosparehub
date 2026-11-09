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

/// Clean, modern e-commerce standard spare parts catalog for administrators.
/// Features a streamlined search & button-driven filter bar, Grid/List view toggle,
/// advanced sorting, and uncluttered product cards.
class ProductsScreen extends StatefulWidget {
  final bool embedded;
  const ProductsScreen({super.key, this.embedded = false});

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

  // ==========================================
  // --- BOTTOM SHEETS (FILTERS & SORTING) ---
  // ==========================================

  void _showAllFiltersSheet(
    BuildContext context,
    ProductProvider provider,
    CompanyProvider companyProvider,
    CategoryProvider categoryProvider,
  ) {
    String tempCompany = provider.selectedCompanyId;
    String tempCategory = provider.selectedCategoryId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasFilterChanges = tempCompany != 'ALL' || tempCategory != 'ALL';

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 14,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.tune_rounded, color: AppColors.primaryGold, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Filter Catalog',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ],
                        ),
                        if (hasFilterChanges)
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempCompany = 'ALL';
                                tempCategory = 'ALL';
                              });
                            },
                            child: const Text(
                              'Reset All',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(color: AppColors.dividerLight),
                    const SizedBox(height: 8),

                    // Brand Filter Section
                    const Text(
                      'Brand / Manufacturer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSheetChip(
                          label: 'All Brands',
                          isSelected: tempCompany == 'ALL',
                          onTap: () => setSheetState(() => tempCompany = 'ALL'),
                        ),
                        ...companyProvider.companies.map((c) {
                          return _buildSheetChip(
                            label: c.name,
                            isSelected: tempCompany == c.id,
                            onTap: () => setSheetState(() => tempCompany = c.id),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Category Filter Section
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSheetChip(
                          label: 'All Categories',
                          isSelected: tempCategory == 'ALL',
                          onTap: () => setSheetState(() => tempCategory = 'ALL'),
                        ),
                        ...categoryProvider.categories.map((cat) {
                          return _buildSheetChip(
                            label: cat.name,
                            isSelected: tempCategory == cat.id,
                            onTap: () => setSheetState(() => tempCategory = cat.id),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Apply Button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.darkButton,
                        foregroundColor: AppColors.warmGold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        provider.setSelectedCompanyId(tempCompany);
                        provider.setSelectedCategoryId(tempCategory);
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBrandSheet(
    BuildContext context,
    ProductProvider provider,
    CompanyProvider companyProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: const [
                      Icon(Icons.business_outlined, color: AppColors.primaryGold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Select Brand',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.dividerLight),
                ListTile(
                  title: const Text('All Brands', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: provider.selectedCompanyId == 'ALL'
                      ? const Icon(Icons.check_circle, color: AppColors.primaryGold)
                      : null,
                  onTap: () {
                    provider.setSelectedCompanyId('ALL');
                    Navigator.pop(ctx);
                  },
                ),
                ...companyProvider.companies.map((c) {
                  final isSelected = provider.selectedCompanyId == c.id;
                  return ListTile(
                    title: Text(
                      c.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? AppColors.darkCharcoal : AppColors.primaryText,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primaryGold)
                        : null,
                    onTap: () {
                      provider.setSelectedCompanyId(c.id);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCategorySheet(
    BuildContext context,
    ProductProvider provider,
    CategoryProvider categoryProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: const [
                      Icon(Icons.category_outlined, color: AppColors.primaryGold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Select Category',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.dividerLight),
                ListTile(
                  title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: provider.selectedCategoryId == 'ALL'
                      ? const Icon(Icons.check_circle, color: AppColors.primaryGold)
                      : null,
                  onTap: () {
                    provider.setSelectedCategoryId('ALL');
                    Navigator.pop(ctx);
                  },
                ),
                ...categoryProvider.categories.map((cat) {
                  final isSelected = provider.selectedCategoryId == cat.id;
                  return ListTile(
                    title: Text(
                      cat.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? AppColors.darkCharcoal : AppColors.primaryText,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primaryGold)
                        : null,
                    onTap: () {
                      provider.setSelectedCategoryId(cat.id);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
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
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
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
                const Divider(color: AppColors.dividerLight),
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
          color: isSelected ? AppColors.darkCharcoal : AppColors.primaryText,
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

  Widget _buildSheetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkCharcoal : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.darkCharcoal : const Color(0xFFE2E6EC),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.warmGold : AppColors.darkCharcoal,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // --- MAIN BUILD METHOD ---
  // ==========================================

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
        automaticallyImplyLeading: !widget.embedded,
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Spare Parts Catalog',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
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
        label: const Text('Add Spare', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _openProductForm(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // --- TOP SEARCH & ACTION BUTTONS BAR ---
            _buildTopControlBar(provider, companyProvider, categoryProvider, filteredCount, totalCount),

            // --- PRODUCTS CATALOG BODY ---
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
      ),
    );
  }

  // ==========================================
  // --- TOP CONTROL BAR (SEARCH + BUTTONS) ---
  // ==========================================

  Widget _buildTopControlBar(
    ProductProvider provider,
    CompanyProvider companyProvider,
    CategoryProvider categoryProvider,
    int filteredCount,
    int totalCount,
  ) {
    final hasCompanyFilter = provider.selectedCompanyId != 'ALL';
    final hasCategoryFilter = provider.selectedCategoryId != 'ALL';
    final activeFilterCount = (hasCompanyFilter ? 1 : 0) + (hasCategoryFilter ? 1 : 0);

    // Resolve Brand Display Name
    String brandLabel = 'Brand: All';
    if (hasCompanyFilter) {
      final match = companyProvider.companies.where((c) => c.id == provider.selectedCompanyId);
      brandLabel = match.isNotEmpty ? match.first.name : 'Brand';
    }

    // Resolve Category Display Name
    String categoryLabel = 'Category: All';
    if (hasCategoryFilter) {
      final match = categoryProvider.categories.where((c) => c.id == provider.selectedCategoryId);
      categoryLabel = match.isNotEmpty ? match.first.name : 'Category';
    }

    // Resolve Sort Label
    String sortLabel = 'Newest';
    switch (provider.sortOption) {
      case ProductSortOption.newest:
        sortLabel = 'Newest';
        break;
      case ProductSortOption.priceLowToHigh:
        sortLabel = 'Price: Low';
        break;
      case ProductSortOption.priceHighToLow:
        sortLabel = 'Price: High';
        break;
      case ProductSortOption.nameAZ:
        sortLabel = 'Name: A-Z';
        break;
      case ProductSortOption.stockHighToLow:
        sortLabel = 'Stock: High';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE9ECEF), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Search Bar Input
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E8EE)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13.5, color: AppColors.darkCharcoal),
              onChanged: (val) => provider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search part name, Application No, Sorl No...',
                hintStyle: const TextStyle(color: Color(0xFF9AA3AF), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryGold, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 2. Button-Driven Filter Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // All Filters Button (With Badge)
                _buildFilterButton(
                  icon: Icons.tune_rounded,
                  label: 'Filters',
                  badgeCount: activeFilterCount > 0 ? activeFilterCount : null,
                  isActive: activeFilterCount > 0,
                  onTap: () => _showAllFiltersSheet(context, provider, companyProvider, categoryProvider),
                ),
                const SizedBox(width: 8),

                // Brand Filter Button
                _buildFilterButton(
                  icon: Icons.business_outlined,
                  label: brandLabel,
                  isActive: hasCompanyFilter,
                  showDropdownArrow: true,
                  onTap: () => _showBrandSheet(context, provider, companyProvider),
                ),
                const SizedBox(width: 8),

                // Category Filter Button
                _buildFilterButton(
                  icon: Icons.category_outlined,
                  label: categoryLabel,
                  isActive: hasCategoryFilter,
                  showDropdownArrow: true,
                  onTap: () => _showCategorySheet(context, provider, categoryProvider),
                ),
                const SizedBox(width: 8),

                // Sort Button
                _buildFilterButton(
                  icon: Icons.swap_vert_rounded,
                  label: sortLabel,
                  isActive: provider.sortOption != ProductSortOption.newest,
                  showDropdownArrow: true,
                  onTap: () => _showSortSheet(context, provider),
                ),

                // Clear Filters Shortcut Button (when any filter is active)
                if (hasCompanyFilter || hasCategoryFilter || provider.searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      provider.clearFilters();
                    },
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.close_rounded, size: 14, color: AppColors.error),
                          SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 3. Compact Count Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $filteredCount of $totalCount spare parts',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              if (activeFilterCount > 0 || provider.searchQuery.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Filter Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool showDropdownArrow = false,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isActive ? AppColors.primaryGold : const Color(0xFFDDE2E8),
            width: isActive ? 1.3 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? AppColors.darkCharcoal : const Color(0xFF6A7381),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppColors.darkCharcoal : const Color(0xFF2C333E),
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: const BoxDecoration(
                  color: AppColors.darkCharcoal,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warmGold,
                  ),
                ),
              ),
            ],
            if (showDropdownArrow) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Color(0xFF8892A0),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // --- CATALOG CONTENT BODY ---
  // ==========================================

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
                    : 'Your catalog is empty. Tap "Add Spare" to get started.',
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

  // ==========================================
  // --- 2-COLUMN GRID VIEW ---
  // ==========================================

  Widget _buildGridView(List<ProductModel> list, ProductProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final int crossAxisCount = availableWidth >= 1100
            ? 4
            : (availableWidth >= 680 ? 3 : 2);
        final double totalHorizontalGutter = 28 + (crossAxisCount - 1) * 12;
        final double columnWidth = (availableWidth - totalHorizontalGutter) / crossAxisCount;
        final double imageHeight = columnWidth / 1.35;
        const double detailsHeight = 154.0;
        final double cardHeight = (imageHeight + detailsHeight).roundToDouble();

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final product = list[index];
            return _buildGridCard(product, provider);
          },
        );
      },
    );
  }

  Widget _buildGridCard(ProductModel product, ProductProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with Overlays
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                    child: AspectRatio(
                      aspectRatio: 1.35,
                      child: Container(
                        color: const Color(0xFFF6F8FA),
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 34),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Stock Badge (Top Right)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _buildStockBadge(product.stockQuantity),
                  ),

                  // Inactive Pill (Top Left)
                  if (!product.isActive)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

              // Card Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand & Category
                      Text(
                        '${product.companyName} • ${product.categoryName}'.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondaryGold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Product Title
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
                      const SizedBox(height: 4),

                      // Application No
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined, size: 12, color: Color(0xFF7A8499)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              'App: ${product.application}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Sorl No (if present)
                      if (product.refNo != null && product.refNo!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.tag_rounded, size: 12, color: AppColors.primaryGold),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                'Sorl: ${product.refNo!}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const Spacer(),

                      // Price & Action Menu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
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

  // ==========================================
  // --- COMPACT LIST VIEW ---
  // ==========================================

  Widget _buildListView(List<ProductModel> list, ProductProvider provider) {
    final isTablet = MediaQuery.of(context).size.width >= 720;
    if (isTablet) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 88),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 140,
          crossAxisSpacing: 12,
          mainAxisSpacing: 10,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final product = list[index];
          return _buildListCard(product, provider);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 88),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Thumbnail
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 82,
                        height: 82,
                        color: const Color(0xFFF6F8FA),
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
                          Expanded(
                            child: Text(
                              '${product.companyName} • ${product.categoryName}'.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.secondaryGold,
                              ),
                            ),
                          ),
                          _buildStockBadge(product.stockQuantity),
                        ],
                      ),

                      const SizedBox(height: 3),

                      // Product Title
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),

                      const SizedBox(height: 3),

                      // Application No & Sorl No
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined, size: 12, color: Color(0xFF7A8499)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              'App: ${product.application}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          if (product.refNo != null && product.refNo!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.tag_rounded, size: 12, color: AppColors.primaryGold),
                            const SizedBox(width: 2),
                            Text(
                              'Sorl: ${product.refNo!}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 5),

                      // Price Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            product.price != null
                                ? '₹ ${product.price!.toStringAsFixed(2)}'
                                : 'Price on Req',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.darkCharcoal,
                            ),
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

  // ==========================================
  // --- SHARED WIDGET HELPERS ---
  // ==========================================

  Widget _buildStockBadge(int? stock) {
    if (stock == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('Stock: —', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
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
        ? 'Out'
        : isLowStock
            ? 'Low ($stock)'
            : 'Stock ($stock)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColor),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(ProductModel product, ProductProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF8892A0), size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
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
