import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_auth_provider.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet dialog prompting unauthenticated customer to register with Name & 10-digit Indian mobile.
/// Handles duplicate request detection, pending status notice, and approved auto-login.
class CustomerRegistrationSheet extends StatefulWidget {
  final VoidCallback? onRegistered;

  const CustomerRegistrationSheet({super.key, this.onRegistered});

  static Future<void> show(BuildContext context, {VoidCallback? onRegistered}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CustomerRegistrationSheet(onRegistered: onRegistered),
    );
  }

  @override
  State<CustomerRegistrationSheet> createState() => _CustomerRegistrationSheetState();
}

class _CustomerRegistrationSheetState extends State<CustomerRegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<UserAuthProvider>();
    final result = await authProvider.registerCustomer(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    if (!mounted) return;

    // Case 1: Same mobile number already submitted and awaiting admin approval
    if (result == CustomerRegistrationResult.alreadyPending) {
      Navigator.of(context).pop();
      final requestedDate = authProvider.currentCustomer?.requestedAt;
      final dateStr = requestedDate != null
          ? '${requestedDate.day}/${requestedDate.month}/${requestedDate.year}'
          : 'recently';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Request Already Pending',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approval request for +91 ${_phoneController.text.trim()} is already under review by our administrator (submitted on $dateStr).',
                style: const TextStyle(color: AppColors.darkCharcoal, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 10),
              const Text(
                'You do not need to submit another request. Once an admin approves your account, ordering will unlock automatically.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                foregroundColor: AppColors.primaryGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }
    // Case 2: Mobile number is already approved in database
    else if (result == CustomerRegistrationResult.alreadyApproved) {
      Navigator.of(context).pop();
      widget.onRegistered?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${authProvider.currentCustomer?.name ?? ''}! Account is approved.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
    // Case 3: Mobile number was previously rejected
    else if (result == CustomerRegistrationResult.alreadyRejected) {
      Navigator.of(context).pop();
      final reason = authProvider.currentCustomer?.rejectionReason ?? 'Account details could not be verified.';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.cancel_rounded, color: AppColors.error, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text('Registration Not Approved', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your previous request was not approved by the admin team:',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  reason,
                  style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                foregroundColor: AppColors.primaryGold,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final ok = await authProvider.reapplyRegistration();
                if (mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Re-application submitted for admin review.')),
                  );
                }
              },
              child: const Text('Re-submit Request'),
            ),
          ],
        ),
      );
    }
    // Case 4: Brand new request submitted successfully
    else if (result == CustomerRegistrationResult.newRequestSubmitted) {
      Navigator.of(context).pop();
      widget.onRegistered?.call();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.hourglass_top_rounded, color: AppColors.primaryGold, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Awaiting Admin Approval',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thank you for registering, ${_nameController.text.trim()}!',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Your request (+91 ${_phoneController.text.trim()}) has been submitted for administrator review. Once verified, you will be able to order parts immediately.',
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                foregroundColor: AppColors.primaryGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primaryGold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Customer Registration',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                      ),
                      Text(
                        'Provide your details to request order access',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),

            // Name Field
            const Text(
              'Your Full Name *',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              enabled: !authProvider.isLoading,
              decoration: const InputDecoration(
                hintText: 'e.g. Mohammed Ameen',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Please enter your name' : null,
            ),

            const SizedBox(height: 16),

            // Phone Field (Strictly 10-digit Indian Mobile)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Indian Mobile Number *',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
                ),
                Text(
                  '10 Digits',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !authProvider.isLoading,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                hintText: '9876543210',
                counterText: '',
                prefixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.phone_android_outlined, size: 20, color: AppColors.primaryGold),
                      SizedBox(width: 6),
                      Text(
                        '+91 ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return '10-digit mobile number is required';
                }
                final cleaned = val.replaceAll(RegExp(r'\D'), '');
                if (cleaned.length != 10) {
                  return 'Mobile number must be exactly 10 digits';
                }
                if (!RegExp(r'^[6-9]').hasMatch(cleaned)) {
                  return 'Indian numbers must start with 6, 7, 8, or 9';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.security_outlined, size: 16, color: AppColors.secondaryGold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Approval is needed once per mobile number before ordering.',
                      style: TextStyle(fontSize: 11.5, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            if (authProvider.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                authProvider.errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 20),

            // Submit Button
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryGold, AppColors.lightGold]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: authProvider.isLoading ? null : _submit,
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkCharcoal),
                        ),
                      )
                    : const Text(
                        'Submit Approval Request',
                        style: TextStyle(
                          color: AppColors.darkCharcoal,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
