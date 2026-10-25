import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/user_auth_provider.dart';
import '../../theme/app_theme.dart';

/// Full-screen Garage User Sign In and Registration adhering to the exact
/// visual mockup theme with crisp borders, dark obsidian buttons, and warm gold accents.
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
    if (!_registerFormKey.currentState!.validate()) return;

    final authProvider = context.read<UserAuthProvider>();
    authProvider.clearError();

    final result = await authProvider.registerCustomer(
      name: _regNameController.text.trim(),
      phoneNumber: _regPhoneController.text.trim(),
      password: _regPasswordController.text,
    );

    if (!mounted) return;

    if (result == CustomerRegistrationResult.alreadyPending) {
      _showPendingDialog(
        phone: _regPhoneController.text.trim(),
        dateStr: 'Recently',
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
    } else if (result == CustomerRegistrationResult.newRequestSubmitted) {
      _showPendingDialog(
        phone: _regPhoneController.text.trim(),
        dateStr: 'Today',
      );
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/AutoSpareLogo.jpg',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Auto Spare Hub Support',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkCharcoal),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'For garage account authorization, direct part inquiries, or password resets, contact our team directly:',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined, color: AppColors.primaryGold, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Direct Helpline', style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText)),
                        SizedBox(height: 2),
                        Text('+91 98765 43210', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.primaryGold, size: 20),
                    tooltip: 'Copy Number',
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: '9876543210'));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Helpline number copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- PENDING DIALOG ---
  void _showPendingDialog({required String phone, required String dateStr}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 26),
            SizedBox(width: 10),
            Text('Approval Pending', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mobile: +91 $phone', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 8),
            const Text(
              'Your garage account registration has been submitted and is currently waiting for administrator authorization. Once approved, you can log in and place orders directly.',
              style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'നിങ്ങളുടെ രജിസ്ട്രേഷൻ അഡ്മിൻ പരിശോധിച്ചുകൊണ്ടിരിക്കുകയാണ്. പരിശോധന പൂർത്തിയാക്കിയ ശേഷം അഡ്മിൻ നിങ്ങളെ നേരിട്ട് ബന്ധപ്പെടുന്നതാണ്. ദയവായി കാത്തിരിക്കുക!',
                style: TextStyle(fontSize: 11.5, color: AppColors.darkCharcoal, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.darkCharcoal)),
          ),
        ],
      ),
    );
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
              style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.darkCharcoal, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isRegisterMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: _buildLoginForm(authProvider),
            secondChild: _buildRegisterForm(authProvider),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // --- LOGIN FORM (EXACT MATCH TO IMAGE 1) ---
  // ==========================================
  Widget _buildLoginForm(UserAuthProvider authProvider) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circular Logo Emblem
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/AutoSpareLogo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.darkCharcoal,
                  child: const Icon(Icons.directions_car, color: AppColors.primaryGold, size: 36),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Welcome Back Header
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in to request the spare parts your garage needs.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),

          // Mobile Number Field
          const Text(
            'Mobile Number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _loginPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal),
            decoration: InputDecoration(
              hintText: 'Enter your registered mobile number',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9EA3AC)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkButton, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter mobile number';
              if (val.trim().length != 10) return 'Enter valid 10-digit mobile number';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Password Field
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal),
            decoration: InputDecoration(
              hintText: 'Eg. : User123',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9EA3AC)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkButton, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please enter your password';
              return null;
            },
          ),

          if (authProvider.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              authProvider.errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],

          const SizedBox(height: 24),

          // "Login to Garage" Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkButton,
                foregroundColor: AppColors.warmGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: authProvider.isLoading ? null : _handleLogin,
              child: authProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warmGold),
                    )
                  : const Text(
                      'Login to Garage',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warmGold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // "Or" Separator
          const Center(
            child: Text(
              'Or',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),

          // "Don't have a garage account?"
          const Center(
            child: Text(
              "Don't have a garage account?",
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.darkCharcoal,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // "Register" Button (Outlined)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCharcoal,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.darkCharcoal, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() => _isRegisterMode = true);
              },
              child: const Text(
                'Register',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // "Contact to Admin" Link
          Center(
            child: TextButton(
              onPressed: _showContactAdminModal,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text(
                'Contact to Admin',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 13.5,
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
  // --- REGISTRATION FORM (CONSISTENT THEME) ---
  // ==========================================
  Widget _buildRegisterForm(UserAuthProvider authProvider) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circular Logo
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/AutoSpareLogo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.darkCharcoal,
                  child: const Icon(Icons.directions_car, color: AppColors.primaryGold, size: 36),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Register Header
          const Text(
            'Create Garage Account',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Register your workshop to request genuine spare parts.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),

          // Garage / Contact Name
          const Text(
            'Garage or Contact Name',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _regNameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal),
            decoration: InputDecoration(
              hintText: 'e.g. Speed Motors / Rahul',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9EA3AC)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkButton, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter garage or contact name';
              if (val.trim().length < 3) return 'Name must be at least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Mobile Number
          const Text(
            'Mobile Number',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _regPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal),
            decoration: InputDecoration(
              hintText: 'Enter 10-digit mobile number',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9EA3AC)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkButton, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter mobile number';
              if (val.trim().length != 10) return 'Must be a valid 10-digit mobile number';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          const Text(
            'Password',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _regPasswordController,
            obscureText: _obscureRegPassword,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal),
            decoration: InputDecoration(
              hintText: 'Create a password (min 4 characters)',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9EA3AC)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkButton, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please set a password';
              if (val.length < 4) return 'Password must be at least 4 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          const Text(
            'Confirm Password',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _regConfirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal),
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9EA3AC)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkButton, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val != _regPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),

          if (authProvider.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              authProvider.errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],

          const SizedBox(height: 24),

          // Register Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkButton,
                foregroundColor: AppColors.warmGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: authProvider.isLoading ? null : _handleRegistration,
              child: authProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warmGold),
                    )
                  : const Text(
                      'Register Garage Account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warmGold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // "Or" Separator
          const Center(
            child: Text(
              'Or',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),

          // "Already have a garage account?"
          const Center(
            child: Text(
              'Already have a garage account?',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.darkCharcoal,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // "Sign In" Button (Outlined)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCharcoal,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.darkCharcoal, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() => _isRegisterMode = false);
              },
              child: const Text(
                'Sign In to Existing Account',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.darkCharcoal),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Contact Admin Link
          Center(
            child: TextButton(
              onPressed: _showContactAdminModal,
              child: const Text(
                'Contact to Admin',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 13.5,
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
}
