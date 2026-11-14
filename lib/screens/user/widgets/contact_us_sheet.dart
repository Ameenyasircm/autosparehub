import 'package:flutter/material.dart';
import 'package:auto_spare_hub/utils/snackbar_helper.dart';
import 'package:flutter/services.dart';
import '../../../services/contact_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive_helper.dart';

/// Modal bottom sheet allowing users to view dynamic store contact details
/// and immediately initiate direct phone call or WhatsApp messaging intents.
class ContactUsSheet extends StatefulWidget {
  const ContactUsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: isTablet ? const BoxConstraints(maxWidth: 520) : null,
      builder: (_) => const ContactUsSheet(),
    );
  }

  @override
  State<ContactUsSheet> createState() => _ContactUsSheetState();
}

class _ContactUsSheetState extends State<ContactUsSheet> {
  final ContactService _contactService = ContactService();
  List<String> _phoneNumbers = const [ContactService.defaultPhoneNumber];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPhone();
  }

  Future<void> _fetchPhone() async {
    final phones = await _contactService.fetchContactPhones();
    if (mounted) {
      setState(() {
        _phoneNumbers = phones;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.darkHeader,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.warmGold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Contact Us',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkHeader,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'SN Auto Spare Hub • Manjeri',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // One card per store number, each with Copy, Call & WhatsApp
          for (var i = 0; i < _phoneNumbers.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildPhoneCard(
              _phoneNumbers[i],
              _phoneNumbers.length > 1 ? 'Phone / WhatsApp ${i + 1}' : 'Official Phone / WhatsApp',
            ),
          ],

          const SizedBox(height: 16),

          // Store Hours Note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.schedule_rounded, size: 14, color: AppColors.secondaryText),
              SizedBox(width: 6),
              Text(
                'Available: Monday - Saturday • 9:00 AM - 8:30 PM',
                style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPhoneCard(String phone, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _isLoading
                        ? const SizedBox(
                            width: 120,
                            height: 18,
                            child: LinearProgressIndicator(
                              color: AppColors.warmGold,
                              backgroundColor: Colors.transparent,
                            ),
                          )
                        : Text(
                            _contactService.formatForDisplay(phone),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.darkHeader,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBarAutoHide(
                    SnackBar(
                      content: Text('Copied $phone to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.copy_rounded, size: 14, color: AppColors.darkCharcoal),
                      SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: AppColors.darkCharcoal),
                  label: 'Call',
                  onTap: () => _contactService.launchPhoneCall(phone),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Image.asset(
                    'assets/member_whats_app.png',
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                  ),
                  label: 'WhatsApp',
                  onTap: () {
                    _contactService.launchWhatsApp(
                      phone,
                      'Hello SN Auto Spare Hub, I have an inquiry about automotive spare parts.',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight, width: 1.1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
