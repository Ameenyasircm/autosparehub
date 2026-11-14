import 'package:flutter/material.dart';
import 'package:auto_spare_hub/utils/snackbar_helper.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_auth_provider.dart';
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
  List<String> _adminPhones = const [ContactService.defaultPhoneNumber];
  bool _isLoadingContact = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminPhone();
  }

  Future<void> _fetchAdminPhone() async {
    final phones = await _contactService.fetchContactPhones();
    if (mounted) {
      setState(() {
        _adminPhones = phones;
        _isLoadingContact = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safely listen to live customer authorization state without throwing if provider absent in tests
    UserAuthProvider? auth;
    try {
      auth = Provider.of<UserAuthProvider>(context, listen: true);
    } catch (_) {}
    final bool isApproved = auth?.isApproved ?? false;

    // LIVE STATE TRANSFORMATION: If admin approved while dialog is open, transform into celebration state immediately
    if (isApproved) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Account Approved! 🎉',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkHeader,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Text(
                    'Great news! Your garage account registration has just been approved by the administrator. You now have full access to browse and place spare part orders.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF14532D),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'നിങ്ങളുടെ അക്കൗണ്ടിന് അഡ്മിൻ അനുമതി നൽകിയിരിക്കുന്നു! നിങ്ങൾക്ക് ഇപ്പോൾ ഓർഡറുകൾ നൽകാം.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF166534),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkButton,
              foregroundColor: AppColors.warmGold,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Start Shopping',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
        ],
      );
    }

    final cleanPhone = widget.phone.replaceAll(RegExp(r'\D'), '');
    final displayPhone = cleanPhone.length > 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;

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
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
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
                      Flexible(
                        child: Text(
                          'Your Mobile: $displayPhone',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.darkCharcoal,
                          ),
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
                      const Expanded(
                        child: Text(
                          'Admin Helpline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkHeader,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < _adminPhones.length; i++) ...[
                    if (i > 0) const Divider(height: 22, color: Color(0xFFE5E9F0)),
                    _buildHelplineNumber(_adminPhones[i], displayPhone),
                  ],
                ],
              ),
            ),
          ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 16),
      actions: [
        // Small, simple pill button.
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warmGold,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
            shape: const StadiumBorder(),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'OK',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ],
    );
  }

  /// One helpline number with Copy, Call and WhatsApp actions.
  Widget _buildHelplineNumber(String phone, String displayPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isLoadingContact ? 'Loading contact info...' : _contactService.formatForDisplay(phone),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkHeader,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (!_isLoadingContact)
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  _contactService.launchPhoneCall(phone);
                },
                icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: AppColors.warmGold),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Call',
                    maxLines: 1,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  final msg = displayPhone.isNotEmpty
                      ? 'Hello Admin, I have registered my garage account ($displayPhone) on Auto Spare Hub and am awaiting approval.'
                      : 'Hello Admin, I have registered my garage account on Auto Spare Hub and am awaiting approval.';
                  _contactService.launchWhatsApp(phone, msg);
                },
                icon: Image.asset(
                  'assets/member_whats_app.png',
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                ),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'WhatsApp',
                    maxLines: 1,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
