import 'package:auto_spare_hub/models/order_model.dart';
import 'package:auto_spare_hub/models/product_model.dart';
import 'package:auto_spare_hub/providers/cart_provider.dart';
import 'package:auto_spare_hub/providers/user_auth_provider.dart';
import 'package:auto_spare_hub/screens/user/order_success_screen.dart';
import 'package:auto_spare_hub/screens/user/user_login_screen.dart';
import 'package:auto_spare_hub/screens/user/widgets/approval_pending_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApprovalPendingDialog Tests', () {
    testWidgets('renders Approval Pending alert with phone and Malayalam notice', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => ApprovalPendingDialog.show(
                  context,
                  phone: '9876543210',
                ),
                child: const Text('Show Alert'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Alert'));
      await tester.pumpAndSettle();

      expect(find.text('Approval Pending'), findsOneWidget);
      expect(find.text('Your Mobile: +91 9876543210'), findsOneWidget);
      expect(find.textContaining('waiting for administrator authorization'), findsOneWidget);
      expect(find.textContaining('നിങ്ങളുടെ രജിസ്ട്രേഷൻ അഡ്മിൻ പരിശോധിച്ചുകൊണ്ടിരിക്കുകയാണ്'), findsOneWidget);
      expect(find.text('Admin Helpline'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Ok'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(find.text('Approval Pending'), findsNothing);
    });

    testWidgets('ApprovalPendingDialog formats 10 digit phone cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => ApprovalPendingDialog.show(
                  context,
                  phone: '+91 9876543210',
                ),
                child: const Text('Show Alert'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Alert'));
      await tester.pumpAndSettle();

      expect(find.text('Your Mobile: +91 9876543210'), findsOneWidget);
    });
  });

  group('UserLoginScreen Form Switching Tests', () {
    testWidgets('switches to register mode when Register button is pressed', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserAuthProvider>(create: (_) => UserAuthProvider()),
            ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ],
          child: const MaterialApp(
            home: UserLoginScreen(),
          ),
        ),
      );

      // Verify initially in login mode
      final crossFadeBefore = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(crossFadeBefore.crossFadeState, CrossFadeState.showFirst);

      // Tap Register button
      final registerSwitchBtn = find.widgetWithText(OutlinedButton, 'Register');
      expect(registerSwitchBtn, findsOneWidget);
      await tester.ensureVisible(registerSwitchBtn);
      await tester.tap(registerSwitchBtn);
      await tester.pumpAndSettle();

      // Now on registration mode
      final crossFadeAfter = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(crossFadeAfter.crossFadeState, CrossFadeState.showSecond);
    });

    testWidgets('starts in registration mode when initialIsRegister is true', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserAuthProvider>(create: (_) => UserAuthProvider()),
            ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ],
          child: const MaterialApp(
            home: UserLoginScreen(initialIsRegister: true),
          ),
        ),
      );

      final crossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(crossFade.crossFadeState, CrossFadeState.showSecond);
    });
  });

  group('OrderSuccessScreen Cart Clear Tests', () {
    testWidgets('clears cart when navigating from OrderSuccessScreen with fromCart: true', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();

      final sampleProduct = ProductModel(
        id: 'PRD_CART_01',
        name: 'Oil Filter',
        companyId: 'CMP_01',
        companyName: 'Toyota',
        categoryId: 'CAT_01',
        categoryName: 'Filters',
        application: 'Toyota Corolla 2015-2020',
        imageUrl: 'https://img.com/filter.jpg',
        price: 500.0,
        isActive: true,
      );
      await cart.addToCart(sampleProduct, quantity: 2);
      expect(cart.items.length, 1);
      expect(cart.totalItemCount, 2);

      final dummyOrder = OrderModel(
        id: 'ORD_9999',
        orderNumber: '#ORD-9999',
        userId: 'USR_TEST',
        userName: 'Garage User',
        userPhone: '9876543210',
        productId: 'PRD_CART_01',
        productName: 'Oil Filter',
        unitPrice: 500.0,
        quantity: 2,
        totalAmount: 1000.0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CartProvider>.value(value: cart),
          ],
          child: MaterialApp(
            home: OrderSuccessScreen(
              order: dummyOrder,
              fromCart: true,
              onContinueShopping: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Verify Continue Shopping button is present
      expect(find.text('Continue Shopping'), findsOneWidget);

      // Tapping Continue Shopping ensures the cart is cleared
      await tester.tap(find.text('Continue Shopping'));
      await tester.pump();

      expect(cart.isEmpty, isTrue);
      expect(cart.totalItemCount, 0);
    });
  });
}
