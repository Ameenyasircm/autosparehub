import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';
import 'cart_screen.dart';
import 'user_login_screen.dart';
import 'user_orders_screen.dart';
import 'user_product_detail_screen.dart';
import 'widgets/approval_pending_dialog.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/contact_us_sheet.dart';

/// Customer Storefront Home Screen matching Image 5 with pixel-level precision:
/// - Dark AppBar (#12151B) with circular logo, "AUTO SPARE HUB" rich title, and rounded square cart button with badge dot
/// - White pill search bar ("Search Spare") with unbroken outline
/// - Category pill filter bar (Engine Parts, Brake System, Filters, Electrical, etc.)
/// - 2-Column Product Grid with category tag pills, centered image, part number, bold price, and "+ Add to Cart" outlined button
/// - 3-Tab Bottom Navigation Bar (Home, My Orders, Profile) with warm gold dot active indicator
class UserHomeScreen extends StatefulWidget {
  final bool showPendingAlertOnStart;
  final String? pendingPhone;

  const UserHomeScreen({
    super.key,
    this.showPendingAlertOnStart = false,
    this.pendingPhone,
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentTabIndex = 0;
  final _searchController = TextEditingController();
  bool _isInitialLoading = true;
  bool _isCheckingApproval = false;
  CategoryModel? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _isInitialLoading = context.read<ProductProvider>().products.isEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<UserAuthProvider>().initSession();
      if (!mounted) return;
      final auth = context.read<UserAuthProvider>();
      if (auth.currentCustomer != null) {
        final cust = auth.currentCustomer!;
        if (auth.isApproved) {
          context.read<CartProvider>().loadCartForUser(cust.id);
        }
        context.read<OrderProvider>().fetchCustomerOrders(cust.id, userPhone: cust.phone);
      }

      if (widget.showPendingAlertOnStart) {
        final phone = widget.pendingPhone ?? auth.currentCustomer?.phone ?? '';
        ApprovalPendingDialog.show(context, phone: phone);
      }

      final compProvider = context.read<CompanyProvider>();
      if (compProvider.companies.isEmpty) compProvider.fetchCompanies();

      final catProvider = context.read<CategoryProvider>();
      if (catProvider.categories.isEmpty) catProvider.fetchCategories();

      await context.read<ProductProvider>().fetchProducts();
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _showExitConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.darkHeader,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: AppColors.warmGold,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Exit App?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkHeader,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit SN AutoSpare Hub?',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.darkCharcoal,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkButton,
              foregroundColor: AppColors.warmGold,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Exit',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<UserAuthProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If user is inside a category view, back button returns to categories grid
        if (_selectedCategory != null) {
          setState(() {
            _selectedCategory = null;
            _searchController.clear();
            context.read<ProductProvider>().setSelectedCategoryId('ALL');
            context.read<ProductProvider>().setSearchQuery('');
          });
          return;
        }

        // If user is on Orders or Profile tab, switch back to Home tab first
        if (_currentTabIndex != 0) {
          setState(() => _currentTabIndex = 0);
          return;
        }

        final shouldExit = await _showExitConfirmDialog(context);
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: _buildTopAppBar(context, cart, auth),
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildStorefrontCatalogTab(context),
              const UserOrdersScreen(showAppBar: false),
              _buildProfileTab(context, auth),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: _buildBottomNav(context),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. TOP APP BAR (MATCHING IMAGE 5)
  // =========================================================================
  PreferredSizeWidget _buildTopAppBar(
    BuildContext context,
    CartProvider cart,
    UserAuthProvider auth,
  ) {
    return AppBar(
      backgroundColor: AppColors.darkHeader,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Logo Emblem
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.warmGold.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/AutoSpareLogo.jpg',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.settings_suggest_rounded,
                  color: AppColors.warmGold,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Brand Title: "AUTO SPARE HUB" with "MANJERI"
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'AUTO SPARE ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'HUB',
                      style: TextStyle(
                        color: AppColors.warmGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                'MANJERI',
                style: TextStyle(
                  color: AppColors.warmGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                  letterSpacing: 2.2,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Pending Status Quick Chip (if applicable)
        if (auth.isPending)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: InkWell(
              onTap: () => setState(() => _currentTabIndex = 2),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Rounded Square Cart Button (matching Image 5 top right)
        Padding(
          padding: const EdgeInsets.only(right: 14, left: 6),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF22262F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: AppColors.warmGold,
                      size: 21,
                    ),
                    if (cart.totalItemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. STOREFRONT CATALOG TAB (CATEGORY-FIRST BROWSING)
  // =========================================================================
  Widget _buildStorefrontCatalogTab(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    if (_isInitialLoading || categoryProvider.isLoading) {
      return _buildLoadingState();
    }

    if (_selectedCategory == null) {
      return _buildCategoriesView(context, categoryProvider, productProvider);
    } else {
      return _buildCategorySparesView(
        context,
        _selectedCategory!,
        categoryProvider,
        companyProvider,
        productProvider,
      );
    }
  }

  // --- 2A. CATEGORIES BROWSING VIEW ---
  Widget _buildCategoriesView(
    BuildContext context,
    CategoryProvider categoryProvider,
    ProductProvider productProvider,
  ) {
    final activeCategories = categoryProvider.categories.where((c) => c.isActive).toList();
    final query = _searchController.text.trim().toLowerCase();
    final isSearching = query.isNotEmpty;

    // Matching products globally across all categories
    final searchProducts = isSearching
        ? productProvider.products.where((p) {
            if (!p.isActive) return false;
            return p.name.toLowerCase().contains(query) ||
                (p.refNo?.toLowerCase().contains(query) ?? false) ||
                p.application.toLowerCase().contains(query) ||
                (p.description?.toLowerCase().contains(query) ?? false) ||
                p.companyName.toLowerCase().contains(query) ||
                p.categoryName.toLowerCase().contains(query) ||
                p.searchKeywords.any((k) => k.contains(query));
          }).toList()
        : <ProductModel>[];

    // Matching categories
    final filteredCategories = isSearching
        ? activeCategories.where((c) {
            final nameMatch = c.name.toLowerCase().contains(query);
            final descMatch = c.description?.toLowerCase().contains(query) ?? false;
            return nameMatch || descMatch;
          }).toList()
        : activeCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Global Search Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFDDE1E6), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF8C95A6),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.darkHeader,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (val) {
                    productProvider.setSearchQuery(val);
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search spare parts, part no, model...',
                    hintStyle: TextStyle(
                      color: Color(0xFF8C95A6),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF8C95A6), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                    setState(() {});
                  },
                ),
            ],
          ),
        ),

        // When user is searching and products match: show global products search results
        if (isSearching && searchProducts.isNotEmpty) ...[
          // Matching categories quick jump strip (if any category name matches)
          if (filteredCategories.isNotEmpty) ...[
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...filteredCategories.map((cat) {
                    return _buildCategoryPill(
                      label: cat.name,
                      isSelected: false,
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                          _searchController.clear();
                          productProvider.setSelectedCategoryId(cat.id);
                          productProvider.setSearchQuery('');
                        });
                      },
                      isCompact: true,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Search Results Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${searchProducts.length} Spares Found (All Categories)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkHeader,
                    letterSpacing: -0.2,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                    setState(() {});
                  },
                  child: const Text(
                    'Clear Search ×',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2-Column Global Product Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.67,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: searchProducts.length,
              itemBuilder: (context, index) {
                return _buildProductCard(context, searchProducts[index]);
              },
            ),
          ),
        ] else if (isSearching && searchProducts.isEmpty && filteredCategories.isNotEmpty) ...[
          // When searching matched categories but no specific products
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredCategories.length} Categories matching "$query"',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkHeader,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                    setState(() {});
                  },
                  child: const Text(
                    'Clear Search ×',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.84,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredCategories.length,
              itemBuilder: (context, index) {
                final category = filteredCategories[index];
                final spareCount = productProvider.products
                    .where((p) => p.isActive && p.categoryId == category.id)
                    .length;
                return _buildCategoryCard(
                  context,
                  category,
                  spareCount,
                  productProvider,
                );
              },
            ),
          ),
        ] else if (isSearching && searchProducts.isEmpty && filteredCategories.isEmpty) ...[
          Expanded(child: _buildEmptyCategoriesState(query)),
        ] else ...[
          // Default Browsing State: Section Title & Counter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Spare Categories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkHeader,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  '${filteredCategories.length} Categories',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

          // Categories Grid
          Expanded(
            child: RefreshIndicator(
              color: AppColors.warmGold,
              backgroundColor: AppColors.darkHeader,
              onRefresh: () async {
                await Future.wait([
                  categoryProvider.fetchCategories(),
                  productProvider.fetchProducts(),
                ]);
              },
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.84,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filteredCategories.length,
                itemBuilder: (context, index) {
                  final category = filteredCategories[index];
                  final spareCount = productProvider.products
                      .where((p) => p.isActive && p.categoryId == category.id)
                      .length;
                  return _buildCategoryCard(
                    context,
                    category,
                    spareCount,
                    productProvider,
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- CATEGORY CARD ITEM ---
  Widget _buildCategoryCard(
    BuildContext context,
    CategoryModel category,
    int spareCount,
    ProductProvider productProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedCategory = category;
              _searchController.clear();
              productProvider.setSelectedCategoryId(category.id);
              productProvider.setSearchQuery('');
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Image Frame
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: category.imageUrl.isNotEmpty
                          ? Image.network(
                              category.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _buildCategoryFallbackIcon(),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.warmGold,
                                    ),
                                  ),
                                );
                              },
                            )
                          : _buildCategoryFallbackIcon(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Category Name
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkHeader,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                // Spare Count and Forward Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$spareCount ${spareCount == 1 ? 'Part' : 'Parts'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.badgeGoldBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppColors.badgeGoldText,
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

  // --- 2B. CATEGORY SPARES VIEW (LISTING ALL SPARES IN SELECTED CATEGORY) ---
  Widget _buildCategorySparesView(
    BuildContext context,
    CategoryModel category,
    CategoryProvider categoryProvider,
    CompanyProvider companyProvider,
    ProductProvider productProvider,
  ) {
    // Products belonging to this category
    final categoryProducts = productProvider.products
        .where((p) => p.isActive && p.categoryId == category.id)
        .toList();

    // Companies present within this category
    final categoryCompanyIds = categoryProducts.map((p) => p.companyId).toSet();
    final availableCompanies = companyProvider.companies
        .where((c) => categoryCompanyIds.contains(c.id))
        .toList();
    final bool showCompanyFilter = availableCompanies.length >= 2;

    final isSearching = productProvider.searchQuery.trim().isNotEmpty;

    // Filtered products for display:
    // When searching, product search is global across all categories without restriction!
    // When not searching, display parts belonging to this selected category.
    final displayedProducts = isSearching
        ? productProvider.filteredProducts.where((p) => p.isActive).toList()
        : productProvider.filteredProducts
            .where((p) => p.isActive && p.categoryId == category.id)
            .toList();

    return Column(
      children: [
        // Top Category Navigation Header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Back Button to Categories
              InkWell(
                onTap: () => _onBackToCategories(productProvider),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.darkHeader,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.arrow_back_rounded, color: AppColors.warmGold, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Categories',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Category Title and Count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkHeader,
                      ),
                    ),
                    Text(
                      '${categoryProducts.length} Parts Available',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              // Category Image Thumbnail
              if (category.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    color: const Color(0xFFF1F5F9),
                    child: Image.network(
                      category.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.category_outlined,
                        size: 20,
                        color: AppColors.warmGold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Search Bar (Within Category)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFDDE1E6), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF8C95A6),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.darkHeader,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (val) => productProvider.setSearchQuery(val),
                  decoration: const InputDecoration(
                    hintText: 'Search spare parts across all categories...',
                    hintStyle: TextStyle(
                      color: Color(0xFF8C95A6),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF8C95A6), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    productProvider.setSearchQuery('');
                  },
                ),
            ],
          ),
        ),

        // Quick Category Jump Bar
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ...categoryProvider.categories.where((c) => c.isActive).map((cat) {
                final isSelected = cat.id == category.id;
                return _buildCategoryPill(
                  label: cat.name,
                  isSelected: isSelected,
                  onTap: () {
                    if (!isSelected) {
                      setState(() {
                        _selectedCategory = cat;
                        _searchController.clear();
                        productProvider.setSelectedCategoryId(cat.id);
                        productProvider.setSearchQuery('');
                      });
                    }
                  },
                  isCompact: true,
                );
              }),
            ],
          ),
        ),

        // Conditional Company Filter Strip (if >= 2 companies in this category)
        if (showCompanyFilter) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryPill(
                  label: 'All Makes',
                  isSelected: productProvider.selectedCompanyId == 'ALL',
                  onTap: () => productProvider.setSelectedCompanyId('ALL'),
                  isCompact: true,
                ),
                ...availableCompanies.map((comp) {
                  return _buildCategoryPill(
                    label: comp.name,
                    isSelected: productProvider.selectedCompanyId == comp.id,
                    onTap: () => productProvider.setSelectedCompanyId(comp.id),
                    isCompact: true,
                  );
                }),
              ],
            ),
          ),
        ],

        // Filter Status Row
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSearching
                    ? '${displayedProducts.length} Spares Found (All Categories)'
                    : '${displayedProducts.length} Parts in ${category.name}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText,
                ),
              ),
              if (productProvider.selectedCompanyId != 'ALL' ||
                  productProvider.searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    productProvider.clearFilters();
                    productProvider.setSelectedCategoryId(category.id);
                  },
                  child: const Text(
                    'Clear Search ×',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2-Column Product Grid
        Expanded(
          child: RefreshIndicator(
            color: AppColors.warmGold,
            backgroundColor: AppColors.darkHeader,
            onRefresh: () => productProvider.fetchProducts(),
            child: displayedProducts.isEmpty
                ? _buildEmptyCategorySparesState(category, productProvider)
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.58,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: displayedProducts.length,
                    itemBuilder: (context, index) {
                      return _buildProductCard(context, displayedProducts[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _onBackToCategories(ProductProvider productProvider) {
    setState(() {
      _selectedCategory = null;
      _searchController.clear();
      productProvider.setSelectedCategoryId('ALL');
      productProvider.setSearchQuery('');
    });
  }

  Widget _buildCategoryFallbackIcon() {
    return Container(
      color: const Color(0xFFF7F8FA),
      child: const Center(
        child: Icon(
          Icons.category_outlined,
          color: AppColors.warmGold,
          size: 38,
        ),
      ),
    );
  }

  Widget _buildEmptyCategoriesState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              query.isNotEmpty ? 'No Matching Categories' : 'No Categories Found',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              query.isNotEmpty
                  ? 'No categories match "$query". Try searching with another keyword.'
                  : 'Spare parts categories will appear here once added.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkCharcoal,
                  side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                child: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategorySparesState(CategoryModel category, ProductProvider provider) {
    final isSearching = provider.searchQuery.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 52, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              isSearching
                  ? 'No Matching Spares Found'
                  : 'No Spares in ${category.name}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'No parts match "${provider.searchQuery}" across any category.'
                  : 'Parts in this category will be available soon.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSearching || provider.selectedCompanyId != 'ALL') ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkCharcoal,
                      side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      provider.clearFilters();
                      provider.setSelectedCategoryId(category.id);
                    },
                    child: const Text('Clear Search'),
                  ),
                  const SizedBox(width: 10),
                ],
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkButton,
                    foregroundColor: AppColors.warmGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _onBackToCategories(provider),
                  child: const Text('All Categories'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- CATEGORY PILL ITEM ---
  Widget _buildCategoryPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 11 : 14,
            vertical: isCompact ? 4 : 7,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkButton : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.warmGold : const Color(0xFFDDE1E6),
              width: 1.1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 11.5 : 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.warmGold : const Color(0xFF2C323E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 2-COLUMN PRODUCT CARD (MATCHING IMAGE 5 WITH PERFECTION) ---
  Widget _buildProductCard(BuildContext context, ProductModel product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            UserProductDetailScreen.show(context, product);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Category Tag Pill (e.g., "Engine Parts")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppColors.badgeGoldBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.badgeGoldBorder, width: 1),
                  ),
                  child: Text(
                    product.categoryName.isNotEmpty ? product.categoryName : 'Spare Part',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.badgeGoldText,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Centered Product Image
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(
                            Icons.car_repair,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Product Title (e.g., "Engine Oil Filter")
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryText,
                  ),
                ),

                const SizedBox(height: 2),

                // Part Number (e.g., "Part No. OF-1024")
                Text(
                  product.refNo != null && product.refNo!.isNotEmpty
                      ? 'Part No. ${product.refNo}'
                      : (product.application.isNotEmpty ? product.application : 'Genuine OEM Part'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7A8499),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 6),

                // Price (e.g., "₹1522")
                Text(
                  product.price != null
                      ? '₹${product.price!.toStringAsFixed(0)}'
                      : 'Price on Req',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryText,
                  ),
                ),

                const SizedBox(height: 8),

                // Outlined "+ Add to Cart" Button (Matching Image 5)
                // Note: Crisp, unbroken, complete rounded rectangular border
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    context.read<CartProvider>().addToCart(product);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${product.name} to cart'),
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
                  },
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFBFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD6DAE2),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add, size: 15, color: AppColors.primaryGold),
                        SizedBox(width: 4),
                        Text(
                          'Add to Cart',
                          style: TextStyle(
                            fontSize: 11.5,
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
        ),
      ),
    );
  }

  // --- LOADING CATALOG STATE ---
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(
            color: AppColors.warmGold,
            strokeWidth: 2.8,
          ),
          SizedBox(height: 16),
          Text(
            'Loading spare parts...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _handleCheckApprovalStatus(UserAuthProvider auth) async {
    if (_isCheckingApproval) return;
    setState(() => _isCheckingApproval = true);
    try {
      await auth.refreshApprovalStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  auth.isApproved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                  color: auth.isApproved ? Colors.greenAccent : AppColors.warmGold,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    auth.isApproved
                        ? 'Account approved! You can now place orders.'
                        : 'Still pending administrator review.',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.darkHeader,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
    } finally {
      if (mounted) setState(() => _isCheckingApproval = false);
    }
  }

  // =========================================================================
  // 3. PROFILE / ACCOUNT TAB
  // =========================================================================
  Widget _buildProfileTab(BuildContext context, UserAuthProvider auth) {
    if (!auth.isRegistered) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkHeader,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmGold.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/AutoSpareLogo.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Welcome to Auto Spare Hub',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkHeader,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with your garage mobile number to view orders, check approval status, and manage spare part requests.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkButton,
                    foregroundColor: AppColors.warmGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UserLoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Login to Garage',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkCharcoal,
                    side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UserLoginScreen(initialIsRegister: true),
                      ),
                    );
                  },
                  child: const Text(
                    'Register New Garage',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => ContactUsSheet.show(context),
                icon: const Icon(Icons.support_agent_rounded, size: 18, color: AppColors.warmGold),
                label: const Text(
                  'Need Help? Contact Us',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkHeader,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Logged in User Profile Details
    final customer = auth.currentCustomer;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Garage Info Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E9F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.darkHeader,
                    child: Text(
                      customer?.name.isNotEmpty == true
                          ? customer!.name[0].toUpperCase()
                          : 'G',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warmGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer?.name ?? 'Garage User',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkHeader,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '+91 ${customer?.phone ?? ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Status Pill
              if (auth.isApproved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Verified & Approved Garage Customer',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else if (auth.isPending)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              color: Color(0xFFD97706),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Awaiting Administrator Approval',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your garage account registration has been submitted and is currently being reviewed. Once authorized, you can place orders directly.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'നിങ്ങളുടെ രജിസ്ട്രേഷൻ അഡ്മിൻ പരിശോധിച്ചുകൊണ്ടിരിക്കുകയാണ്. പരിശോധന പൂർത്തിയാക്കിയ ശേഷം അഡ്മിൻ നിങ്ങളെ ഉടൻ ബന്ധപ്പെടുന്നതാണ്. ദയവായി കാത്തിരിക്കുക!',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 1,
                        color: const Color(0xFFFDE68A).withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // InkWell(
                          //   onTap: () => ApprovalPendingDialog.show(
                          //     context,
                          //     phone: customer?.phone ?? '',
                          //   ),
                          //   borderRadius: BorderRadius.circular(6),
                          //   child: Padding(
                          //     padding: const EdgeInsets.symmetric(vertical: 4),
                          //     child: Row(
                          //       mainAxisSize: MainAxisSize.min,
                          //       children: [
                          //         Image.asset(
                          //           'assets/member_whats_app.png',
                          //           width: 15,
                          //           height: 15,
                          //         ),
                          //         const SizedBox(width: 5),
                          //         const Text(
                          //           'Contact Admin',
                          //           style: TextStyle(
                          //             fontSize: 11.5,
                          //             fontWeight: FontWeight.w700,
                          //             color: Color(0xFF92400E),
                          //             decoration: TextDecoration.underline,
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                          // ), // InkWell(
                          //   onTap: () => ApprovalPendingDialog.show(
                          //     context,
                          //     phone: customer?.phone ?? '',
                          //   ),
                          //   borderRadius: BorderRadius.circular(6),
                          //   child: Padding(
                          //     padding: const EdgeInsets.symmetric(vertical: 4),
                          //     child: Row(
                          //       mainAxisSize: MainAxisSize.min,
                          //       children: [
                          //         Image.asset(
                          //           'assets/member_whats_app.png',
                          //           width: 15,
                          //           height: 15,
                          //         ),
                          //         const SizedBox(width: 5),
                          //         const Text(
                          //           'Contact Admin',
                          //           style: TextStyle(
                          //             fontSize: 11.5,
                          //             fontWeight: FontWeight.w700,
                          //             color: Color(0xFF92400E),
                          //             color: Color(0xFF92400E),
                          //             decoration: TextDecoration.underline,
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                          // ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isCheckingApproval ? null : () => _handleCheckApprovalStatus(auth),
                              borderRadius: BorderRadius.circular(20),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.darkHeader, Color(0xFF2C303B)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.warmGold.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.darkHeader.withValues(alpha: 0.18),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isCheckingApproval)
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.warmGold,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.sync_rounded,
                                        size: 14,
                                        color: AppColors.warmGold,
                                      ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Check Approval Status',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Settings / Actions List
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E9F0)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: AppColors.warmGold),
                title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () => setState(() => _currentTabIndex = 1),
              ),
              const Divider(height: 1, color: AppColors.dividerLight),
              ListTile(
                leading: const Icon(Icons.support_agent_rounded, color: AppColors.warmGold),
                title: const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () => ContactUsSheet.show(context),
              ),
              const Divider(height: 1, color: AppColors.dividerLight),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded, color: AppColors.warmGold),
                title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () => ChangeUserPasswordDialog.show(context),
              ),
              const Divider(height: 1, color: AppColors.dividerLight),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error)),
                onTap: () async {
                  await auth.logout();
                  if (context.mounted) {
                    context.read<CartProvider>().onUserLogout();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 4. BOTTOM NAVIGATION BAR (MATCHING IMAGE 2 & 5)
  // =========================================================================
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECEFF3), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.format_list_bulleted_rounded,
            activeIcon: Icons.format_list_bulleted_rounded,
            label: 'My Orders',
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = _currentTabIndex == index;
    final color = isSelected ? AppColors.darkCharcoal : const Color(0xFF8C95A6);

    return InkWell(
      onTap: () {
        if (_currentTabIndex == index && index == 0 && _selectedCategory != null) {
          setState(() {
            _selectedCategory = null;
            _searchController.clear();
            context.read<ProductProvider>().setSelectedCategoryId('ALL');
            context.read<ProductProvider>().setSearchQuery('');
          });
          return;
        }
        setState(() => _currentTabIndex = index);
        if (index == 1) {
          final auth = context.read<UserAuthProvider>();
          if (auth.currentCustomer != null) {
            final cust = auth.currentCustomer!;
            context.read<OrderProvider>().fetchCustomerOrders(cust.id, userPhone: cust.phone);
          }
        }
      },
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            // Active Gold Dot Indicator (Matching Image 2 & 5)
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.warmGold,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
