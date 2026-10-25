import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/customer_model.dart';
import '../../models/order_model.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../providers/admin_login_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/customer_management_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/admin_authorization_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone_helper.dart';
import '../admin_login_screen.dart';
import 'admin_management_screen.dart';
import 'categories_screen.dart';
import 'companies_screen.dart';
import 'product_form_screen.dart';
import 'products_screen.dart';

/// Comprehensive Automotive Admin Dashboard with Live Orders Management,
/// Date/Status Filtering, Customer Approval Center, and Catalog Metrics.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _customerSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerManagementProvider>().listenToCustomers();
      _refreshAllData();
    });
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      context.read<AdminDashboardProvider>().fetchDashboardCounts(),
      context.read<CustomerManagementProvider>().fetchCustomers(),
      context.read<OrderProvider>().fetchAdminOrders(),
      context.read<CategoryProvider>().fetchCategories(),
    ]);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.darkCharcoal,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your administrative session?',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await context.read<AdminLoginProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 400),
                  pageBuilder: (context, anim, secAnim) => const AdminLoginScreen(),
                  transitionsBuilder: (context, anim, secAnim, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
                (route) => false,
              );
            },
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateTo(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    _refreshAllData();
  }

  // --- CUSTOMER APPROVAL REVIEW MODAL ---
  void _showCustomerApprovalsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer<CustomerManagementProvider>(
          builder: (context, customerProvider, child) {
            final pending = customerProvider.pendingCustomers;
            final currentAdmin = context.read<AdminLoginProvider>().currentAdmin;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_add_rounded, color: Colors.amber, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Pending Approvals (${pending.length})',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: pending.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 48, color: Colors.green.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'All customer requests have been processed!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkCharcoal,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: pending.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final customer = pending[index];
                              return _buildCustomerApprovalCard(customer, currentAdmin?.id);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRejectCustomerDialog(BuildContext context, CustomerModel customer) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.person_off_outlined, color: AppColors.error),
            SizedBox(width: 8),
            Text('Reject Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${customer.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text('Mobile: ${PhoneHelper.formatForDisplay(customer.phone)}', style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText)),
            const SizedBox(height: 12),
            const Text(
              'Reason for rejection (shown to customer):',
              style: TextStyle(fontSize: 12, color: AppColors.darkCharcoal, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Phone verification failed / Non-commercial enquiry',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final provider = context.read<CustomerManagementProvider>();
              final reason = reasonController.text.trim().isNotEmpty
                  ? reasonController.text.trim()
                  : 'Account request could not be verified.';
              final ok = await provider.rejectCustomer(customer.id, reason: reason);
              if (context.mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Rejected request for ${customer.name}')),
                );
              }
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  void _showChangeCustomerPasswordDialog(BuildContext context, CustomerModel customer) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.lock_reset_rounded, color: AppColors.primaryGold, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Change Customer Password', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${customer.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text('Mobile: +91 ${customer.phone}', style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText)),
                const SizedBox(height: 14),
                const Text(
                  'New Password *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    hintText: 'Minimum 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter new password';
                    if (val.trim().length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Confirm Password *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Re-enter new password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                  validator: (val) {
                    if (val != newPasswordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                foregroundColor: AppColors.primaryGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogCtx);
                final provider = context.read<CustomerManagementProvider>();
                final messenger = ScaffoldMessenger.of(context);
                final ok = await provider.updateCustomerPassword(
                  customer.id,
                  newPasswordController.text.trim(),
                );
                if (ok) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Password updated successfully for ${customer.name}!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage ?? 'Failed to update password.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerApprovalCard(CustomerModel customer, String? adminId) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                radius: 20,
                backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppColors.darkCharcoal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: AppColors.secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          PhoneHelper.formatForDisplay(customer.phone),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primaryGold),
                          tooltip: 'Copy Phone',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: customer.phone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied ${customer.phone} to clipboard'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkCharcoal,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showChangeCustomerPasswordDialog(context, customer),
                icon: const Icon(Icons.lock_reset_rounded, size: 15, color: AppColors.primaryGold),
                label: const Text('Change Password', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showRejectCustomerDialog(context, customer),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final provider = context.read<CustomerManagementProvider>();
                  final ok = await provider.approveCustomer(customer.id, adminId: adminId);
                  if (mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Approved ${customer.name}! They can now place orders.')),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approve Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- DETAILED ORDER BREAKDOWN SHEET ---
  void _showOrderDetailsSheet(BuildContext context, OrderModel order) {
    Color badgeColor;
    Color badgeBg;
    IconData statusIcon;

    switch (order.status) {
      case 'CONFIRMED':
        badgeColor = Colors.blue.shade700;
        badgeBg = Colors.blue.shade50;
        statusIcon = Icons.thumb_up_alt_rounded;
        break;
      case 'DISPATCHED':
        badgeColor = Colors.deepPurple;
        badgeBg = Colors.deepPurple.shade50;
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'DELIVERED':
        badgeColor = Colors.green.shade700;
        badgeBg = Colors.green.shade50;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'CANCELLED':
        badgeColor = Colors.red.shade700;
        badgeBg = Colors.red.shade50;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'PENDING':
      default:
        badgeColor = Colors.amber.shade800;
        badgeBg = Colors.amber.shade50;
        statusIcon = Icons.hourglass_top_rounded;
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      if (order.createdAt != null)
                        Text(
                          '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year} at ${order.createdAt!.hour.toString().padLeft(2, '0')}:${order.createdAt!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: badgeColor),
                        const SizedBox(width: 4),
                        Text(
                          order.status,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Contact Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                            child: Text(
                              order.userName.isNotEmpty ? order.userName[0].toUpperCase() : 'C',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.userName,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  PhoneHelper.formatForDisplay(order.userPhone),
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: AppColors.primaryGold, size: 18),
                            tooltip: 'Copy Phone',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: order.userPhone));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied ${order.userPhone} to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ordered Spare Parts
                    Row(
                      children: [
                        const Icon(Icons.precision_manufacturing_outlined, color: AppColors.primaryGold, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Ordered Spare Parts (${order.items.length} items)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = order.items[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey.shade100,
                                  child: item.productImage.isNotEmpty
                                      ? Image.network(
                                          item.productImage,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.car_repair_rounded, color: AppColors.primaryGold),
                                        )
                                      : const Icon(Icons.car_repair_rounded, color: AppColors.primaryGold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.companyName} • ${item.categoryName}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                    ),
                                    if (item.refNo != null && item.refNo!.isNotEmpty)
                                      Text(
                                        'Ref: ${item.refNo}',
                                        style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Qty: ${item.quantity}   •   ₹ ${item.unitPrice.toStringAsFixed(0)} each',
                                      style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹ ${item.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Delivery Details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.location_on_outlined, color: AppColors.primaryGold, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Delivery Address & Notes',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Text(
                            order.shippingAddress != null && order.shippingAddress!.isNotEmpty
                                ? order.shippingAddress!
                                : 'No shipping address provided.',
                            style: const TextStyle(fontSize: 13, color: AppColors.darkCharcoal, height: 1.3),
                          ),
                          if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.note_alt_outlined, size: 16, color: AppColors.secondaryText),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Customer Note: "${order.customerNote!}"',
                                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.secondaryText),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (order.adminRemark != null && order.adminRemark!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.rate_review_rounded, size: 16, color: AppColors.primaryGold),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Admin Remark:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.darkCharcoal,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          order.adminRemark!,
                                          style: const TextStyle(fontSize: 12.5, color: AppColors.darkCharcoal),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Financial Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Units (${order.totalItemUnits} units)',
                                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Order Total Amount',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                              ),
                            ],
                          ),
                          Text(
                            '₹ ${order.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Change Status Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkCharcoal,
                          foregroundColor: AppColors.primaryGold,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _showOrderStatusDialog(context, order);
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text('Update Order Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ORDER STATUS & REMARK UPDATER SHEET ---
  void _showOrderStatusDialog(BuildContext context, OrderModel order) {
    final orderProvider = context.read<OrderProvider>();
    const statuses = [
      {'status': 'PENDING', 'label': 'Pending Review', 'icon': Icons.hourglass_top_rounded, 'color': Colors.amber},
      {'status': 'CONFIRMED', 'label': 'Confirmed & Processing', 'icon': Icons.thumb_up_alt_rounded, 'color': Colors.blue},
      {'status': 'DISPATCHED', 'label': 'Dispatched for Delivery', 'icon': Icons.local_shipping_rounded, 'color': Colors.deepPurple},
      {'status': 'DELIVERED', 'label': 'Delivered Successfully', 'icon': Icons.check_circle_rounded, 'color': Colors.green},
      {'status': 'CANCELLED', 'label': 'Cancelled / Rejected', 'icon': Icons.cancel_rounded, 'color': Colors.red},
    ];

    final remarkController = TextEditingController(text: order.adminRemark ?? '');
    String selectedStatus = order.status;
    bool isSaving = false;

    const quickRemarks = [
      'Verified with customer',
      'Ready for store pickup',
      'Dispatched via transport',
      'Customer unreachable on phone',
      'Cancelled on customer request',
      'Out of stock / part unavailable',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Update Status & Remark',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${order.orderNumber} • ${order.userName}',
                                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.secondaryText),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Status Header
                    const Text(
                      'SELECT STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Status options
                    ...statuses.map((s) {
                      final isSelected = selectedStatus == s['status'];
                      final color = s['color'] as Color;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setSheetState(() {
                              selectedStatus = s['status'] as String;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : Colors.grey.shade200,
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(s['icon'] as IconData, color: color, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s['label'] as String,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? AppColors.darkCharcoal : Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: color, size: 20)
                                else
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Remark Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ADMIN REMARK / NOTE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        if (remarkController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                remarkController.clear();
                              });
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Remark Suggestion Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: quickRemarks.map((q) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 8),
                            child: ActionChip(
                              label: Text(
                                q,
                                style: const TextStyle(fontSize: 11, color: AppColors.darkCharcoal),
                              ),
                              backgroundColor: Colors.grey.shade100,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () {
                                setSheetState(() {
                                  remarkController.text = q;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Text Field for Remark
                    TextField(
                      controller: remarkController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13, color: AppColors.darkCharcoal),
                      decoration: InputDecoration(
                        hintText: 'e.g. Called customer, confirmed for pickup at 4 PM...',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.all(12),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.darkCharcoal,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSaving ? null : () => Navigator.pop(sheetCtx),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.darkCharcoal,
                              foregroundColor: AppColors.primaryGold,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setSheetState(() => isSaving = true);
                                    final finalRemark = remarkController.text.trim();
                                    final ok = await orderProvider.updateOrderStatus(
                                      order.id,
                                      selectedStatus,
                                      adminRemark: finalRemark,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(sheetCtx);
                                      if (ok) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Order ${order.orderNumber} updated to $selectedStatus'),
                                            backgroundColor: AppColors.darkCharcoal,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to update order status.'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGold),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              isSaving ? 'Updating...' : 'Save Status & Remark',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
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
      },
    );
  }

  // --- CUSTOM DATE RANGE PICKER ---
  Future<void> _pickCustomDateRange(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();
    final initialRange = orderProvider.customDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.darkCharcoal,
              onPrimary: AppColors.primaryGold,
              surface: Colors.white,
              onSurface: AppColors.darkCharcoal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      orderProvider.setDateFilter(OrderDateFilter.custom, customRange: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = context.watch<AdminLoginProvider>().currentAdmin;
    final dashboardProvider = context.watch<AdminDashboardProvider>();
    final customerProvider = context.watch<CustomerManagementProvider>();
    final orderProvider = context.watch<OrderProvider>();

    final adminName = currentAdmin?.name.isNotEmpty == true ? currentAdmin!.name : 'Admin';
    final adminType = currentAdmin?.type.isNotEmpty == true ? currentAdmin!.type : 'MANAGER';
    final isManager = AdminAuthorizationService.canManageAdmins(currentAdmin);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        color: AppColors.primaryGold,
        backgroundColor: AppColors.darkCharcoal,
        onRefresh: _refreshAllData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // --- HEADER ---
            SliverAppBar(
              expandedHeight: 140.0,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.darkCharcoal,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/AutoSpareLogo.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.directions_car,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ),
              ),
              title: const Text(
                'AutoSpare Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: 0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.lightGold),
                  tooltip: 'Refresh All',
                  onPressed: _refreshAllData,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppColors.lightGold),
                  tooltip: 'Sign Out',
                  onPressed: () => _showLogoutDialog(context),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1E2125),
                        AppColors.darkCharcoal,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 54, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Welcome back, $adminName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Automotive Spare Parts Management',
                                  style: TextStyle(
                                    color: AppColors.textMuted.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryGold, AppColors.lightGold],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              adminType,
                              style: const TextStyle(
                                color: AppColors.darkCharcoal,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- DASHBOARD BODY CONTENT ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- PENDING CUSTOMER APPROVALS BANNER ---
                    if (customerProvider.pendingCount > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_add_rounded, color: Colors.amber, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${customerProvider.pendingCount} Customer Approval Request${customerProvider.pendingCount > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: AppColors.darkCharcoal,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'New accounts waiting for permission to order',
                                    style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.darkCharcoal,
                                foregroundColor: AppColors.primaryGold,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () => _showCustomerApprovalsModal(context),
                              child: const Text('Review', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                    // --- CATALOG & SHORTCUTS HEADER ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Catalog Overview',
                          style: TextStyle(
                            color: AppColors.darkCharcoal,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGold,
                            foregroundColor: AppColors.darkCharcoal,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                          onPressed: () => _navigateTo(const ProductFormScreen()),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'Add Product',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- 2x2 METRICS GRID ---
                    Row(
                      children: [
                        _buildSummaryCard(
                          title: 'Products',
                          count: dashboardProvider.productCount,
                          subtitle: 'Spare Parts',
                          icon: Icons.precision_manufacturing_outlined,
                          accentColor: AppColors.primaryGold,
                          isLoading: dashboardProvider.isLoading,
                          onTap: () => _navigateTo(const ProductsScreen()),
                        ),
                        const SizedBox(width: 10),
                        _buildSummaryCard(
                          title: 'Companies',
                          count: dashboardProvider.companyCount,
                          subtitle: 'Vehicle Brands',
                          icon: Icons.business_outlined,
                          accentColor: AppColors.secondaryGold,
                          isLoading: dashboardProvider.isLoading,
                          onTap: () => _navigateTo(const CompaniesScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildSummaryCard(
                          title: 'Categories',
                          count: dashboardProvider.categoryCount,
                          subtitle: 'Part Catalog',
                          icon: Icons.category_outlined,
                          accentColor: AppColors.darkCharcoal,
                          isLoading: dashboardProvider.isLoading,
                          onTap: () => _navigateTo(const CategoriesScreen()),
                        ),
                        const SizedBox(width: 10),
                        _buildSummaryCard(
                          title: 'Admins',
                          count: dashboardProvider.adminCount,
                          subtitle: 'Registered Staff',
                          icon: Icons.admin_panel_settings_outlined,
                          accentColor: AppColors.primaryGold,
                          isLoading: dashboardProvider.isLoading,
                          onTap: () {
                            if (isManager) {
                              _navigateTo(const AdminManagementScreen());
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Admin Management requires MANAGER privileges.'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ==========================================
                    // --- LIVE CUSTOMER ORDERS MANAGEMENT ---
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Customer Orders',
                              style: TextStyle(
                                color: AppColors.darkCharcoal,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${orderProvider.filteredAdminOrders.length}',
                                style: const TextStyle(
                                  color: AppColors.darkCharcoal,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Total: ${orderProvider.totalOrdersCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- STATUS FILTER STRIP (PRIMARY STATUS TABS) ---
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusFilterChip(
                            status: 'ALL',
                            label: 'All Orders',
                            count: orderProvider.totalOrdersCount,
                            icon: Icons.all_inbox_rounded,
                            color: AppColors.darkCharcoal,
                            provider: orderProvider,
                          ),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip(
                            status: 'PENDING',
                            label: 'Pending',
                            count: orderProvider.pendingOrdersCount,
                            icon: Icons.hourglass_top_rounded,
                            color: Colors.amber.shade800,
                            provider: orderProvider,
                          ),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip(
                            status: 'CONFIRMED',
                            label: 'Confirmed',
                            count: orderProvider.confirmedOrdersCount,
                            icon: Icons.thumb_up_alt_rounded,
                            color: Colors.blue.shade700,
                            provider: orderProvider,
                          ),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip(
                            status: 'DISPATCHED',
                            label: 'Dispatched',
                            count: orderProvider.dispatchedOrdersCount,
                            icon: Icons.local_shipping_rounded,
                            color: Colors.deepPurple,
                            provider: orderProvider,
                          ),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip(
                            status: 'DELIVERED',
                            label: 'Delivered',
                            count: orderProvider.deliveredOrdersCount,
                            icon: Icons.check_circle_rounded,
                            color: Colors.green.shade700,
                            provider: orderProvider,
                          ),
                          const SizedBox(width: 6),
                          _buildStatusFilterChip(
                            status: 'CANCELLED',
                            label: 'Cancelled',
                            count: orderProvider.cancelledOrdersCount,
                            icon: Icons.cancel_rounded,
                            color: Colors.red.shade700,
                            provider: orderProvider,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- CUSTOMER SEARCH FILTER ---
                    Container(
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _customerSearchController,
                        onChanged: (val) => orderProvider.setCustomerFilter(val),
                        style: const TextStyle(fontSize: 13, color: AppColors.darkCharcoal),
                        decoration: InputDecoration(
                          hintText: 'Search customer name, phone, or #ORD...',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primaryGold),
                          suffixIcon: _customerSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                  onPressed: () {
                                    _customerSearchController.clear();
                                    orderProvider.setCustomerFilter('');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    // --- CATEGORY FILTER STRIP ---
                    Consumer<CategoryProvider>(
                      builder: (context, catProvider, child) {
                        final categories = catProvider.categories;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryFilterChip('ALL', 'All Categories', orderProvider),
                              ...categories.map((cat) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _buildCategoryFilterChip(cat.name, cat.name, orderProvider),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // --- DATE FILTER STRIP ---
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDateFilterChip(
                            label: 'All Time',
                            filter: OrderDateFilter.all,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => orderProvider.setDateFilter(OrderDateFilter.all),
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: 'Today',
                            filter: OrderDateFilter.today,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => orderProvider.setDateFilter(OrderDateFilter.today),
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: 'This Week',
                            filter: OrderDateFilter.thisWeek,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => orderProvider.setDateFilter(OrderDateFilter.thisWeek),
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: 'This Month',
                            filter: OrderDateFilter.thisMonth,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => orderProvider.setDateFilter(OrderDateFilter.thisMonth),
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: orderProvider.customDateRange != null
                                ? '${orderProvider.customDateRange!.start.day}/${orderProvider.customDateRange!.start.month} - ${orderProvider.customDateRange!.end.day}/${orderProvider.customDateRange!.end.month}'
                                : 'Custom Range...',
                            filter: OrderDateFilter.custom,
                            activeFilter: orderProvider.dateFilter,
                            onTap: () => _pickCustomDateRange(context),
                          ),
                        ],
                      ),
                    ),

                    if (orderProvider.customerFilter.isNotEmpty ||
                        orderProvider.categoryFilter != 'ALL' ||
                        orderProvider.statusFilter != 'ALL' ||
                        orderProvider.dateFilter != OrderDateFilter.all) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.filter_alt, size: 13, color: AppColors.primaryGold),
                              const SizedBox(width: 4),
                              Text(
                                'Filtered: ${orderProvider.filteredAdminOrders.length} of ${orderProvider.totalOrdersCount} orders',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              _customerSearchController.clear();
                              orderProvider.resetAllFilters();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Text(
                                'Reset Filters',
                                style: TextStyle(fontSize: 11.5, color: AppColors.error, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // --- ORDERS LIST ---
                    if (orderProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
                          ),
                        ),
                      )
                    else if (orderProvider.filteredAdminOrders.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No Orders Found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No customer orders match the selected date & status filter.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orderProvider.filteredAdminOrders.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = orderProvider.filteredAdminOrders[index];
                          return _buildOrderCard(order);
                        },
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ORDER CARD WIDGET ---
  Widget _buildOrderCard(OrderModel order) {
    Color badgeColor;
    Color badgeBg;
    IconData statusIcon;

    switch (order.status) {
      case 'CONFIRMED':
        badgeColor = Colors.blue.shade700;
        badgeBg = Colors.blue.shade50;
        statusIcon = Icons.thumb_up_alt_rounded;
        break;
      case 'DISPATCHED':
        badgeColor = Colors.deepPurple;
        badgeBg = Colors.deepPurple.shade50;
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'DELIVERED':
        badgeColor = Colors.green.shade700;
        badgeBg = Colors.green.shade50;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'CANCELLED':
        badgeColor = Colors.red.shade700;
        badgeBg = Colors.red.shade50;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'PENDING':
      default:
        badgeColor = Colors.amber.shade800;
        badgeBg = Colors.amber.shade50;
        statusIcon = Icons.hourglass_top_rounded;
        break;
    }

    return InkWell(
      onTap: () => _showOrderDetailsSheet(context, order),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Card Top Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (order.createdAt != null)
                      Text(
                        '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}',
                        style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        order.status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Snapshot
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade100,
                        child: order.productImage.isNotEmpty
                            ? Image.network(
                                order.productImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.precision_manufacturing_outlined,
                                  color: AppColors.primaryGold,
                                ),
                              )
                            : const Icon(
                                Icons.precision_manufacturing_outlined,
                                color: AppColors.primaryGold,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.items.length > 1
                                ? '${order.items.first.productName} & ${order.items.length - 1} more parts'
                                : order.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.items.length > 1
                                ? '${order.items.length} parts • ${order.totalItemUnits} units'
                                : '${order.companyName} • ${order.categoryName}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Units: ${order.totalItemUnits}   •   ₹${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Customer Snapshot
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      order.userName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
                    ),
                    const Spacer(),
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      PhoneHelper.formatForDisplay(order.userPhone),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primaryGold),
                      tooltip: 'Copy Phone',
                      padding: const EdgeInsets.only(left: 6),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: order.userPhone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${order.userPhone} to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                if (order.shippingAddress != null && order.shippingAddress!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: AppColors.secondaryText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.shippingAddress!,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ],

                if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.secondaryText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '"${order.customerNote!}"',
                          style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ],

                if (order.adminRemark != null && order.adminRemark!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.rate_review_rounded, size: 14, color: AppColors.primaryGold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 11.5, color: AppColors.darkCharcoal),
                              children: [
                                const TextSpan(
                                  text: 'Admin Remark: ',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                TextSpan(
                                  text: order.adminRemark!,
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkCharcoal,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showOrderDetailsSheet(context, order),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text(
                        'View Details',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkCharcoal,
                        foregroundColor: AppColors.primaryGold,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showOrderStatusDialog(context, order),
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text(
                        'Status & Remark',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
    );
  }

  Widget _buildCategoryFilterChip(String category, String label, OrderProvider provider) {
    final isSelected = provider.categoryFilter.toLowerCase() == category.toLowerCase();
    return GestureDetector(
      onTap: () => provider.setCategoryFilter(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkCharcoal : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.darkCharcoal : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primaryGold : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterChip({
    required String label,
    required OrderDateFilter filter,
    required OrderDateFilter activeFilter,
    required VoidCallback onTap,
  }) {
    final isSelected = filter == activeFilter;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkCharcoal : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.darkCharcoal : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primaryGold : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip({
    required String status,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required OrderProvider provider,
  }) {
    final isSelected = provider.statusFilter == status;
    return GestureDetector(
      onTap: () => provider.setStatusFilter(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.5,
              color: isSelected ? (status == 'ALL' ? AppColors.primaryGold : Colors.white) : color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.22) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 20, color: accentColor),
                    if (isLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    else
                      Text(
                        count.toString(),
                        style: const TextStyle(
                          color: AppColors.darkCharcoal,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.darkCharcoal,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
