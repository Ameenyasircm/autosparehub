import 'package:auto_spare_hub/models/customer_model.dart';
import 'package:auto_spare_hub/models/order_model.dart';
import 'package:auto_spare_hub/providers/cart_provider.dart';
import 'package:auto_spare_hub/providers/order_provider.dart';
import 'package:auto_spare_hub/providers/user_auth_provider.dart';
import 'package:auto_spare_hub/screens/user/user_orders_screen.dart';
import 'package:auto_spare_hub/services/user_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required UserAuthProvider authProvider,
    required OrderProvider orderProvider,
    required CartProvider cartProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserAuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
        ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
      ],
      child: MaterialApp(
        theme: ThemeData(
          splashFactory: InkRipple.splashFactory,
        ),
        home: const UserOrdersScreen(),
      ),
    );
  }

  group('UserOrdersScreen Status Filter and Color Coding Tests', () {
    testWidgets('renders status filter strip with counts and color badges', (tester) async {
      final authProvider = UserAuthProvider();
      authProvider.setCustomerForTesting(const CustomerModel(
        id: 'USR001',
        name: 'Ameen',
        phone: '9876543210',
        status: 'APPROVED',
      ));

      final orderProvider = OrderProvider();
      final cartProvider = CartProvider();

      final now = DateTime.now();
      final testOrders = [
        OrderModel(
          id: 'ORD_PENDING_1',
          orderNumber: '#ORD-1001',
          userId: 'USR001',
          userName: 'Ameen',
          userPhone: '9876543210',
          productName: 'Brake Disc Rotor',
          companyName: 'Toyota',
          categoryName: 'Brakes',
          totalAmount: 1800.0,
          status: 'PENDING',
          createdAt: now,
        ),
        OrderModel(
          id: 'ORD_CONFIRMED_1',
          orderNumber: '#ORD-1002',
          userId: 'USR001',
          userName: 'Ameen',
          userPhone: '9876543210',
          productName: 'Oil Filter Standard',
          companyName: 'Honda',
          categoryName: 'Filters',
          totalAmount: 450.0,
          status: 'CONFIRMED',
          createdAt: now,
        ),
        OrderModel(
          id: 'ORD_DELIVERED_1',
          orderNumber: '#ORD-1003',
          userId: 'USR001',
          userName: 'Ameen',
          userPhone: '9876543210',
          productName: 'Spark Plug Set',
          companyName: 'Denso',
          categoryName: 'Ignition',
          totalAmount: 1200.0,
          status: 'DELIVERED',
          createdAt: now,
        ),
      ];

      orderProvider.setCustomerOrdersForTesting(testOrders);

      await tester.pumpWidget(createTestWidget(
        authProvider: authProvider,
        orderProvider: orderProvider,
        cartProvider: cartProvider,
      ));
      await tester.pumpAndSettle();

      // Verify the filter pills exist with proper labels and counts
      expect(find.text('All'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Total count
      expect(find.text('Requested'), findsWidgets);
      expect(find.text('Confirmed'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Cancelled'), findsOneWidget);
      // Dispatched should NOT be present in filter bar
      expect(find.text('Dispatched'), findsNothing);

      // Verify all 3 orders are displayed initially
      expect(find.text('#ORD-1001'), findsOneWidget);
      expect(find.text('#ORD-1002'), findsOneWidget);
      expect(find.text('#ORD-1003'), findsOneWidget);

      // Filter by 'Confirmed'
      await tester.tap(find.text('Confirmed').first);
      await tester.pumpAndSettle();

      // Only #ORD-1002 should be visible
      expect(find.text('#ORD-1001'), findsNothing);
      expect(find.text('#ORD-1002'), findsOneWidget);
      expect(find.text('#ORD-1003'), findsNothing);

      // Filter by 'Cancelled' (count is 0)
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('No Cancelled Orders'), findsOneWidget);
      expect(find.text('Show All Orders'), findsOneWidget);

      // Tap 'Show All Orders'
      await tester.tap(find.text('Show All Orders'));
      await tester.pumpAndSettle();

      // All 3 orders should be visible again
      expect(find.text('#ORD-1001'), findsOneWidget);
      expect(find.text('#ORD-1002'), findsOneWidget);
      expect(find.text('#ORD-1003'), findsOneWidget);
    });

    test('Approval Celebration: marks seen so snackbar is not repeated on app launch', () async {
      final sessionService = UserSessionService();
      const customer = CustomerModel(
        id: 'USR002',
        name: 'Auto Garage',
        phone: '9876543211',
        status: 'APPROVED',
      );

      // Initially not seen
      expect(await sessionService.hasSeenApprovalNotice('USR002'), isFalse);

      // Mark seen
      await sessionService.markApprovalNoticeSeen('USR002');
      expect(await sessionService.hasSeenApprovalNotice('USR002'), isTrue);

      // Test UserAuthProvider initSession with already approved user marks it seen
      await sessionService.saveCustomerSession(customer);
      final auth = UserAuthProvider(sessionService: sessionService);
      await auth.initSession();

      // Because user was already approved from saved session, celebration is not triggered
      expect(auth.shouldShowApprovalCelebration, isFalse);
      expect(await sessionService.hasSeenApprovalNotice('USR002'), isTrue);
    });
  });
}

