import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';
import 'user_home_screen.dart';
import 'widgets/approval_pending_dialog.dart';
import 'widgets/contact_us_sheet.dart';

/// Garage User Sign In and Registration screen styled identically to AdminLoginScreen:
/// Clean background, circular emblem with gold border, rich branding, and crisp form card.
class UserLoginScreen extends StatefulWidget {
  final bool initialIsRegister;
  final VoidCallback? onAuthenticated;

  const UserLoginScreen({
    super.key,
    this.initialIsRegister = false,
    this.onAuthenticated,
  });

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  late bool _isRegisterMode;
  bool _obscureLoginPassword = true;
  bool _obscureRegPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.initialIsRegister;
  }

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  // --- LOGIN HANDLER ---
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_loginFormKey.currentState!.validate()) return;

    final authProvider = context.read<UserAuthProvider>();
    authProvider.clearError();

    final result = await authProvider.loginCustomer(
      phoneNumber: _loginPhoneController.text.trim(),
      password: _loginPasswordController.text,
    );

    if (!mounted) return;

    if (result == CustomerLoginResult.approved) {
      final customer = authProvider.currentCustomer;
      if (customer != null) {
        context.read<CartProvider>().loadCartForUser(customer.id);
      }

      widget.onAuthenticated?.call();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${customer?.name ?? 'Customer'}!'),
          backgroundColor: AppColors.darkButton,
        ),
      );
    } else if (result == CustomerLoginResult.pendingApproval) {
      _showPendingDialog(
        phone: _loginPhoneController.text.trim(),
        dateStr: 'Recently',
      );
    } else if (result == CustomerLoginResult.rejected) {
      _showRejectedDialog(phone: _loginPhoneController.text.trim());
    } else if (result == CustomerLoginResult.userNotFound) {
      // Auto navigate to registration form and pre-fill mobile & password
      final enteredPhone = _loginPhoneController.text.trim();
      final enteredPassword = _loginPasswordController.text;

      _regPhoneController.text = enteredPhone;
      if (enteredPassword.isNotEmpty) {
        _regPasswordController.text = enteredPassword;
        _regConfirmPasswordController.text = enteredPassword;
      }

      setState(() {
        _isRegisterMode = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account not found with this mobile. Please enter your Garage Name to register.'),
          backgroundColor: AppColors.darkButton,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Sign in failed. Check your credentials.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // --- REGISTRATION HANDLER ---
  Future<void> _handleRegistration() async {
    FocusScope.of(context).unfocus();
    if (!_registerFormKey.currentState!.validate()) return;

    final authProvider = context.read<UserAuthProvider>();
    authProvider.clearError();

    final result = await authProvider.registerCustomer(
      name: _regNameController.text.trim(),
      phoneNumber: _regPhoneController.text.trim(),
      password: _regPasswordController.text,
    );

    if (!mounted) return;

    if (result == CustomerRegistrationResult.newRequestSubmitted ||
        result == CustomerRegistrationResult.alreadyPending) {
      final phone = _regPhoneController.text.trim();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Garage account registered successfully! Waiting for admin approval.'),
          backgroundColor: AppColors.darkButton,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => UserHomeScreen(
            showPendingAlertOnStart: true,
            pendingPhone: phone,
          ),
        ),
        (route) => false,
      );
    } else if (result == CustomerRegistrationResult.alreadyApproved) {
      setState(() {
        _isRegisterMode = false;
        _loginPhoneController.text = _regPhoneController.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account is already approved! Please sign in with your password.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (result == CustomerRegistrationResult.alreadyRejected) {
      _showRejectedDialog(phone: _regPhoneController.text.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Registration failed. Try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // --- CONTACT ADMIN MODAL ---
  void _showContactAdminModal() {
    ContactUsSheet.show(context);
  }

  // --- PENDING DIALOG ---
  void _showPendingDialog({required String phone, String? dateStr}) {
    ApprovalPendingDialog.show(context, phone: phone, dateStr: dateStr);
  }

  // --- REJECTED DIALOG ---
  void _showRejectedDialog({required String phone}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.cancel_rounded, color: AppColors.error, size: 26),
            SizedBox(width: 10),
            Text('Account Not Approved', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mobile: +91 $phone', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 8),
            const Text(
              'This registration request was not approved by the administrator. Please reach out to customer support to re-verify your garage credentials.',
              style: TextStyle(fontSize: 12.5, color: AppColors.darkCharcoal, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkButton,
              foregroundColor: AppColors.warmGold,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _showContactAdminModal();
            },
            child: const Text('Contact Admin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkHeader, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- BRAND HEADER SECTION (MATCHING ADMIN LOGIN) ---
                  Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.warmGold.withValues(alpha: 0.6),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.warmGold.withValues(alpha: 0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/AutoSpareLogo.jpg',
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.darkHeader,
                            child: const Icon(
                              Icons.directions_car_rounded,
                              color: AppColors.warmGold,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Brand Title: "AUTO SPARE HUB"
                  Center(
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'AUTO SPARE ',
                            style: TextStyle(
                              color: AppColors.darkHeader,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'HUB',
                            style: TextStyle(
                              color: AppColors.warmGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Pill Badge: "GARAGE PORTAL"
                  // Center(
                  //   child: Container(
                  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  //     decoration: BoxDecoration(
                  //       color: AppColors.darkButton,
                  //       borderRadius: BorderRadius.circular(12),
                  //       border: Border.all(
                  //         color: AppColors.warmGold.withValues(alpha: 0.5),
                  //         width: 1,
                  //       ),
                  //     ),
                  //     child: const Text(
                  //       'GARAGE PORTAL',
                  //       style: TextStyle(
                  //         color: AppColors.warmGold,
                  //         fontSize: 10,
                  //         fontWeight: FontWeight.w800,
                  //         letterSpacing: 1.6,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 20),

                  // --- FORM CARD (MATCHING ADMIN LOGIN FORM CARD) ---
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEDEFF2), width: 1.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(22.0),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _isRegisterMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: _buildLoginForm(authProvider),
                      secondChild: _buildRegisterForm(authProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // --- LOGIN FORM ---
  // ==========================================
  Widget _buildLoginForm(UserAuthProvider authProvider) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Title
          const Text(
            'Sign In',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkHeader,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your registered mobile number and password.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFECEFF3)),
          const SizedBox(height: 16),

          // Error Banner (Matching Admin Login)
          if (authProvider.errorMessage != null) ...[
            _buildErrorBanner(authProvider.errorMessage!),
            const SizedBox(height: 16),
          ],

          // Mobile Number Field
          const Text(
            'Mobile Number',
            style: TextStyle(
              color: AppColors.darkHeader,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _loginPhoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !authProvider.isLoading,
            onChanged: (_) => authProvider.clearError(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkHeader,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter mobile number';
              }
              if (value.trim().length != 10) {
                return 'Enter valid 10-digit mobile number';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Enter registered mobile',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9EA3AC)),
              prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.warmGold, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.warmGold, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Password Field
          const Text(
            'Password',
            style: TextStyle(
              color: AppColors.darkHeader,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            textInputAction: TextInputAction.done,
            enabled: !authProvider.isLoading,
            onFieldSubmitted: (_) => _handleLogin(),
            onChanged: (_) => authProvider.clearError(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkHeader,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Enter your account password',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9EA3AC)),
              prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.warmGold, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.warmGold, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1.2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF8C95A6),
                  size: 20,
                ),
                tooltip: _obscureLoginPassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Submit Button (Matching Admin Login)
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: authProvider.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkButton,
                foregroundColor: AppColors.warmGold,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: authProvider.isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.warmGold),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Verifying...',
                          style: TextStyle(
                            color: AppColors.warmGold,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login_rounded, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Login',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // "Or" Separator
          _buildOrDivider(),
          const SizedBox(height: 16),

          // "Don't have a garage account?"
          const Center(
            child: Text(
              "Don't have a account?",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.darkCharcoal,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // "Register" Button (Outlined)
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCharcoal,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (_regPhoneController.text.isEmpty && _loginPhoneController.text.isNotEmpty) {
                  _regPhoneController.text = _loginPhoneController.text.trim();
                }
                if (_regPasswordController.text.isEmpty && _loginPasswordController.text.isNotEmpty) {
                  _regPasswordController.text = _loginPasswordController.text;
                  _regConfirmPasswordController.text = _loginPasswordController.text;
                }
                setState(() => _isRegisterMode = true);
              },
              child: const Text(
                'Register',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Contact Admin Link
          Center(
            child: TextButton(
              onPressed: _showContactAdminModal,
              child: const Text(
                'Contact to Admin',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // --- REGISTRATION FORM ---
  // ==========================================
  Widget _buildRegisterForm(UserAuthProvider authProvider) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Title
          const Text(
            'Create Garage Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkHeader,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Register your workshop to request spare parts directly.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFECEFF3)),
          const SizedBox(height: 16),

          // Error Banner
          if (authProvider.errorMessage != null) ...[
            _buildErrorBanner(authProvider.errorMessage!),
            const SizedBox(height: 16),
          ],

          // Garage / Contact Name
          const Text(
            'Garage or Contact Name',
            style: TextStyle(
              color: AppColors.darkHeader,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: !authProvider.isLoading,
            onChanged: (_) => authProvider.clearError(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkHeader,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter garage or contact name';
              }
              if (value.trim().length < 3) {
                return 'Name must be at least 3 characters';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'e.g. Speed Motors / Rahul',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9EA3AC)),
              prefixIcon: const Icon(Icons.storefront_rounded, color: AppColors.warmGold, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.warmGold, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mobile Number
          const Text(
            'Mobile Number',
            style: TextStyle(
              color: AppColors.darkHeader,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regPhoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !authProvider.isLoading,
            onChanged: (_) => authProvider.clearError(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkHeader,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter mobile number';
              }
              if (value.trim().length != 10) {
                return 'Must be a valid 10-digit mobile number';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Enter 10-digit mobile',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9EA3AC)),
              prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.warmGold, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.warmGold, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Password
          const Text(
            'Password',
            style: TextStyle(
              color: AppColors.darkHeader,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regPasswordController,
            obscureText: _obscureRegPassword,
            textInputAction: TextInputAction.next,
            enabled: !authProvider.isLoading,
            onChanged: (_) => authProvider.clearError(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkHeader,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please set a password';
              }
              if (value.length < 4) {
                return 'Password must be at least 4 characters';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Create a password (min 4 characters)',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9EA3AC)),
              prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.warmGold, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.warmGold, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1.2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF8C95A6),
                  size: 20,
                ),
                tooltip: _obscureRegPassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Password
          const Text(
            'Confirm Password',
            style: TextStyle(
              color: AppColors.darkHeader,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regConfirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            enabled: !authProvider.isLoading,
            onFieldSubmitted: (_) => _handleRegistration(),
            onChanged: (_) => authProvider.clearError(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkHeader,
            ),
            validator: (value) {
              if (value != _regPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9EA3AC)),
              prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.warmGold, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.warmGold, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1.2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF8C95A6),
                  size: 20,
                ),
                tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Register Action Button (Matching Admin Login)
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: authProvider.isLoading ? null : _handleRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkButton,
                foregroundColor: AppColors.warmGold,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: authProvider.isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.warmGold),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Registering...',
                          style: TextStyle(
                            color: AppColors.warmGold,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.app_registration_rounded, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Register Garage Account',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // "Or" Separator
          _buildOrDivider(),
          const SizedBox(height: 16),

          // "Already have a garage account?"
          const Center(
            child: Text(
              'Already have a garage account?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.darkCharcoal,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // "Sign In" Button (Outlined)
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCharcoal,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (_loginPhoneController.text.isEmpty && _regPhoneController.text.isNotEmpty) {
                  _loginPhoneController.text = _regPhoneController.text.trim();
                }
                setState(() => _isRegisterMode = false);
              },
              child: const Text(
                'Sign In to Existing Account',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Contact Admin Link
          Center(
            child: TextButton(
              onPressed: _showContactAdminModal,
              child: const Text(
                'Contact to Admin',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE UI HELPERS ---

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0xFFECEFF3), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: Color(0xFF9EA3AC),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFECEFF3), height: 1)),
      ],
    );
  }
}
