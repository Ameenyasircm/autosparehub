import 'package:flutter/material.dart';

import '../../../services/contact_service.dart';
import '../../../theme/app_theme.dart';

/// Store name, address, email and contact numbers, shown at the bottom of the
/// user home screen. The phone numbers are the ones set by the admin
/// (Store Contact Numbers); each line is tappable.
class StoreAddressCard extends StatefulWidget {
  const StoreAddressCard({super.key});

  @override
  State<StoreAddressCard> createState() => _StoreAddressCardState();
}

class _StoreAddressCardState extends State<StoreAddressCard> {
  final ContactService _contactService = ContactService();
  List<String> _phones = const [];

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
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final addressLines = [
      _buildInfoRow(
        icon: Icons.location_on_rounded,
        text: ContactService.storeAddress,
        onTap: _contactService.launchStoreLocation,
      ),
      _buildInfoRow(
        icon: Icons.email_rounded,
        text: ContactService.storeEmail,
        onTap: _contactService.launchEmail,
      ),
    ];
    final phoneLines = [
      for (final phone in _phones)
        _buildInfoRow(
          icon: Icons.phone_rounded,
          text: _contactService.formatForDisplay(phone),
          onTap: () => _contactService.launchPhoneCall(phone),
        ),
    ];

    return Container(
      key: const ValueKey('store_address_card'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.darkHeader,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warmGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.4), width: 0.8),
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.warmGold, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VISIT OUR STORE',
                      style: TextStyle(
                        color: AppColors.warmGold,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      ContactService.storeName,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 4),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: addressLines)),
                const SizedBox(width: 16),
                Expanded(child: Column(children: phoneLines)),
              ],
            )
          else
            ...addressLines,
          if (!isWide) ...phoneLines,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppColors.warmGold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
