import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/user_auth_provider.dart';
import '../../../theme/app_theme.dart';
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

    // Case 1: Account already pending approval
    if (result == CustomerRegistrationResult.alreadyPending) {
      Navigator.of(context).pop();
      final requestedDate = authProvider.currentCustomer?.requestedAt;
      final dateStr = requestedDate != null
          ? '${requestedDate.day}/${requestedDate.month}/${requestedDate.year}'
          : 'recently';

      _showPendingDialog(
        phone: _phoneController.text.trim(),
        dateStr: dateStr,
      );
    }
    // Case 2: Account already approved -> Switch to sign in or auto login
    else if (result == CustomerRegistrationResult.alreadyApproved) {
      setState(() {
        _isLoginMode = true;
        _loginPhoneController.text = _phoneController.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account is already approved! Please sign in with your password.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
    // Case 3: Mobile was previously rejected
    else if (result == CustomerRegistrationResult.alreadyRejected) {
      Navigator.of(context).pop();
      _showRejectionDialog(authProvider.currentCustomer?.rejectionReason);
    }
    // Case 4: Account exists
    else if (result == CustomerRegistrationResult.alreadyExists) {
      setState(() {
        _isLoginMode = true;
        _loginPhoneController.text = _phoneController.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An account already exists for this mobile number. Please sign in.'),
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

      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
                ScaffoldMessenger.of(context).showSnackBar(
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account is now approved! You can log in.'), backgroundColor: AppColors.success),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
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
                ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
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
    );
  }

  Widget _buildRegistrationForm(UserAuthProvider authProvider) {
    return Form(
      key: _regFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name Field
          const Text(
            'Full Name *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            enabled: !authProvider.isLoading,
            decoration: const InputDecoration(
              hintText: 'e.g. Mohammed Ameen',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Please enter your full name' : null,
          ),

          const SizedBox(height: 14),

          // Phone Field
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
          const Text(
            'Set Account Password *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscureRegPassword,
            enabled: !authProvider.isLoading,
            decoration: InputDecoration(
              hintText: 'Minimum 6 characters',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureRegPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please set a password';
              if (val.trim().length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Confirm Password Field
          const Text(
            'Confirm Password *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            enabled: !authProvider.isLoading,
            decoration: InputDecoration(
              hintText: 'Re-enter password',
              prefixIcon: const Icon(Icons.lock_reset_outlined, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (val) {
              if (val != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Notice Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(left: 24),
                  child: Text(
                    'പാർട്സുകൾ ഓർഡർ ചെയ്യുന്നതിന് മുൻപ് അഡ്മിന്റെ അനുമതി ആവശ്യമാണ്.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.secondaryText),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

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
              onPressed: authProvider.isLoading ? null : _submitRegistration,
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
                      'Register & Request Approval',
                      style: TextStyle(
                        color: AppColors.darkCharcoal,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
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
            controller: _loginPhoneController,
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
          const Text(
            'Password *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            enabled: !authProvider.isLoading,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureLoginPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
              ),
            ),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Please enter your password' : null,
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(left: 24),
                  child: Text(
                    'അഡ്മിൻ അനുമതി നൽകിയ ശേഷം മാത്രമേ ലോഗിൻ ചെയ്യാൻ സാധിക്കൂ.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.secondaryText),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Sign In Button
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
              onPressed: authProvider.isLoading ? null : _submitLogin,
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
                      'Sign In to Account',
                      style: TextStyle(
                        color: AppColors.darkCharcoal,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
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
