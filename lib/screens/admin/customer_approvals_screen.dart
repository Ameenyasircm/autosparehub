import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/customer_model.dart';
import '../../providers/admin_login_provider.dart';
import '../../providers/customer_management_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/contact_service.dart';
import '../../utils/phone_helper.dart';

/// Screen for administrators to review, approve, and reject customer account requests.
/// Features dedicated tabs for Pending, Approved, and Rejected customer profiles.
class CustomerApprovalsScreen extends StatefulWidget {
  const CustomerApprovalsScreen({super.key});

  @override
  State<CustomerApprovalsScreen> createState() => _CustomerApprovalsScreenState();
}

class _CustomerApprovalsScreenState extends State<CustomerApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _contactService = ContactService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerManagementProvider>().listenToCustomers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRejectDialog(BuildContext context, CustomerModel customer) {
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
            Text('Reject Customer Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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

  void _showChangePasswordDialog(BuildContext context, CustomerModel customer) {
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
                Text('Mobile: ${PhoneHelper.formatForDisplay(customer.phone)}', style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText)),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerManagementProvider>();
    final currentAdmin = context.read<AdminLoginProvider>().currentAdmin;

    final pendingList = provider.customers.where((c) => c.isPending).toList();
    final approvedList = provider.customers.where((c) => c.isApproved).toList();
    final rejectedList = provider.customers.where((c) => c.isRejected).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: const Text(
          'Customer Approvals',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.lightGold),
            tooltip: 'Refresh',
            onPressed: () => provider.fetchCustomers(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGold,
          indicatorWeight: 3,
          labelColor: AppColors.primaryGold,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(text: 'Pending (${pendingList.length})'),
            Tab(text: 'Approved (${approvedList.length})'),
            Tab(text: 'Rejected (${rejectedList.length})'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: provider.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  // 1. Pending Tab
                  _buildCustomerList(
                    customers: pendingList,
                    emptyMessage: 'No pending customer approval requests.',
                    adminId: currentAdmin?.id,
                    isPendingTab: true,
                  ),

                  // 2. Approved Tab
                  _buildCustomerList(
                    customers: approvedList,
                    emptyMessage: 'No approved customers yet.',
                    adminId: currentAdmin?.id,
                    isPendingTab: false,
                  ),

                  // 3. Rejected Tab
                  _buildCustomerList(
                    customers: rejectedList,
                    emptyMessage: 'No rejected requests.',
                    adminId: currentAdmin?.id,
                    isPendingTab: false,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCustomerList({
    required List<CustomerModel> customers,
    required String emptyMessage,
    required String? adminId,
    required bool isPendingTab,
  }) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      physics: const BouncingScrollPhysics(),
      itemCount: customers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _buildCard(customer, adminId, isPendingTab, index + 1);
      },
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} $month, $hour:$minute $ampm';
  }

  Widget _buildCard(CustomerModel customer, String? adminId, bool isPendingTab, int serialNumber) {
    Color badgeColor;
    Color badgeBg;
    if (customer.isApproved) {
      badgeColor = AppColors.success;
      badgeBg = Colors.green.shade50;
    } else if (customer.isRejected) {
      badgeColor = AppColors.error;
      badgeBg = Colors.red.shade50;
    } else {
      badgeColor = Colors.amber.shade800;
      badgeBg = Colors.amber.shade50;
    }

    final dateStr = _formatDate(customer.requestedAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Avatar, Name & Phone & Date, Status Badge & Call/WhatsApp
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppColors.darkCharcoal,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: AppColors.darkCharcoal.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$serialNumber',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkCharcoal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: customer.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${customer.phone} to clipboard'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined, size: 12, color: AppColors.secondaryText),
                          const SizedBox(width: 3),
                          Text(
                            PhoneHelper.formatForDisplay(customer.phone),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_rounded, size: 11, color: AppColors.primaryGold),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      customer.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Call ${customer.name}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await _contactService.launchPhoneCall(customer.phone);
                            if (!ok && mounted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Could not open phone dialer')),
                              );
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.darkCharcoal.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.borderSoft, width: 0.8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.phone_in_talk_rounded,
                              size: 14,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'WhatsApp ${customer.name}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await _contactService.launchWhatsApp(
                              customer.phone,
                              'Hello ${customer.name}, contacting you regarding your Auto Spare Hub account.',
                            );
                            if (!ok && mounted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Could not open WhatsApp')),
                              );
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3), width: 0.8),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/member_whats_app.png',
                              width: 15,
                              height: 15,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Rejection reason snippet if rejected
          if (customer.rejectionReason != null && customer.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                'Reason: ${customer.rejectionReason}',
                style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.dividerLight),
          const SizedBox(height: 8),

          // Action row
          _buildActionRow(context, customer, adminId, isPendingTab),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, CustomerModel customer, String? adminId, bool isPendingTab) {
    if (isPendingTab) {
      return Row(
        children: [
          SizedBox(
            height: 28,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkCharcoal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _showChangePasswordDialog(context, customer),
              icon: const Icon(Icons.lock_reset_rounded, size: 15, color: AppColors.primaryGold),
              label: const Text('Password', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _showRejectDialog(context, customer),
              child: const Text('Reject', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () async {
                final provider = context.read<CustomerManagementProvider>();
                final messenger = ScaffoldMessenger.of(context);
                final ok = await provider.approveCustomer(customer.id, adminId: adminId);
                if (mounted && ok) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Approved ${customer.name}!')),
                  );
                }
              },
              icon: const Icon(Icons.check_rounded, size: 14),
              label: const Text('Approve', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
    }

    if (customer.isApproved) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 28,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCharcoal,
                side: const BorderSide(color: AppColors.borderSoft),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _showChangePasswordDialog(context, customer),
              icon: const Icon(Icons.lock_reset_rounded, size: 14, color: AppColors.primaryGold),
              label: const Text('Change Password', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _showRejectDialog(context, customer),
              icon: const Icon(Icons.block_rounded, size: 13),
              label: const Text('Revoke', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }

    // Rejected Tab
    return Row(
      children: [
        SizedBox(
          height: 28,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.darkCharcoal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _showChangePasswordDialog(context, customer),
            icon: const Icon(Icons.lock_reset_rounded, size: 15, color: AppColors.primaryGold),
            label: const Text('Password', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 28,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              final provider = context.read<CustomerManagementProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final ok = await provider.approveCustomer(customer.id, adminId: adminId);
              if (mounted && ok) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Re-approved ${customer.name}!')),
                );
              }
            },
            icon: const Icon(Icons.check_rounded, size: 14),
            label: const Text('Re-Approve', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
