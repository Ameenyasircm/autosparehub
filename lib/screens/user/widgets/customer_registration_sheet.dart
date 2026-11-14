import 'package:flutter/material.dart';
import 'package:auto_spare_hub/utils/snackbar_helper.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/user_auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widgets/app_submit_button.dart';
import '../../../widgets/app_text_field.dart';
import '../user_login_screen.dart';

/// Modal bottom sheet providing seamless customer account Registration & Sign In.
/// Allows setting a password during registration, logging in once approved,
/// checking pending approval status, and synchronizing customer shopping carts.
class CustomerRegistrationSheet extends StatefulWidget {
  final VoidCallback? onRegistered;
  final bool initialIsLogin;

  const CustomerRegistrationSheet({
    super.key,
    this.onRegistered,
    this.initialIsLogin = false,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onRegistered,
    bool initialIsLogin = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserLoginScreen(
          initialIsRegister: !initialIsLogin,
          onAuthenticated: onRegistered,
        ),
      ),
    );
  }

  @override
  State<CustomerRegistrationSheet> createState() => _CustomerRegistrationSheetState();
}

class _CustomerRegistrationSheetState extends State<CustomerRegistrationSheet> {
  final _regFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  late bool _isLoginMode;
  bool _obscureRegPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureLoginPassword = true;

  @override
  void initState() {
    super.initState();
    _isLoginMode = widget.initialIsLogin;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  // --- SUBMIT REGISTRATION ---
  Future<void> _submitRegistration() async {
    if (!_regFormKey.currentState!.validate()) return;

    final authProvider = context.read<UserAuthProvider>();
    authProvider.clearError();

    final result = await authProvider.registerCustomer(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    // Cases 1-4: mobile number already registered (any status). One account
    // per number, so switch to sign in instead of creating/logging in.
    if (result == CustomerRegistrationResult.alreadyPending ||
        result == CustomerRegistrationResult.alreadyApproved ||
        result == CustomerRegistrationResult.alreadyRejected ||
        result == CustomerRegistrationResult.alreadyExists) {
      setState(() {
        _isLoginMode = true;
        _loginPhoneController.text = _phoneController.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBarAutoHide(
        SnackBar(
          content: Text(authProvider.errorMessage ??
              'This mobile number is already registered. Please sign in.'),
          backgroundColor: AppColors.darkCharcoal,
        ),
      );
    }
    // Case 5: Brand new request submitted -> awaiting admin approval
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
                'Registration Submitted, ${_nameController.text.trim()}!',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account (+91 ${_phoneController.text.trim()}) and password have been created. It is currently under review by our administrator.',
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Once an administrator approves your account, you will be able to log in and order spare parts directly.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.darkCharcoal, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    SizedBox(height: 8),
                    Divider(height: 1, color: Color(0xFFFFE082)),
                    SizedBox(height: 8),
                    Text(
                      'നിങ്ങളുടെ അക്കൗണ്ട് അഡ്മിൻ പരിശോധിച്ച് അംഗീകരിച്ച ശേഷം മാത്രമേ ലോഗിൻ ചെയ്യാനും സ്പെയർ പാർട്സുകൾ ഓർഡർ ചെയ്യാനും സാധിക്കൂ.',
                      style: TextStyle(fontSize: 12, color: AppColors.darkCharcoal, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
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
              child: const Text('Ok', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }
  }

  // --- SUBMIT LOGIN ---
  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final authProvider = context.read<UserAuthProvider>();
    authProvider.clearError();

    final result = await authProvider.loginCustomer(
      phoneNumber: _loginPhoneController.text.trim(),
      password: _loginPasswordController.text.trim(),
    );

    if (!mounted) return;

    if (result == CustomerLoginResult.approved) {
      // Auto fetch customer cart from DB
      final customerId = authProvider.currentCustomer?.id;
      if (customerId != null) {
        context.read<CartProvider>().loadCartForUser(customerId);
      }

      Navigator.of(context).pop();
      widget.onRegistered?.call();

      ScaffoldMessenger.of(context).showSnackBarAutoHide(
        SnackBar(
          content: Text('Welcome back, ${authProvider.currentCustomer?.name ?? 'Customer'}!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (result == CustomerLoginResult.pendingApproval) {
      Navigator.of(context).pop();
      final requestedDate = authProvider.currentCustomer?.requestedAt;
      final dateStr = requestedDate != null
          ? '${requestedDate.day}/${requestedDate.month}/${requestedDate.year}'
          : 'recently';

      _showPendingDialog(
        phone: _loginPhoneController.text.trim(),
        dateStr: dateStr,
      );
    } else if (result == CustomerLoginResult.rejected) {
      Navigator.of(context).pop();
      _showRejectionDialog(authProvider.currentCustomer?.rejectionReason);
    } else if (result == CustomerLoginResult.userNotFound) {
      ScaffoldMessenger.of(context).showSnackBarAutoHide(
        const SnackBar(
          content: Text('No account found for this number. Please register first.'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() {
        _isLoginMode = false;
        _phoneController.text = _loginPhoneController.text.trim();
        if (_loginPasswordController.text.isNotEmpty) {
          _passwordController.text = _loginPasswordController.text;
          _confirmPasswordController.text = _loginPasswordController.text;
        }
      });
    }
  }

  void _showPendingDialog({required String phone, required String dateStr}) {
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
                'Approval Still Pending',
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
              'Your registration for +91 $phone is under review by our administrator (submitted on $dateStr).',
              style: const TextStyle(color: AppColors.darkCharcoal, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Once an administrator approves your account, full ordering privileges will unlock immediately.',
                    style: TextStyle(color: AppColors.darkCharcoal, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                  SizedBox(height: 8),
                  Divider(height: 1, color: Color(0xFFFFE082)),
                  SizedBox(height: 8),
                  Text(
                    'അഡ്മിന്റെ അനുമതിക്കായി കാത്തിരിക്കുന്നു. അഡ്മിൻ പരിശോധിച്ച് അംഗീകരിച്ച ശേഷം മാത്രമേ ലോഗിൻ ചെയ്യാനും ഓർഡറുകൾ നൽകാനും സാധിക്കൂ.',
                    style: TextStyle(color: AppColors.darkCharcoal, fontSize: 12, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = context.read<UserAuthProvider>();
              await auth.logout();
              if (mounted) {
                context.read<CartProvider>().onUserLogout();
                ScaffoldMessenger.of(context).showSnackBarAutoHide(
                  const SnackBar(content: Text('Logged out successfully.')),
                );
              }
            },
            child: const Text('Log Out'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = context.read<UserAuthProvider>();
              await auth.refreshApprovalStatus();
              if (mounted) {
                if (auth.isApproved) {
                  ScaffoldMessenger.of(context).showSnackBarAutoHide(
                    const SnackBar(content: Text('Account is now approved! You can log in.'), backgroundColor: AppColors.success),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBarAutoHide(
                    const SnackBar(content: Text('Still pending administrator review.')),
                  );
                }
              }
            },
            child: const Text('Check Status'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkCharcoal,
              foregroundColor: AppColors.primaryGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ok', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showRejectionDialog(String? reason) {
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
              'Your registration request was not approved by the admin team:',
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
                reason ?? 'Account details could not be verified.',
                style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = context.read<UserAuthProvider>();
              await auth.logout();
              if (mounted) {
                context.read<CartProvider>().onUserLogout();
                ScaffoldMessenger.of(context).showSnackBarAutoHide(
                  const SnackBar(content: Text('Logged out successfully.')),
                );
              }
            },
            child: const Text('Log Out'),
          ),
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
              final authProvider = context.read<UserAuthProvider>();
              final ok = await authProvider.reapplyRegistration();
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBarAutoHide(
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isTablet = ResponsiveHelper.isTablet(context);

    return SafeArea(
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 520 : double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
            child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Segmented Mode Switcher (Register | Sign In)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E6EC)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLoginMode = false;
                        });
                        authProvider.clearError();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: !_isLoginMode ? AppColors.darkCharcoal : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !_isLoginMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Register Account',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: !_isLoginMode ? AppColors.primaryGold : AppColors.darkCharcoal,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLoginMode = true;
                        });
                        authProvider.clearError();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _isLoginMode ? AppColors.darkCharcoal : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _isLoginMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Sign In',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _isLoginMode ? AppColors.primaryGold : AppColors.darkCharcoal,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Mode Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLoginMode ? Icons.login_rounded : Icons.person_add_alt_1_outlined,
                    color: AppColors.primaryGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoginMode ? 'Customer Sign In' : 'New Customer Registration',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      Text(
                        _isLoginMode
                            ? 'Enter mobile & password to access your account'
                            : 'Set your name, mobile & password for admin approval',
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: AppColors.dividerLight),
            const SizedBox(height: 10),

            // Form Content: Either Registration or Sign In
            if (!_isLoginMode) ...[
              _buildRegistrationForm(authProvider),
            ] else ...[
              _buildLoginForm(authProvider),
            ],

            if (authProvider.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  authProvider.errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
      ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(UserAuthProvider authProvider) {
    return Form(
      key: _regFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name Field
          AppTextField(
            label: 'Full Name',
            hint: 'Enter your full name',
            controller: _nameController,
            isRequired: true,
            textCapitalization: TextCapitalization.words,
            enabled: !authProvider.isLoading,
            prefixIcon: Icons.person_outline,
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Please enter your full name' : null,
          ),

          const SizedBox(height: 14),

          // Phone Field
          AppTextField(
            label: 'Phone Number',
            hint: '10-digit mobile number',
            controller: _phoneController,
            isRequired: true,
            keyboardType: TextInputType.phone,
            enabled: !authProvider.isLoading,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefixWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.phone_android_outlined, size: 18, color: AppColors.primaryGold),
                  SizedBox(width: 4),
                  Text(
                    '+91 ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return '10-digit mobile number is required';
              final cleaned = val.replaceAll(RegExp(r'\D'), '');
              if (cleaned.length != 10) return 'Must be exactly 10 digits';
              if (!RegExp(r'^[6-9]').hasMatch(cleaned)) return 'Must start with 6, 7, 8, or 9';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Password Field
          AppTextField(
            label: 'Password',
            hint: 'Enter password',
            controller: _passwordController,
            isRequired: true,
            obscureText: _obscureRegPassword,
            enabled: !authProvider.isLoading,
            prefixIcon: Icons.lock_outline,
            suffixWidget: IconButton(
              icon: Icon(
                _obscureRegPassword ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: AppColors.secondaryText,
              ),
              onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please set a password';
              if (val.trim().length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Confirm Password Field
          AppTextField(
            label: 'Confirm Password',
            hint: 'Re-enter password',
            controller: _confirmPasswordController,
            isRequired: true,
            obscureText: _obscureConfirmPassword,
            enabled: !authProvider.isLoading,
            prefixIcon: Icons.lock_reset_outlined,
            suffixWidget: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: AppColors.secondaryText,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (val) {
              if (val != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Notice Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFECEFF3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.secondaryGold),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Admin approval is required once before ordering parts.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.darkCharcoal, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Submit Button with loader & informative text
          AppSubmitButton(
            label: 'Register & Request Approval',
            loadingLabel: 'Submitting Registration...',
            isLoading: authProvider.isLoading,
            onPressed: _submitRegistration,
            icon: Icons.how_to_reg_outlined,
            backgroundColor: AppColors.primaryGold,
            foregroundColor: AppColors.darkCharcoal,
          ),

          const SizedBox(height: 10),

          // Switch to Sign In Link
          Center(
            child: TextButton(
              onPressed: () {
                setState(() => _isLoginMode = true);
                authProvider.clearError();
              },
              child: const Text(
                'Already have an approved account? Sign In',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(UserAuthProvider authProvider) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phone Field
          AppTextField(
            label: 'Phone Number',
            hint: '10-digit mobile number',
            controller: _loginPhoneController,
            isRequired: true,
            keyboardType: TextInputType.phone,
            enabled: !authProvider.isLoading,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefixWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.phone_android_outlined, size: 18, color: AppColors.primaryGold),
                  SizedBox(width: 4),
                  Text(
                    '+91 ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter your registered mobile number';
              final cleaned = val.replaceAll(RegExp(r'\D'), '');
              if (cleaned.length != 10) return 'Must be exactly 10 digits';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Password Field
          AppTextField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _loginPasswordController,
            isRequired: true,
            obscureText: _obscureLoginPassword,
            enabled: !authProvider.isLoading,
            prefixIcon: Icons.lock_outline,
            suffixWidget: IconButton(
              icon: Icon(
                _obscureLoginPassword ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: AppColors.secondaryText,
              ),
              onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Please enter your password' : null,
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFECEFF3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 16, color: AppColors.secondaryText),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Once approved by admin, sign in to order spare parts.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Sign In Button
          AppSubmitButton(
            label: 'Sign In to Account',
            loadingLabel: 'Signing In...',
            isLoading: authProvider.isLoading,
            onPressed: _submitLogin,
            icon: Icons.login_rounded,
            backgroundColor: AppColors.primaryGold,
            foregroundColor: AppColors.darkCharcoal,
          ),

          const SizedBox(height: 10),

          // Switch to Register Link
          Center(
            child: TextButton(
              onPressed: () {
                setState(() => _isLoginMode = false);
                authProvider.clearError();
              },
              child: const Text(
                'New customer? Register for account approval',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
