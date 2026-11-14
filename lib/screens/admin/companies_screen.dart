import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/company_model.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/company_provider.dart';
import '../../theme/app_theme.dart';
import 'categories_screen.dart';
import 'company_form_screen.dart';

/// Screen listing vehicle manufacturers / companies with search, status toggling, category navigation, and management options.
class CompaniesScreen extends StatefulWidget {
  final bool embedded;
  const CompaniesScreen({super.key, this.embedded = false});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final _searchController = TextEditingController();

  CategoryProvider? _maybeWatchCategoryProvider(BuildContext context) {
    try {
      return context.watch<CategoryProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  CategoryProvider? _maybeReadCategoryProvider(BuildContext context) {
    try {
      return context.read<CategoryProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _refreshDashboardCountsSafely() {
    try {
      context.read<AdminDashboardProvider>().fetchDashboardCounts();
    } on ProviderNotFoundException {
      // Standalone widget/screen usage without dashboard shell.
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CompanyProvider>().fetchCompanies();
      final catProvider = _maybeReadCategoryProvider(context);
      if (catProvider != null && catProvider.categories.isEmpty) {
        catProvider.fetchCategories();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteCompany(CompanyModel company) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Delete Brand', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${company.name}"?\n\nIf categories or spare parts are linked to this manufacturer, deactivating the brand is recommended instead of deletion.',
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final provider = context.read<CompanyProvider>();
              final success = await provider.deleteCompany(company.id);

              if (mounted) {
                if (success) {
                  _refreshDashboardCountsSafely();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Brand "${company.name}" deleted.'),
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

  Future<void> _openCompanyForm([CompanyModel? company]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyFormScreen(companyToEdit: company),
      ),
    );
    if (!mounted) return;
    _refreshDashboardCountsSafely();
  }

  Future<void> _openCompanyCategories(CompanyModel company) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(company: company),
      ),
    );
    if (!mounted) return;
    _refreshDashboardCountsSafely();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyProvider>();
    final categoryProvider = _maybeWatchCategoryProvider(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: const Text(
          'Brands',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGold,
        foregroundColor: AppColors.darkCharcoal,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Brand', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _openCompanyForm(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => provider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search brands by name...',
                prefixIcon: const Icon(Icons.search, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Content List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryGold,
              backgroundColor: AppColors.darkCharcoal,
              onRefresh: () async {
                final futures = <Future<void>>[provider.fetchCompanies()];
                if (categoryProvider != null) {
                  futures.add(categoryProvider.fetchCategories());
                }
                await Future.wait(futures);
              },
              child: _buildListContent(provider, categoryProvider),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildListContent(CompanyProvider provider, CategoryProvider? categoryProvider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    if (provider.errorMessage != null && provider.companies.isEmpty) {
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
                style: const TextStyle(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => provider.fetchCompanies(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final list = provider.filteredCompanies;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                provider.searchQuery.isNotEmpty
                    ? 'No brands match "${provider.searchQuery}"'
                    : 'No brands registered.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.darkCharcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add vehicle manufacturers like Toyota, Honda, Hyundai...',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final isTablet = MediaQuery.of(context).size.width >= 720;
    if (isTablet) {
      final crossAxisCount = MediaQuery.of(context).size.width >= 1100 ? 3 : 2;
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: list.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisExtent: 108,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final company = list[index];
          return _buildCompanyCard(company, provider, categoryProvider);
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final company = list[index];
        return _buildCompanyCard(company, provider, categoryProvider);
      },
    );
  }

  Widget _buildCompanyCard(
    CompanyModel company,
    CompanyProvider provider,
    CategoryProvider? categoryProvider,
  ) {
    final categoryCount = categoryProvider?.categoriesForCompany(company.id).length;

    return Card(
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openCompanyCategories(company),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo Thumbnail
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: company.logoUrl.isNotEmpty
                      ? Image.network(
                          company.logoUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          },
                          errorBuilder: (ctx, err, stack) => const Icon(
                            Icons.business,
                            color: AppColors.primaryGold,
                            size: 28,
                          ),
                        )
                      : const Icon(Icons.business, color: AppColors.primaryGold, size: 28),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            company.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.darkCharcoal,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: company.isActive
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            company.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: company.isActive ? AppColors.success : AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (company.description != null && company.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        company.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (categoryCount != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            size: 12.5,
                            color: AppColors.badgeGoldText,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$categoryCount ${categoryCount == 1 ? 'Category' : 'Categories'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.badgeGoldText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: AppColors.badgeGoldText,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.secondaryText),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (action) async {
                  if (action == 'categories') {
                    _openCompanyCategories(company);
                  } else if (action == 'edit') {
                    _openCompanyForm(company);
                  } else if (action == 'toggle_active') {
                    await provider.toggleCompanyActive(company.id, !company.isActive);
                  } else if (action == 'delete') {
                    _confirmDeleteCompany(company);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'categories',
                    child: Row(
                      children: [
                        Icon(Icons.category_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Manage Categories'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit Brand'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_active',
                    child: Row(
                      children: [
                        Icon(
                          company.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(company.isActive ? 'Deactivate' : 'Activate'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
