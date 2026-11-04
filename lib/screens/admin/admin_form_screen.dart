import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/admin_model.dart';
import '../../providers/admin_management_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_submit_button.dart';
import '../../widgets/app_text_field.dart';

/// Form screen for creating or editing administrator accounts.
class AdminFormScreen extends StatefulWidget {
  final AdminModel? adminToEdit;

  const AdminFormScreen({super.key, this.adminToEdit});

  bool get isEditing => adminToEdit != null;

  @override
  State<AdminFormScreen> createState() => _AdminFormScreenState();
}

class _AdminFormScreenState extends State<AdminFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;

  String _selectedRole = 'STAFF';
  bool _isActive = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final admin = widget.adminToEdit;
    _nameController = TextEditingController(text: admin?.name ?? '');
    _phoneController = TextEditingController(text: admin?.phoneNumber ?? '');
    _passwordController = TextEditingController();
    _selectedRole = admin?.type ?? 'STAFF';
    _isActive = admin?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AdminManagementProvider>();
    provider.clearError();

    bool success = false;

    if (widget.isEditing) {
      success = await provider.editAdmin(
        id: widget.adminToEdit!.id,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        type: _selectedRole,
        currentIsActive: _isActive,
        originalPhoneNumber: widget.adminToEdit!.phoneNumber,
      );
    } else {
      success = await provider.addAdmin(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        type: _selectedRole,
        password: _passwordController.text,
        isActive: _isActive,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Administrator updated successfully.'
                : 'Administrator created successfully.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminManagementProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Edit Administrator' : 'Add New Administrator',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error Banner
              if (provider.errorMessage != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Full Name Field
              // Full Name Field
              AppTextField(
                label: 'Administrator Full Name',
                hint: 'Enter full name',
                controller: _nameController,
                isRequired: true,
                textCapitalization: TextCapitalization.words,
                enabled: !provider.isSaving,
                prefixIcon: Icons.person_outline,
                isDarkTheme: true,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Administrator full name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Phone Number Field
              AppTextField(
                label: 'Phone Number',
                hint: '10-digit mobile number',
                controller: _phoneController,
                isRequired: true,
                keyboardType: TextInputType.phone,
                enabled: !provider.isSaving,
                prefixIcon: Icons.phone_android_outlined,
                isDarkTheme: true,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Registered phone number is required';
                  }
                  if (val.trim().length < 8) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Role Selector Dropdown
              AppDropdownField<String>(
                label: 'Administrator Role',
                hint: 'Select role',
                value: _selectedRole,
                isRequired: true,
                enabled: !provider.isSaving,
                prefixIcon: Icons.shield_outlined,
                isDarkTheme: true,
                items: const [
                  DropdownMenuItem(
                    value: 'MANAGER',
                    child: Text(
                      'MANAGER (Full Access)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'STAFF',
                    child: Text(
                      'STAFF (Catalog Access)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRole = val);
                },
              ),

              // Password Field (Only when creating new admin)
              if (!widget.isEditing) ...[
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Initial Password',
                  hint: 'Enter initial login password',
                  controller: _passwordController,
                  isRequired: true,
                  obscureText: _obscurePassword,
                  enabled: !provider.isSaving,
                  prefixIcon: Icons.lock_outline,
                  isDarkTheme: true,
                  suffixWidget: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.secondaryText,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Initial password is required';
                    }
                    if (val.length < 4) {
                      return 'Password must be at least 4 characters';
                    }
                    return null;
                  },
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Existing passwords are preserved securely and not displayed or overwritten during profile edits.',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Active Status Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Status',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          _isActive ? 'Active (Permitted to log in)' : 'Inactive (Login restricted)',
                          style: TextStyle(
                            color: _isActive ? AppColors.success : AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isActive,
                      activeColor: AppColors.primaryGold,
                      onChanged: provider.isSaving
                          ? null
                          : (val) => setState(() => _isActive = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button with modern spinner and informative text
              AppSubmitButton(
                label: widget.isEditing ? 'Update Administrator' : 'Create Administrator',
                loadingLabel: widget.isEditing ? 'Updating Administrator...' : 'Creating Administrator...',
                isLoading: provider.isSaving,
                icon: widget.isEditing ? Icons.check_circle_outline : Icons.person_add_outlined,
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.darkCharcoal,
                height: 52,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
