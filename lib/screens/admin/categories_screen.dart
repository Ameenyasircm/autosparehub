import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/company_model.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/company_provider.dart';
import '../../theme/app_theme.dart';
import 'category_form_screen.dart';

/// Screen listing spare parts categories with company filtering, search, thumbnail preview, status toggle, and edit/delete actions.
class CategoriesScreen extends StatefulWidget {
  final bool embedded;
  final CompanyModel? company;

  const CategoriesScreen({
    super.key,
    this.embedded = false,
    this.company,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _searchController = TextEditingController();
  String _selectedCompanyId = 'ALL';

  CompanyProvider? _maybeWatchCompanyProvider(BuildContext context) {
    try {
      return context.watch<CompanyProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  CompanyProvider? _maybeReadCompanyProvider(BuildContext context) {
    try {
      return context.read<CompanyProvider>();
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
    if (widget.company != null) {
      _selectedCompanyId = widget.company!.id;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CategoryProvider>().fetchCategories();
      final compProvider = _maybeReadCompanyProvider(context);
      if (compProvider != null && compProvider.companies.isEmpty) {
        compProvider.fetchCompanies();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Delete Category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete category "${category.name}"?\n\nIf spare parts are assigned to this category, deactivating it is recommended to avoid breaking product relations.',
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
              final provider = context.read<CategoryProvider>();
              final success = await provider.deleteCategory(category.id);

              if (mounted) {
                if (success) {
                  _refreshDashboardCountsSafely();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Category "${category.name}" deleted.'),
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

  Future<void> _openCategoryForm([CategoryModel? category]) async {
    final compProvider = _maybeReadCompanyProvider(context);
    String? initialCompId = widget.company?.id;
    String? initialCompName = widget.company?.name;

    if (category == null &&
        initialCompId == null &&
        _selectedCompanyId != 'ALL' &&
        _selectedCompanyId != CategoryProvider.unassignedCompanyFilter) {
      initialCompId = _selectedCompanyId;
      final match = compProvider?.companies.where((c) => c.id == _selectedCompanyId);
      if (match != null && match.isNotEmpty) {
        initialCompName = match.first.name;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(
          categoryToEdit: category,
          initialCompanyId: initialCompId,
          initialCompanyName: initialCompName,
        ),
      ),
    );
    if (!mounted) return;
    _refreshDashboardCountsSafely();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final companyProvider = _maybeWatchCompanyProvider(context);
    final unassignedCount = provider.unassignedCategories.length;
    final activeFilterCompanyId = widget.company?.id ?? _selectedCompanyId;
    final showCompanyChips = widget.company == null &&
        ((companyProvider != null && companyProvider.companies.isNotEmpty) ||
            unassignedCount > 0);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: Text(
          widget.company != null
              ? '${widget.company!.name} Categories'
              : 'Spare Parts Categories',
          style: const TextStyle(
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
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _openCategoryForm(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Search Bar & Company Filter Strip
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => provider.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: widget.company != null
                          ? 'Search categories in ${widget.company!.name}...'
                          : 'Search categories or companies...',
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
                  if (showCompanyChips) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildCompanyFilterChip(
                            label: 'All Companies',
                            isSelected: _selectedCompanyId == 'ALL',
                            onTap: () => setState(() => _selectedCompanyId = 'ALL'),
                          ),
                          if (unassignedCount > 0)
                            _buildCompanyFilterChip(
                              label: 'Unassigned ($unassignedCount)',
                              isSelected: _selectedCompanyId ==
                                  CategoryProvider.unassignedCompanyFilter,
                              onTap: () => setState(() => _selectedCompanyId =
                                  CategoryProvider.unassignedCompanyFilter),
                            ),
                          if (companyProvider != null)
                            ...companyProvider.companies.map((comp) {
                              return _buildCompanyFilterChip(
                                label: comp.name,
                                isSelected: _selectedCompanyId == comp.id,
                                onTap: () => setState(() => _selectedCompanyId = comp.id),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                  if (widget.company == null &&
                      unassignedCount > 0 &&
                      _selectedCompanyId == 'ALL') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$unassignedCount existing ${unassignedCount == 1 ? 'category needs' : 'categories need'} a company. Tap any category to map it.',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content List
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryGold,
                backgroundColor: AppColors.darkCharcoal,
                onRefresh: () async {
                  final futures = <Future<void>>[provider.fetchCategories()];
                  if (companyProvider != null) {
                    futures.add(companyProvider.fetchCompanies());
                  }
                  await Future.wait(futures);
                },
                child: _buildListContent(
                  provider,
                  companyProvider,
                  activeFilterCompanyId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkCharcoal : const Color(0xFFF3F5F8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.primaryGold : const Color(0xFFDDE1E6),
              width: 1.1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primaryGold : AppColors.darkCharcoal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(
    CategoryProvider provider,
    CompanyProvider? companyProvider,
    String activeFilterCompanyId,
  ) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    if (provider.errorMessage != null && provider.categories.isEmpty) {
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
                onPressed: () => provider.fetchCategories(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final list = provider.filteredCategories.where((c) {
      if (activeFilterCompanyId == 'ALL') return true;
      if (activeFilterCompanyId == CategoryProvider.unassignedCompanyFilter) {
        return c.companyId.isEmpty;
      }
      return c.companyId == activeFilterCompanyId;
    }).toList();

    if (list.isEmpty) {
      final isUnassignedView =
          activeFilterCompanyId == CategoryProvider.unassignedCompanyFilter;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUnassignedView ? Icons.check_circle_outline : Icons.category_outlined,
                size: 56,
                color: isUnassignedView ? AppColors.success : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                provider.searchQuery.isNotEmpty
                    ? 'No categories match "${provider.searchQuery}"'
                    : (isUnassignedView
                        ? 'All categories are mapped to a company!'
                        : (widget.company != null
                            ? 'No categories added under ${widget.company!.name} yet.'
                            : 'No spare parts categories created.')),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.darkCharcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isUnassignedView
                    ? 'Every category in your catalog belongs to a company.'
                    : 'Organize catalog parts into Engine, Brakes, Transmission under each company.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              if (isUnassignedView) ...[
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: AppColors.primaryGold,
                  ),
                  onPressed: () => setState(() => _selectedCompanyId = 'ALL'),
                  child: const Text('Show All Categories'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final isTablet = MediaQuery.of(context).size.width >= 720;

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: 16,
      ),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final category = list[index];
        return _buildCategoryCard(category, provider, companyProvider);
      },
    );
  }

  String _resolveCompanyName(CategoryModel category, CompanyProvider? companyProvider) {
    if (companyProvider != null && category.companyId.isNotEmpty) {
      final match = companyProvider.companies.where((c) => c.id == category.companyId);
      if (match.isNotEmpty) return match.first.name;
    }
    return category.companyName;
  }

  Widget _buildCategoryCard(
    CategoryModel category,
    CategoryProvider provider,
    CompanyProvider? companyProvider,
  ) {
    final resolvedCompanyName = _resolveCompanyName(category, companyProvider);
    final isAssigned = category.hasCompany;
    final companyLabel = isAssigned
        ? (resolvedCompanyName.isNotEmpty ? resolvedCompanyName : 'Assigned Company')
        : 'Unassigned — Tap to set company';

    return Card(
          elevation: 1.5,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isAssigned ? Colors.grey.shade200 : Colors.amber.shade300,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openCategoryForm(category),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image Thumbnail
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: category.imageUrl.isNotEmpty
                        ? Image.network(
                            category.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            },
                            errorBuilder: (ctx, err, stack) => const Icon(
                              Icons.category,
                              color: AppColors.primaryGold,
                              size: 30,
                            ),
                          )
                        : const Icon(Icons.category, color: AppColors.primaryGold, size: 30),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              category.name,
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
                              color: category.isActive
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: category.isActive ? AppColors.success : AppColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                        if (widget.company == null) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAssigned
                                  ? AppColors.badgeGoldBg
                                  : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isAssigned
                                    ? AppColors.badgeGoldBorder.withValues(alpha: 0.6)
                                    : Colors.amber.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAssigned
                                      ? Icons.business_outlined
                                      : Icons.warning_amber_rounded,
                                  size: 12,
                                  color: isAssigned
                                      ? AppColors.badgeGoldText
                                      : Colors.amber.shade800,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    companyLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isAssigned
                                          ? AppColors.badgeGoldText
                                          : Colors.amber.shade900,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      if (category.description != null && category.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          category.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                            height: 1.3,
                          ),
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
                    if (action == 'edit') {
                      _openCategoryForm(category);
                    } else if (action == 'toggle_active') {
                      await provider.toggleCategoryActive(category.id, !category.isActive);
                    } else if (action == 'delete') {
                      _confirmDeleteCategory(category);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit Category'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_active',
                      child: Row(
                        children: [
                          Icon(
                            category.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(category.isActive ? 'Deactivate' : 'Activate'),
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
