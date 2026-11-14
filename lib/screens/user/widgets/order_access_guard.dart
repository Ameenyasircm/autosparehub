import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/user_auth_provider.dart';
import '../../../theme/app_theme.dart';
import 'approval_pending_dialog.dart';

/// Final check before an order is submitted. The login is restored from the
/// phone's cache, so this asks the server whether the customer still exists
/// and is approved. Returns true only when the order may be placed; otherwise
/// shows the reason (and logs out if the account was deleted).
Future<bool> ensureOrderAccess(BuildContext context) async {
  final auth = context.read<UserAuthProvider>();
  final cart = context.read<CartProvider>();
  final orders = context.read<OrderProvider>();
  final phone = auth.currentCustomer?.phone ?? '';

  final result = await auth.verifyOrderAccess();
  if (result == OrderAccessResult.allowed) return true;
  if (!context.mounted) return false;

  switch (result) {
    case OrderAccessResult.allowed:
      return true;
    case OrderAccessResult.notApproved:
      await ApprovalPendingDialog.show(context, phone: phone);
      return false;
    case OrderAccessResult.accountRemoved:
      auth.consumeAccountRemovedNotice(); // shown here, not again on Home
      cart.onUserLogout();
      orders.clearCustomerOrders();
      await _showMessage(
        context,
        icon: Icons.person_off_outlined,
        title: 'Account Not Found',
        message: 'Your account is no longer active, so this order was not placed. '
            'You have been logged out. Please contact the store or register again.',
      );
      return false;
    case OrderAccessResult.rejected:
      await _showMessage(
        context,
        icon: Icons.block_rounded,
        title: 'Account Not Approved',
        message: 'Your account does not have access to place orders. '
            'Please contact the store for help.',
      );
      return false;
    case OrderAccessResult.notLoggedIn:
      await _showMessage(
        context,
        icon: Icons.login_rounded,
        title: 'Please Log In',
        message: 'Log in with your registered mobile number to place an order.',
      );
      return false;
    case OrderAccessResult.networkError:
      await _showMessage(
        context,
        icon: Icons.wifi_off_rounded,
        title: 'Could Not Verify Account',
        message: 'Please check your internet connection and try again. '
            'Your order has not been placed yet.',
      );
      return false;
  }
}

/// Message shown on Home when the account was deleted while the app was open.
Future<void> showAccountRemovedMessage(BuildContext context) => _showMessage(
      context,
      icon: Icons.person_off_outlined,
      title: 'Account Not Found',
      message: 'Your account is no longer active and you have been logged out. '
          'Please contact the store or register again.',
    );

Future<void> _showMessage(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Icon(icon, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.darkHeader)),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 14, height: 1.4),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK', style: TextStyle(color: AppColors.darkHeader, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}
