import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order_model.dart';
import '../../theme/app_theme.dart';
import 'user_home_screen.dart';
import 'user_orders_screen.dart';

/// Dedicated celebratory screen shown immediately after placing a spare parts order.
/// Explicitly communicates to the customer that no payment is processed in the app
/// and that an administrator will contact them directly for order confirmation and dispatch.
class OrderSuccessScreen extends StatelessWidget {
  final OrderModel order;

  const OrderSuccessScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.darkCharcoal,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Order Confirmed',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined, color: AppColors.lightGold),
              tooltip: 'Return to Home',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const UserHomeScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- SUCCESS HERO CARD ---
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Animated Success Icon with Luxury Glow
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.35),
                            width: 2.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Order Placed Successfully!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkCharcoal,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Thank you, ${order.userName}! Your request is logged.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Order Number Badge with Copy
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: order.orderNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order number copied: ${order.orderNumber}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Order Ref: ${order.orderNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.5,
                                  color: AppColors.darkCharcoal,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: AppColors.darkCharcoal,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // --- CRITICAL DIRECT CONTACT POLICY NOTICE CARD ---
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.darkCharcoal,
                        AppColors.darkCharcoal.withValues(alpha: 0.94),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.support_agent_rounded,
                              color: AppColors.primaryGold,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Direct Administrator Confirmation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),

                      _buildInfoBullet(
                        icon: Icons.phone_callback_rounded,
                        title: 'Admin Will Contact You Directly',
                        subtitle:
                            'Our team will call or WhatsApp you directly at +91 ${order.userPhone} to confirm exact part compatibility, pricing, and fulfillment.',
                        malayalamSubtitle:
                            'ഓർഡർ സ്ഥിരീകരിക്കുന്നതിനായി ഞങ്ങളുടെ അഡ്മിൻ നിങ്ങളെ നേരിട്ട് ബന്ധപ്പെടുന്നതാണ്.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // --- ORDER ITEMS & SUMMARY ---
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 19, color: AppColors.primaryGold),
                          const SizedBox(width: 8),
                          Text(
                            'Order Summary (${order.distinctItems.length} ${order.distinctItems.length == 1 ? 'part' : 'parts'})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.dividerLight),
                      const SizedBox(height: 12),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: order.distinctItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = order.distinctItems[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  color: Colors.grey.shade100,
                                  child: item.productImage.isNotEmpty
                                      ? Image.network(
                                          item.productImage,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.car_repair,
                                                  color: AppColors.primaryGold),
                                        )
                                      : const Icon(Icons.car_repair,
                                          color: AppColors.primaryGold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${item.companyName} • Qty: ${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹ ${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1, color: AppColors.dividerLight),
                      const SizedBox(height: 12),

                      // Total Amount Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimated Total Amount:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          Text(
                            '₹ ${order.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ],
                      ),

                      if (order.shippingAddress != null &&
                          order.shippingAddress!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 16, color: AppColors.primaryGold),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Delivery Location: ${order.shippingAddress}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.darkCharcoal),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // --- ACTION BUTTONS ---
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryGold, AppColors.lightGold],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const UserOrdersScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_rounded,
                        color: AppColors.darkCharcoal),
                    label: const Text(
                      'View My Orders',
                      style: TextStyle(
                        color: AppColors.darkCharcoal,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkCharcoal,
                    side: const BorderSide(color: AppColors.borderSoft, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const UserHomeScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text(
                    'Continue Shopping',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBullet({
    required IconData icon,
    required String title,
    required String subtitle,
    String? malayalamSubtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.lightGold, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (malayalamSubtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  malayalamSubtitle,
                  style: const TextStyle(
                    color: AppColors.lightGold,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
