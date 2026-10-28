import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/contact_service.dart';
import '../../../theme/app_theme.dart';

/// Modal bottom sheet allowing users to view dynamic store contact details
/// and immediately initiate direct phone call or WhatsApp messaging intents.
class ContactUsSheet extends StatefulWidget {
  const ContactUsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ContactUsSheet(),
    );
  }

  @override
  State<ContactUsSheet> createState() => _ContactUsSheetState();
}

class _ContactUsSheetState extends State<ContactUsSheet> {
  final ContactService _contactService = ContactService();
  String _phoneNumber = ContactService.defaultPhoneNumber;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPhone();
  }

  Future<void> _fetchPhone() async {
    final phone = await _contactService.fetchContactPhone();
    if (mounted) {
      setState(() {
        _phoneNumber = phone;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedPhone = _contactService.formatForDisplay(_phoneNumber);

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

          // Phone Number Highlight Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Official Phone / WhatsApp',
                      style: TextStyle(
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
                            formattedPhone,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.darkHeader,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _phoneNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied $_phoneNumber to clipboard'),
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
          ),

          const SizedBox(height: 20),

          // --- ACTION BUTTON 1: DIRECT PHONE CALL ---
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkButton,
                foregroundColor: AppColors.warmGold,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                _contactService.launchPhoneCall(_phoneNumber);
              },
              icon: const Icon(Icons.phone_in_talk_rounded, color: AppColors.warmGold, size: 20),
              label: const Text(
                'Direct Phone Call',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warmGold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- ACTION BUTTON 2: WHATSAPP CHAT INTENT ---
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                _contactService.launchWhatsApp(
                  _phoneNumber,
                  'Hello SN Auto Spare Hub, I have an inquiry about automotive spare parts.',
                );
              },
              icon: Image.asset(
                'assets/member_whats_app.png',
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
              label: const Text(
                'Chat on WhatsApp',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

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
}
