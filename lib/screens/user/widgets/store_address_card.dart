import 'package:flutter/material.dart';

import '../../../services/contact_service.dart';
import '../../../theme/app_theme.dart';

/// Compact store details shown at the bottom of the user home screen:
/// name, address, email and the contact numbers set by the admin.
/// Each line is tappable (maps, email, call).
class StoreAddressCard extends StatefulWidget {
  const StoreAddressCard({super.key});

  @override
  State<StoreAddressCard> createState() => _StoreAddressCardState();
}

class _StoreAddressCardState extends State<StoreAddressCard> {
  final ContactService _contactService = ContactService();
  List<String> _phones = const [ContactService.defaultPhoneNumber];

  @override
  void initState() {
    super.initState();
    _loadPhones();
  }

  Future<void> _loadPhones() async {
    final phones = await _contactService.fetchContactPhones();
    if (mounted) setState(() => _phones = phones);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('store_address_card'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E9F0), width: 1.1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/AutoSpareLogo.jpg',
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.storefront_rounded, size: 22, color: AppColors.warmGold),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  ContactService.storeName,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkHeader,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _line(
            Icons.location_on_outlined,
            ContactService.storeAddress.replaceAll('\n', ' '),
            _contactService.launchStoreLocation,
          ),
          _line(Icons.mail_outline_rounded, ContactService.storeEmail, _contactService.launchEmail),
          // Phone numbers side by side; each one is its own tap target.
          Wrap(
            spacing: 14,
            children: [
              for (final phone in _phones)
                _line(
                  Icons.phone_outlined,
                  _contactService.formatForDisplay(phone),
                  () => _contactService.launchPhoneCall(phone),
                  expand: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, VoidCallback onTap, {bool expand = true}) {
    final label = Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        color: AppColors.secondaryText,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 15, color: AppColors.warmGold),
            ),
            const SizedBox(width: 8),
            if (expand) Expanded(child: label) else label,
          ],
        ),
      ),
    );
  }
}
