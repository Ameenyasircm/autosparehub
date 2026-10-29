import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_login_provider.dart';
import '../../providers/customer_management_provider.dart';
import '../../services/admin_authorization_service.dart';
import '../../services/contact_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone_helper.dart';
import '../admin_login_screen.dart';
import 'admin_management_screen.dart';
import 'categories_screen.dart';
import 'companies_screen.dart';
import 'customer_approvals_screen.dart';
import 'product_form_screen.dart';
import 'products_screen.dart';

/// Admin Menu Screen hosting all management options, approvals, catalog controls,
/// contact details settings, and admin session management.
class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  final ContactService _contactService = ContactService();
  String _activeContactPhone = ContactService.defaultPhoneNumber;
  bool _isLoadingContact = true;

  @override
  void initState() {
    super.initState();
    _loadContactPhone();
  }

  Future<void> _loadContactPhone() async {
    final phone = await _contactService.fetchContactPhone();
    if (mounted) {
      setState(() {
        _activeContactPhone = phone;
        _isLoadingContact = false;
      });
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkHeader,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your administrative session?',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await context.read<AdminLoginProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (context, anim, secAnim) => const AdminLoginScreen(),
                  transitionsBuilder: (context, anim, secAnim, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
                (route) => false,
              );
            },
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog(BuildContext context) {
    final controller = TextEditingController(text: _activeContactPhone);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.contact_phone_rounded,
                    color: Color(0xFF0D9488),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Store Contact Number',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkHeader,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This 10-digit number is displayed on the customer profile for instant calling and WhatsApp inquiries.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.warmGold, size: 20),
                    prefixText: '+91 ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.darkHeader),
                    labelText: 'Customer Helpline Phone',
                    hintText: '9048112233',
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.warmGold, width: 1.8),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkButton,
                  foregroundColor: AppColors.warmGold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final val = controller.text.trim();
                        final clean = PhoneHelper.extract10Digits(val);
                        if (clean.length != 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid 10-digit mobile number.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSaving = true);
                        final ok = await _contactService.updateContactPhone(clean);
                        if (dialogCtx.mounted) {
                          Navigator.of(dialogCtx).pop();
                        }
                        if (mounted) {
                          if (ok) {
                            setState(() => _activeContactPhone = clean);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Helpline phone updated to +91 $clean'),
                                backgroundColor: AppColors.darkHeader,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update helpline number.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warmGold),
                      )
                    : const Text('Change & Save', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = context.watch<AdminLoginProvider>().currentAdmin;
    final customerProvider = context.watch<CustomerManagementProvider>();
    final isManager = AdminAuthorizationService.canManageAdmins(currentAdmin);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildTopAppBar(context),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          physics: const BouncingScrollPhysics(),
          children: [
          // Current Admin Profile Card
          _buildAdminProfileCard(currentAdmin),

          const SizedBox(height: 20),

          // SECTION 1: ADMINISTRATION & USER APPROVALS
          _buildSectionHeader('Administration & Approvals'),
          const SizedBox(height: 8),

          _buildMenuItem(
            context: context,
            title: 'Customer Approvals',
            icon: Icons.how_to_reg_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBgColor: const Color(0xFFEEF4FF),
            badge: customerProvider.pendingCount > 0 ? '${customerProvider.pendingCount} PENDING' : null,
            badgeColor: customerProvider.pendingCount > 0 ? const Color(0xFFD97706) : null,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerApprovalsScreen()),
              );
            },
          ),

          const SizedBox(height: 10),

          _buildMenuItem(
            context: context,
            title: 'Admin Management',
            icon: Icons.admin_panel_settings_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBgColor: const Color(0xFFF3E8FF),
            badge: isManager ? 'MANAGER ACCESS' : 'LOCKED',
            badgeColor: isManager ? const Color(0xFF2E7D32) : Colors.grey.shade600,
            onTap: () {
              if (isManager) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminManagementScreen()),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Access restricted. Only Managers can manage administrators.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 22),

          // SECTION 2: CATALOG & BUSINESS MANAGEMENT
          _buildSectionHeader('Catalog & Inventory Management'),
          const SizedBox(height: 8),

          _buildMenuItem(
            context: context,
            title: 'Spare Parts & Products',
            icon: Icons.precision_manufacturing_rounded,
            iconColor: const Color(0xFFD97706),
            iconBgColor: const Color(0xFFFEF3C7),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductsScreen()),
              );
            },
          ),

          const SizedBox(height: 10),

          _buildMenuItem(
            context: context,
            title: 'Add New Product',
            icon: Icons.add_box_rounded,
            iconColor: const Color(0xFF16A34A),
            iconBgColor: const Color(0xFFDCFCE7),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              );
            },
          ),

          const SizedBox(height: 10),

          _buildMenuItem(
            context: context,
            title: 'Vehicle Brands & Companies',
            icon: Icons.business_rounded,
            iconColor: const Color(0xFF0284C7),
            iconBgColor: const Color(0xFFE0F2FE),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CompaniesScreen()),
              );
            },
          ),

          const SizedBox(height: 10),

          _buildMenuItem(
            context: context,
            title: 'Part Categories',
            icon: Icons.category_rounded,
            iconColor: const Color(0xFFEA580C),
            iconBgColor: const Color(0xFFFFEDD5),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              );
            },
          ),

          const SizedBox(height: 22),

          // SECTION 3: STORE & CUSTOMER SETTINGS
          _buildSectionHeader('Store & Support Settings'),
          const SizedBox(height: 8),

          _buildMenuItem(
            context: context,
            title: 'Customer Helpline Contact',
            icon: Icons.contact_phone_rounded,
            iconColor: const Color(0xFF0D9488),
            iconBgColor: const Color(0xFFCCFBF1),
            badge: _isLoadingContact ? '...' : _contactService.formatForDisplay(_activeContactPhone),
            badgeColor: const Color(0xFF0D9488),
            onTap: () => _showEditContactDialog(context),
          ),

          const SizedBox(height: 22),

          // SECTION 4: SESSION MANAGEMENT
          _buildSectionHeader('Account & Session'),
          const SizedBox(height: 8),

          _buildMenuItem(
            context: context,
            title: 'Sign Out',
            icon: Icons.logout_rounded,
            iconColor: AppColors.error,
            iconBgColor: const Color(0xFFFEE2E2),
            onTap: () => _showLogoutDialog(context),
          ),

          const SizedBox(height: 28),
          Center(
            child: Text(
              'SN AutoSpare Hub • Admin Operations v2.0.0',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.darkHeader,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Logo Emblem
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.warmGold.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/AutoSpareLogo.jpg',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.settings_suggest_rounded,
                  color: AppColors.warmGold,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Brand Title: "AUTO SPARE HUB" with "ADMIN MENU"
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'AUTO SPARE ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'HUB',
                      style: TextStyle(
                        color: AppColors.warmGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                'ADMIN MENU',
                style: TextStyle(
                  color: AppColors.warmGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminProfileCard(dynamic currentAdmin) {
    final String name = currentAdmin?.name ?? 'Admin';
    final String phone = currentAdmin?.phoneNumber ?? '--';
    final String role = currentAdmin?.type ?? 'STAFF';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkHeader,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF22262F),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.warmGold, width: 1.5),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.warmGold,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Phone: $phone',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warmGold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warmGold, width: 1),
            ),
            child: Text(
              role,
              style: const TextStyle(
                color: AppColors.warmGold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF5A6271),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    Color? iconColor,
    Color? iconBgColor,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    final effectiveIconColor = iconColor ?? const Color(0xFFC48618);
    final effectiveBgColor = iconBgColor ?? effectiveIconColor.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF2), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: effectiveBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(icon, color: effectiveIconColor, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.darkHeader,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.darkHeader).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (badgeColor ?? AppColors.darkHeader).withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor ?? AppColors.darkHeader,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFFB0B7C3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
