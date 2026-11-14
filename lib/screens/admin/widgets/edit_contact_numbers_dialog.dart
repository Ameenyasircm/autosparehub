import 'package:flutter/material.dart';

import '../../../services/contact_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/phone_helper.dart';

/// Opens the dialog where an admin edits the store contact numbers shown to
/// customers. The first number is required, the second is optional.
///
/// Returns the saved numbers (primary first), or null if nothing was saved.
Future<List<String>?> showEditContactNumbersDialog(
  BuildContext context, {
  required ContactService contactService,
  required List<String> currentPhones,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _EditContactNumbersDialog(
      contactService: contactService,
      currentPhones: currentPhones,
    ),
  );
}

/// Joins contact numbers for display, e.g. "90481 12233 / 98765 43210".
String formatContactPhones(List<String> phones, {String separator = ' / '}) =>
    phones.map(PhoneHelper.formatForDisplay).join(separator);

class _EditContactNumbersDialog extends StatefulWidget {
  final ContactService contactService;
  final List<String> currentPhones;

  const _EditContactNumbersDialog({
    required this.contactService,
    required this.currentPhones,
  });

  @override
  State<_EditContactNumbersDialog> createState() => _EditContactNumbersDialogState();
}

class _EditContactNumbersDialogState extends State<_EditContactNumbersDialog> {
  late final TextEditingController _primaryController;
  late final TextEditingController _secondaryController;
  bool _isSaving = false;
  String? _primaryError;
  String? _secondaryError;

  @override
  void initState() {
    super.initState();
    final phones = widget.currentPhones;
    _primaryController = TextEditingController(text: phones.isNotEmpty ? phones[0] : '');
    _secondaryController = TextEditingController(text: phones.length > 1 ? phones[1] : '');
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final primary = PhoneHelper.extract10Digits(_primaryController.text.trim());
    final secondary = PhoneHelper.extract10Digits(_secondaryController.text.trim());

    setState(() {
      _primaryError = primary.length == 10 ? null : 'Enter a valid 10-digit mobile number';
      _secondaryError = secondary.isEmpty || secondary.length == 10
          ? (secondary.isNotEmpty && secondary == primary ? 'Same as the first number' : null)
          : 'Enter a valid 10-digit mobile number';
    });
    if (_primaryError != null || _secondaryError != null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    final ok = await widget.contactService.updateContactPhones(primary, secondary);
    if (!mounted) return;

    if (ok) {
      final saved = [primary, if (secondary.isNotEmpty) secondary];
      Navigator.of(context).pop(saved);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Helpline updated: ${formatContactPhones(saved)}'),
          backgroundColor: AppColors.darkHeader,
        ),
      );
    } else {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to update helpline numbers.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.contact_phone_rounded, color: Color(0xFF0D9488), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Store Contact Numbers',
              style: TextStyle(
                fontSize: 16.5,
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
            const Text(
              'These numbers are shown to customers for calling and WhatsApp inquiries.',
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText, height: 1.4),
            ),
            const SizedBox(height: 14),
            _buildPhoneField(
              controller: _primaryController,
              label: 'Contact Number 1',
              errorText: _primaryError,
            ),
            const SizedBox(height: 12),
            _buildPhoneField(
              controller: _secondaryController,
              label: 'Contact Number 2 (optional)',
              errorText: _secondaryError,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warmGold),
                )
              : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildPhoneField({
    required TextEditingController controller,
    required String label,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isSaving,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.warmGold, size: 20),
        labelText: label,
        hintText: '9048112233',
        errorText: errorText,
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
    );
  }
}
