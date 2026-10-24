import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/customer_model.dart';
import '../../providers/admin_login_provider.dart';
import '../../providers/customer_management_provider.dart';
import '../../theme/app_theme.dart';
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
      body: provider.isLoading
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
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: customers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _buildCard(customer, adminId, isPendingTab);
      },
    );
  }

  Widget _buildCard(CustomerModel customer, String? adminId, bool isPendingTab) {
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

    final requestedDate = customer.requestedAt;
    final dateStr = requestedDate != null
        ? '${requestedDate.day}/${requestedDate.month}/${requestedDate.year} at ${requestedDate.hour.toString().padLeft(2, '0')}:${requestedDate.minute.toString().padLeft(2, '0')}'
        : '--';

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            customer.status,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 2),
                    Text(
                      'Requested: $dateStr',
                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (customer.rejectionReason != null && customer.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Rejection Reason: ${customer.rejectionReason}',
                style: const TextStyle(color: AppColors.error, fontSize: 11.5),
              ),
            ),
          ],

          if (isPendingTab) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showRejectDialog(context, customer),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final provider = context.read<CustomerManagementProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await provider.approveCustomer(customer.id, adminId: adminId);
                    if (mounted && ok) {
                      messenger.showSnackBar(
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
        ],
      ),
    );
  }
}
