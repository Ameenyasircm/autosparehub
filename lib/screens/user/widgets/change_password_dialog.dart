import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_auth_provider.dart';
import '../../../theme/app_theme.dart';

/// Modal dialog allowing a signed-in customer to update their account password.
class ChangeUserPasswordDialog extends StatefulWidget {
  const ChangeUserPasswordDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangeUserPasswordDialog(),
    );
  }

  @override
  State<ChangeUserPasswordDialog> createState() => _ChangeUserPasswordDialogState();
}

class _ChangeUserPasswordDialogState extends State<ChangeUserPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserAuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<UserAuthProvider>();
    final success = await authProvider.changePassword(
      oldPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_reset_rounded, color: AppColors.primaryGold, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Change Password',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppColors.secondaryText),
            visualDensity: VisualDensity.compact,
            onPressed: authProvider.isLoading ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Enter your current password and choose a new password with at least 6 characters.',
                style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Current Password Field
              const Text(
                'Current Password *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                enabled: !authProvider.isLoading,
                decoration: InputDecoration(
                  hintText: 'Enter current password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter your current password' : null,
              ),

              const SizedBox(height: 14),

              // New Password Field
              const Text(
                'New Password *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                enabled: !authProvider.isLoading,
                decoration: InputDecoration(
                  hintText: 'Minimum 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter a new password';
                  if (val.trim().length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Confirm New Password Field
              const Text(
                'Confirm New Password *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                enabled: !authProvider.isLoading,
                decoration: InputDecoration(
                  hintText: 'Re-enter new password',
                  prefixIcon: const Icon(Icons.lock_clock_outlined, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please confirm your new password';
                  if (val.trim() != _newPasswordController.text.trim()) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              // Error display
              if (authProvider.errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authProvider.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: authProvider.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkCharcoal,
            foregroundColor: AppColors.primaryGold,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: authProvider.isLoading ? null : _submit,
          child: authProvider.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
                  ),
                )
              : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
