import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/contact_service.dart';
import '../../../theme/app_theme.dart';

/// Modal dialog showing the Approval Pending state for newly registered or
/// awaiting-authorization garage accounts with English/Malayalam guidance
/// and dynamic admin phone contact with Call and WhatsApp intents from Firestore.
class ApprovalPendingDialog {
  static Future<void> show(
    BuildContext context, {
    required String phone,
    String? dateStr,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ApprovalPendingDialogWidget(
        phone: phone,
        dateStr: dateStr,
      ),
    );
  }
}

class _ApprovalPendingDialogWidget extends StatefulWidget {
  final String phone;
  final String? dateStr;

  const _ApprovalPendingDialogWidget({
    required this.phone,
    this.dateStr,
  });

  @override
  State<_ApprovalPendingDialogWidget> createState() =>
      _ApprovalPendingDialogWidgetState();
}

class _ApprovalPendingDialogWidgetState
    extends State<_ApprovalPendingDialogWidget> {
  final ContactService _contactService = ContactService();
  String _adminPhone = ContactService.defaultPhoneNumber;
  bool _isLoadingContact = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminPhone();
  }

  Future<void> _fetchAdminPhone() async {
    final phone = await _contactService.fetchContactPhone();
    if (mounted) {
      setState(() {
        _adminPhone = phone;
        _isLoadingContact = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanPhone = widget.phone.replaceAll(RegExp(r'\D'), '');
    final displayPhone = cleanPhone.length > 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;

    final formattedAdminPhone = _contactService.formatForDisplay(_adminPhone);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(
        children: const [
          Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Approval Pending',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.darkHeader,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (displayPhone.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E9F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_android_rounded, size: 14, color: AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      'Your Mobile: +91 $displayPhone',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            const Text(
              'Your garage account registration has been submitted and is currently waiting for administrator authorization. Once approved, you can log in and place orders directly.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.darkCharcoal,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),

            // Malayalam explanation box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'നിങ്ങളുടെ രജിസ്ട്രേഷൻ അഡ്മിൻ പരിശോധിച്ചുകൊണ്ടിരിക്കുകയാണ്. പരിശോധന പൂർത്തിയാക്കിയ ശേഷം അഡ്മിൻ നിങ്ങളെ നേരിട്ട് ബന്ധപ്പെടുന്നതാണ്. ദയവായി കാത്തിരിക്കുക!',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.darkCharcoal,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Admin Contact section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E9F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.warmGold),
                      const SizedBox(width: 6),
                      const Text(
                        'Admin Helpline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkHeader,
                        ),
                      ),
                      const Spacer(),
                      if (!_isLoadingContact)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _adminPhone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied $_adminPhone to clipboard'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Row(
                            children: const [
                              Icon(Icons.copy_rounded, size: 12, color: AppColors.secondaryText),
                              SizedBox(width: 3),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLoadingContact ? 'Loading contact info...' : formattedAdminPhone,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkHeader,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Call & WhatsApp Action Buttons
                  Row(
                    children: [
                      // Direct Call Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkButton,
                            foregroundColor: AppColors.warmGold,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            _contactService.launchPhoneCall(_adminPhone);
                          },
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: AppColors.warmGold),
                          label: const Text(
                            'Call',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // WhatsApp Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            final msg = displayPhone.isNotEmpty
                                ? 'Hello Admin, I have registered my garage account (+91 $displayPhone) on Auto Spare Hub and am awaiting approval.'
                                : 'Hello Admin, I have registered my garage account on Auto Spare Hub and am awaiting approval.';
                            _contactService.launchWhatsApp(_adminPhone, msg);
                          },
                          icon: Image.asset(
                            'assets/member_whats_app.png',
                            width: 18,
                            height: 18,
                            fit: BoxFit.contain,
                          ),
                          label: const Text(
                            'WhatsApp',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Ok',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
            ),
          ),
        ),
      ],
    );
  }
}
