import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_login_provider.dart';
import '../theme/app_theme.dart';
import 'admin/admin_shell_screen.dart';

/// Redesigned Admin Login Screen matching the modern brand identity:
/// Dark obsidian accents, warm gold highlights, circular emblem, and crisp form controls.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<AdminLoginProvider>();
    provider.clearError();

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final success = await provider.login(
      usernameOrPhone: username,
      password: password,
    );

    if (success && mounted) {
      _passwordController.clear();

      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AdminShellScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminLoginProvider>();
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- BRAND HEADER SECTION ---
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.warmGold.withValues(alpha: 0.6),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.warmGold.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/AutoSpareLogo.jpg',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.darkHeader,
                            child: const Icon(
                              Icons.settings_suggest_rounded,
                              color: AppColors.warmGold,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

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

                  // Pill Badge: "ADMIN PORTAL • MANJERI"
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.darkButton,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warmGold.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'ADMIN PORTAL • MANJERI',
                        style: TextStyle(
                          color: AppColors.warmGold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Heading Text


                  // --- LOGIN FORM CARD ---
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card Header Badge
                          const Divider(height: 1, color: Color(0xFFECEFF3)),
                          const SizedBox(height: 18),

                          // Error Banner
                          if (provider.errorMessage != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
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
                                      provider.errorMessage!,
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
                            ),
                          ],

                          // Username / Phone Field
                          const Text(
                            'Username or Mobile Number',
                            style: TextStyle(
                              color: AppColors.darkHeader,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _usernameController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            enabled: !provider.isLoading,
                            onChanged: (_) => provider.clearError(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkHeader,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter username or phone number';
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
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            enabled: !provider.isLoading,
                            onFieldSubmitted: (_) => _handleLogin(),
                            onChanged: (_) => provider.clearError(),
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
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF8C95A6),
                                  size: 20,
                                ),
                                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                onPressed: _togglePasswordVisibility,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Submit Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: provider.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.darkButton,
                                foregroundColor: AppColors.warmGold,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: provider.isLoading
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppColors.warmGold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Verifying Credentials...',
                                          style: TextStyle(
                                            color: AppColors.warmGold,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login_rounded, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Sign In to Admin Portal',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Automotive Security Note

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
