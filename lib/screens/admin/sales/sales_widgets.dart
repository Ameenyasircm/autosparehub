import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/customer_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/customer_management_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/phone_helper.dart';
import 'customer_form_screen.dart';

/// Shared pieces for the sales & purchase screens.

class SalesErrorBanner extends StatelessWidget {
  final String message;
  const SalesErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// A tappable box showing a value, used for date/customer/product selectors.
class SelectorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const SelectorTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.warmGold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? value! : placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                        color: hasValue ? AppColors.primaryText : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasValue && onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.secondaryText),
                  onPressed: onClear,
                )
              else
                const Icon(Icons.arrow_drop_down_rounded, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> _showSearchSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext sheetContext, String query) listBuilder,
  Widget? headerAction,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheetContext) {
      String query = '';
      return StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkHeader)),
                      ),
                      if (headerAction != null) headerAction,
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) => setSheetState(() => query = v.trim().toLowerCase()),
                  ),
                ),
                Expanded(child: listBuilder(ctx, query)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Lets the admin pick a product. In sale mode, out-of-stock products are
/// marked, and picking one lets the admin add a purchase first.
Future<ProductModel?> showProductPicker(BuildContext context, {required bool forSale}) {
  final productProvider = context.read<ProductProvider>();
  if (productProvider.products.isEmpty && !productProvider.isLoading) {
    productProvider.fetchProducts();
  }

  return _showSearchSheet<ProductModel>(
    context: context,
    title: 'Select Product',
    listBuilder: (ctx, query) {
      final provider = ctx.watch<ProductProvider>();
      if (provider.isLoading && provider.products.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: AppColors.warmGold));
      }
      final list = provider.products.where((p) {
        if (query.isEmpty) return true;
        return p.name.toLowerCase().contains(query) ||
            p.application.toLowerCase().contains(query) ||
            p.companyName.toLowerCase().contains(query);
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (list.isEmpty) {
        return const Center(
            child: Text('No products found', style: TextStyle(color: AppColors.secondaryText)));
      }

      return ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = list[i];
          final stock = p.stockQuantity ?? 0;
          final blocked = forSale && stock <= 0;
          return ListTile(
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(
              [
                if (p.productCode != null) 'Code: ${p.productCode}',
                p.companyName,
                if (!p.isActive) 'Inactive',
              ].join(' • '),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  blocked ? 'Out of stock - tap to add purchase' : 'Stock: $stock',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: stock <= 0 ? AppColors.error : AppColors.success,
                  ),
                ),
                if (p.price != null)
                  Text('₹${p.price!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
              ],
            ),
            onTap: () => Navigator.of(ctx).pop(p),
          );
        },
      );
    },
  );
}

/// Lets the admin pick an approved customer, or create a new one.
Future<CustomerModel?> showCustomerPicker(BuildContext context) {
  final customerProvider = context.read<CustomerManagementProvider>();
  if (customerProvider.customers.isEmpty && !customerProvider.isLoading) {
    customerProvider.fetchCustomers();
  }

  return _showSearchSheet<CustomerModel>(
    context: context,
    title: 'Select Customer',
    headerAction: Builder(
      builder: (ctx) => TextButton.icon(
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.warmGold),
        label: const Text('New',
            style: TextStyle(color: AppColors.darkHeader, fontWeight: FontWeight.w700)),
        onPressed: () async {
          final created = await Navigator.of(ctx).push<CustomerModel>(
            MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
          );
          if (created != null && ctx.mounted) Navigator.of(ctx).pop(created);
        },
      ),
    ),
    listBuilder: (ctx, query) {
      final provider = ctx.watch<CustomerManagementProvider>();
      if (provider.isLoading && provider.customers.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: AppColors.warmGold));
      }
      final list = provider.customers.where((c) {
        if (!c.isApproved) return false;
        if (query.isEmpty) return true;
        return c.name.toLowerCase().contains(query) || c.phoneNumber.contains(query);
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (list.isEmpty) {
        return const Center(
          child: Text('No approved customers found.\nTap "New" to add one.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText)),
        );
      }

      return ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final c = list[i];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.badgeGoldBg,
              child: Icon(Icons.person_rounded, color: AppColors.warmGold),
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(PhoneHelper.formatForDisplay(c.phoneNumber)),
            onTap: () => Navigator.of(ctx).pop(c),
          );
        },
      );
    },
  );
}
