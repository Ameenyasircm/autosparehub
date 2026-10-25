import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'widgets/change_password_dialog.dart';

/// Customer Storefront Home Screen matching Image 5 with pixel-level precision:
/// - Dark AppBar (#12151B) with circular logo, "AUTO SPARE HUB" rich title, and rounded square cart button with badge dot
/// - White pill search bar ("Search Spare") with unbroken outline
/// - Category pill filter bar (Engine Parts, Brake System, Filters, Electrical, etc.)
/// - 2-Column Product Grid with category tag pills, centered image, part number, bold price, and "+ Add to Cart" outlined button
/// - 3-Tab Bottom Navigation Bar (Home, My Orders, Profile) with warm gold dot active indicator
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentTabIndex = 0;
  final _searchController = TextEditingController();
  bool _isInitialLoading = true;

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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<UserAuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildTopAppBar(context, cart, auth),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildStorefrontCatalogTab(context),
          const UserOrdersScreen(showAppBar: false),
          _buildProfileTab(context, auth),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
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
          // Brand Title: "AUTO SPARE HUB"
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'AUTO SPARE ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    letterSpacing: 0.6,
                  ),
                ),
                TextSpan(
                  text: 'HUB',
                  style: TextStyle(
                    color: AppColors.warmGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
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
  // 2. STOREFRONT CATALOG TAB (MATCHING IMAGE 5)
  // =========================================================================
  Widget _buildStorefrontCatalogTab(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    final bool showCompanyFilter = companyProvider.companies.length >= 2;
    final products = productProvider.filteredProducts.where((p) => p.isActive).toList();

    return Column(
      children: [
        // --- SEARCH BAR (MATCHING IMAGE 5) ---
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
                  onChanged: (val) => productProvider.setSearchQuery(val),
                  decoration: const InputDecoration(
                    hintText: 'Search Spare',
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

        // --- CATEGORY PILLS STRIP (MATCHING IMAGE 5) ---
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryPill(
                label: 'All Categories',
                isSelected: productProvider.selectedCategoryId == 'ALL',
                onTap: () => productProvider.setSelectedCategoryId('ALL'),
              ),
              ...categoryProvider.categories.map((cat) {
                return _buildCategoryPill(
                  label: cat.name,
                  isSelected: productProvider.selectedCategoryId == cat.id,
                  onTap: () => productProvider.setSelectedCategoryId(cat.id),
                );
              }),
            ],
          ),
        ),

        // --- CONDITIONAL COMPANY FILTER STRIP (IF >= 2 COMPANIES) ---
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
                ...companyProvider.companies.map((comp) {
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

        // --- FILTER STATUS ROW ---
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${products.length} Parts Available',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText,
                ),
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

        // --- 2-COLUMN STOREFRONT PRODUCT GRID (MATCHING IMAGE 5) ---
        Expanded(
          child: RefreshIndicator(
            color: AppColors.warmGold,
            backgroundColor: AppColors.darkHeader,
            onRefresh: () => productProvider.fetchProducts(),
            child: (_isInitialLoading || productProvider.isLoading)
                ? _buildLoadingState()
                : products.isEmpty
                    ? _buildEmptyState(productProvider)
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
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return _buildProductCard(context, products[index]);
                    },
                  ),
          ),
        ),
      ],
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
                    color: Color(0xFF111317),
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
                    color: Color(0xFF111317),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF181A20),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add, size: 15, color: Color(0xFF111317)),
                        SizedBox(width: 4),
                        Text(
                          'Add to Cart',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111317),
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

  // --- EMPTY CATALOG STATE ---
  Widget _buildEmptyState(ProductProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 52, color: Colors.grey),
            const SizedBox(height: 14),
            const Text(
              'No Matching Spare Parts',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try searching with another keyword or reset your filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkHeader,
                side: const BorderSide(color: AppColors.darkHeader),
              ),
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
                    foregroundColor: AppColors.darkHeader,
                    side: const BorderSide(color: Color(0xFF181A20), width: 1.2),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Awaiting Administrator Approval',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Your garage account registration has been submitted and is currently being reviewed. Once authorized, you can place orders directly.',
                            style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'നിങ്ങളുടെ രജിസ്ട്രേഷൻ അഡ്മിൻ പരിശോധിച്ചുകൊണ്ടിരിക്കുകയാണ്. പരിശോധന പൂർത്തിയാക്കിയ ശേഷം അഡ്മിൻ നിങ്ങളെ ഉടൻ ബന്ധപ്പെടുന്നതാണ്. ദയവായി കാത്തിരിക്കുക!',
                            style: TextStyle(fontSize: 11.5, color: AppColors.darkCharcoal, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkButton,
                        side: const BorderSide(color: AppColors.darkButton),
                      ),
                      onPressed: () async {
                        await auth.refreshApprovalStatus();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                auth.isApproved
                                    ? 'Account approved! You can now place orders.'
                                    : 'Still pending administrator review.',
                              ),
                              backgroundColor: auth.isApproved ? AppColors.success : AppColors.darkButton,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Check Approval Status'),
                    ),
                  ],
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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded, color: AppColors.warmGold),
                title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () => ChangeUserPasswordDialog.show(context),
              ),
              const Divider(height: 1),
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
    final color = isSelected ? const Color(0xFF111317) : const Color(0xFF8C95A6);

    return InkWell(
      onTap: () {
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
