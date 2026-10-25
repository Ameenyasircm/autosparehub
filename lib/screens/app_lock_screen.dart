import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_lock_provider.dart';
import '../services/contact_service.dart';
import '../theme/app_theme.dart';

/// Full-screen Version Lock & Update Enforcement Screen.
/// Displayed when the currently installed build does not match the allowed
/// versions specified in Firebase Realtime Database (/0/ADMIN_VERSIONS or USER_VERSIONS).
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final ContactService _contactService = ContactService();

  Future<void> _handleUpdate(String url) async {
    if (url.trim().isEmpty) return;

    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
        await launchUrl(uri);
      } catch (e) {
        debugPrint('AppLockScreen: Failed to launch update URL: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockProvider = context.watch<AppLockProvider>();
    final updateUrl = lockProvider.updateAddress;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.darkHeader,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Logo Emblem with Gold Glow
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.warmGold.withValues(alpha: 0.8),
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.warmGold.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/AutoSpareLogo.jpg',
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF22262F),
                            child: const Icon(
                              Icons.settings_suggest_rounded,
                              color: AppColors.warmGold,
                              size: 44,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Brand Title
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'AUTO SPARE ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 0.6,
                            ),
                          ),
                          TextSpan(
                            text: 'HUB',
                            style: TextStyle(
                              color: AppColors.warmGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'MANJERI',
                      style: TextStyle(
                        color: AppColors.warmGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Lock Alert Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.warmGold.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Lock Icon
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF282D38),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.warmGold.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.system_security_update_rounded,
                              color: AppColors.warmGold,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'App Update Required',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),

                          const Text(
                            'This version of the application is no longer supported. Please update to the latest release to continue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFB0B7C3),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Current Version Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161920),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF2C323E)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warmGold),
                                const SizedBox(width: 6),
                                Text(
                                  'Installed: ${lockProvider.formattedVersion}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Update Button (if update URL is present)
                          if (updateUrl.isNotEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warmGold,
                                  foregroundColor: AppColors.darkHeader,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _handleUpdate(updateUrl),
                                icon: const Icon(Icons.download_rounded, size: 20),
                                label: const Text(
                                  'Update Now',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Check Again Button
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: AppColors.warmGold.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: lockProvider.isChecking
                                  ? null
                                  : () async {
                                      final allowed = await lockProvider.recheckLock();
                                      if (context.mounted && !allowed) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Update still required for this version.'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    },
                              icon: lockProvider.isChecking
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.warmGold,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(
                                lockProvider.isChecking ? 'Checking...' : 'Check Again',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Contact Helpline Action
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _contactService.launchPhoneCall(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.headset_mic_rounded, size: 15, color: AppColors.warmGold),
                            SizedBox(width: 8),
                            Text(
                              'Need help? Contact Store Support',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
          ),
        ),
      ),
    );
  }
}
