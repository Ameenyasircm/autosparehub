import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_login_provider.dart';
import '../../../providers/customer_management_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/phone_helper.dart';
import '../../../widgets/app_submit_button.dart';
import '../../../widgets/app_text_field.dart';
import 'sales_widgets.dart';

/// Admin creates an approved customer. Pops with the created [CustomerModel].
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSaving = false;
  String? _error;

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

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final provider = context.read<CustomerManagementProvider>();
    final admin = context.read<AdminLoginProvider>().currentAdmin;
    final created = await provider.addCustomerByAdmin(
      name: _nameController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      adminId: admin?.id,
    );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _error = created == null ? provider.errorMessage : null;
    });
    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer ${created.name} added.'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add Customer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) SalesErrorBanner(_error!),
                AppTextField(
                  label: 'Customer / Garage Name',
                  hint: 'Enter name',
                  controller: _nameController,
                  isRequired: true,
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  enabled: !_isSaving,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  controller: _phoneController,
                  isRequired: true,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  prefixIcon: Icons.phone_outlined,
                  enabled: !_isSaving,
                  validator: (v) =>
                      PhoneHelper.isValidIndianNumber(v) ? null : 'Enter a valid 10-digit mobile number',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'App Password',
                  hint: 'Minimum 6 characters',
                  controller: _passwordController,
                  isRequired: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  enabled: !_isSaving,
                  helperText: 'The customer can use this number and password to log in to the app.',
                  validator: (v) =>
                      (v == null || v.trim().length < 6) ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 28),
                AppSubmitButton(
                  label: 'Save Customer',
                  loadingLabel: 'Saving...',
                  icon: Icons.check_rounded,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
