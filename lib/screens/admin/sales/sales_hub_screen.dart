import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'customer_form_screen.dart';
import 'day_wise_sales_screen.dart';
import 'stock_entry_form_screen.dart';

/// Entry point for the simple sales system, opened from the admin menu.
class SalesHubScreen extends StatelessWidget {
  const SalesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Sales & Purchases',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HubTile(
            title: 'New Sale',
            subtitle: 'Sell to a customer. Stock goes down.',
            icon: Icons.point_of_sale_rounded,
            color: const Color(0xFF16A34A),
            onTap: () => open(const StockEntryFormScreen(type: StockEntryType.sale)),
          ),
          _HubTile(
            title: 'New Purchase',
            subtitle: 'Add stock bought from a supplier. Stock goes up.',
            icon: Icons.add_shopping_cart_rounded,
            color: const Color(0xFF2563EB),
            onTap: () => open(const StockEntryFormScreen(type: StockEntryType.purchase)),
          ),
          _HubTile(
            title: 'Add Customer',
            subtitle: 'Create an approved customer account.',
            icon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFF7C3AED),
            onTap: () => open(const CustomerFormScreen()),
          ),
          _HubTile(
            title: 'Day-wise Sales',
            subtitle: 'Sales by day, with date, product and customer filters.',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFFD97706),
            onTap: () => open(const DayWiseSalesScreen()),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HubTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.darkHeader)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
        onTap: onTap,
      ),
    );
  }
}
