import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/admin_model.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../providers/admin_login_provider.dart';
import '../../providers/admin_management_provider.dart';
import '../../theme/app_theme.dart';
import 'admin_form_screen.dart';

/// Professional Admin Management screen for managing administrator accounts, roles, and access.
class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminManagementProvider>().fetchAdmins();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteAdmin(AdminModel admin) {
    final currentAdmin = context.read<AdminLoginProvider>().currentAdmin;

    if (admin.id == currentAdmin?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the currently logged-in administrator account.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

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
          'Are you sure you want to permanently delete administrator "${admin.name}" (${admin.phoneNumber})?\n\nThis action cannot be undone. To temporarily revoke access, consider Deactivating the account instead.',
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
              final provider = context.read<AdminManagementProvider>();
              final success = await provider.deleteAdmin(admin.id, currentAdmin?.id ?? '');

              if (mounted) {
                if (success) {
                  context.read<AdminDashboardProvider>().fetchDashboardCounts();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Administrator "${admin.name}" deleted.'),
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
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdminForm([AdminModel? admin]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminFormScreen(adminToEdit: admin),
      ),
    );
    if (!mounted) return;
    context.read<AdminDashboardProvider>().fetchDashboardCounts();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminManagementProvider>();
    final currentAdmin = context.watch<AdminLoginProvider>().currentAdmin;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: const Text(
          'Admin Management',
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
        label: const Text('Add Admin', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _openAdminForm(),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => provider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search admin by name or phone...',
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
                const SizedBox(height: 10),

                // Role Filter Chips
                Row(
                  children: [
                    const Text(
                      'Role:',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip('ALL', 'All', provider),
                    const SizedBox(width: 6),
                    _buildFilterChip('MANAGER', 'Managers', provider),
                    const SizedBox(width: 6),
                    _buildFilterChip('STAFF', 'Staff', provider),
                  ],
                ),
              ],
            ),
          ),

          // Admins List / State Handlers
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryGold,
              backgroundColor: AppColors.darkCharcoal,
              onRefresh: () => provider.fetchAdmins(),
              child: _buildListContent(provider, currentAdmin?.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String roleKey, String label, AdminManagementProvider provider) {
    final isSelected = provider.roleFilter == roleKey;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? AppColors.darkCharcoal : AppColors.secondaryText,
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGold,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: isSelected ? AppColors.primaryGold : Colors.grey.shade300,
      ),
      onSelected: (_) => provider.setRoleFilter(roleKey),
    );
  }

  Widget _buildListContent(AdminManagementProvider provider, String? currentAdminId) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    if (provider.errorMessage != null && provider.admins.isEmpty) {
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
                onPressed: () => provider.fetchAdmins(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final list = provider.filteredAdmins;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                provider.searchQuery.isNotEmpty
                    ? 'No administrators match "${provider.searchQuery}"'
                    : 'No administrator accounts registered.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.darkCharcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap "+ Add Admin" below to create an administrator.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final admin = list[index];
        final isSelf = admin.id == currentAdminId;

        return Card(
          elevation: 1.5,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isSelf
                  ? AppColors.primaryGold.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
              width: isSelf ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: admin.isManager ? AppColors.darkCharcoal : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: admin.isManager ? AppColors.primaryGold : Colors.grey.shade300,
                    ),
                  ),
                  child: Icon(
                    admin.isManager ? Icons.shield_rounded : Icons.person_rounded,
                    color: admin.isManager ? AppColors.primaryGold : Colors.grey.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              admin.name,
                              style: const TextStyle(
                                color: AppColors.darkCharcoal,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  color: AppColors.primaryGold,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_android, size: 13, color: AppColors.secondaryText),
                          const SizedBox(width: 4),
                          Text(
                            admin.phoneNumber,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Badges
                      Row(
                        children: [
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: admin.isManager
                                  ? AppColors.darkCharcoal
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              admin.type,
                              style: TextStyle(
                                color: admin.isManager ? AppColors.primaryGold : Colors.grey.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Active Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: admin.isActive
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  admin.isActive ? Icons.check_circle : Icons.cancel,
                                  size: 11,
                                  color: admin.isActive ? AppColors.success : AppColors.error,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  admin.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: admin.isActive ? AppColors.success : AppColors.error,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.secondaryText),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) async {
                    if (action == 'edit') {
                      _openAdminForm(admin);
                    } else if (action == 'toggle_active') {
                      if (isSelf && admin.isActive) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot deactivate your own active session.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      await provider.toggleAdminActive(admin.id, !admin.isActive);
                    } else if (action == 'delete') {
                      _confirmDeleteAdmin(admin);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_active',
                      child: Row(
                        children: [
                          Icon(
                            admin.isActive ? Icons.block_flipped : Icons.check_circle_outline,
                            size: 18,
                            color: admin.isActive ? Colors.orange : AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          Text(admin.isActive ? 'Deactivate Access' : 'Activate Access'),
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
                          Text('Delete Admin', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
