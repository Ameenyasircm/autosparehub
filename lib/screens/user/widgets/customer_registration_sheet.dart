import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_auth_provider.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet dialog prompting unauthenticated customer to register with Name & Phone.
/// Upon registration, the profile is set to PENDING awaiting Admin approval.
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
    final success = await authProvider.registerCustomer(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      widget.onRegistered?.call();

      // Show informational dialog explaining approval workflow
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
            children: const [
              Text(
                'Thank you for registering with AutoSpare Hub!',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                'To maintain high-quality fulfillment, your account is currently pending review by our administration team. Once approved, you can place orders immediately.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.4),
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

            // Phone Field
            const Text(
              'Mobile / WhatsApp Phone Number *',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !authProvider.isLoading,
              decoration: const InputDecoration(
                hintText: 'e.g. 9876543210',
                prefixIcon: Icon(Icons.phone_android_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Phone number is required';
                if (val.trim().length < 7) return 'Please enter a valid phone number';
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
                      'Admin approval is required once before placing orders.',
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
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(AppColors.darkCharcoal)),
                      )
                    : const Text(
                        'Submit for Approval',
                        style: TextStyle(
                          color: AppColors.darkCharcoal,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
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
