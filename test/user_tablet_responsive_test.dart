import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auto_spare_hub/models/category_model.dart';
import 'package:auto_spare_hub/models/company_model.dart';
import 'package:auto_spare_hub/models/customer_model.dart';
import 'package:auto_spare_hub/models/order_model.dart';
import 'package:auto_spare_hub/models/product_model.dart';
import 'package:auto_spare_hub/providers/cart_provider.dart';
import 'package:auto_spare_hub/providers/category_provider.dart';
import 'package:auto_spare_hub/providers/company_provider.dart';
import 'package:auto_spare_hub/providers/order_provider.dart';
import 'package:auto_spare_hub/providers/product_provider.dart';
import 'package:auto_spare_hub/providers/user_auth_provider.dart';
import 'package:auto_spare_hub/screens/user/cart_screen.dart';
import 'package:auto_spare_hub/screens/user/order_success_screen.dart';
import 'package:auto_spare_hub/screens/user/user_home_screen.dart';
import 'package:auto_spare_hub/screens/user/user_login_screen.dart';
import 'package:auto_spare_hub/screens/user/user_orders_screen.dart';
import 'package:auto_spare_hub/screens/user/user_product_detail_screen.dart';
import 'package:auto_spare_hub/screens/user/widgets/approval_pending_dialog.dart';
import 'package:auto_spare_hub/screens/user/widgets/change_password_dialog.dart';
import 'package:auto_spare_hub/screens/user/widgets/contact_us_sheet.dart';
import 'package:auto_spare_hub/screens/user/widgets/order_placement_sheet.dart';
import 'package:auto_spare_hub/services/user_session_service.dart';
import 'package:auto_spare_hub/theme/app_theme.dart';

void main() {
  const sampleCompany = CompanyModel(
    id: 'COMP_HONDA',
    name: 'Honda Heavy Motors',
    logoUrl: '',
    description: 'Genuine heavy & commercial vehicle components',
    isActive: true,
  );

  const secondCompany = CompanyModel(
    id: 'COMP_TATA',
    name: 'Tata Commercial',
    logoUrl: '',
    description: 'Truck and tipper OEM spare parts',
    isActive: true,
  );

  const sampleCategory = CategoryModel(
    id: 'CAT_BRAKE',
    name: 'Heavy Brake & Drum Assembly',
    imageUrl: '',
    companyId: 'COMP_HONDA',
    companyName: 'Honda Heavy Motors',
    isActive: true,
  );

  const secondCategory = CategoryModel(
    id: 'CAT_ENGINE',
    name: 'Engine & Filtration Systems',
    imageUrl: '',
    companyId: 'COMP_HONDA',
    companyName: 'Honda Heavy Motors',
    isActive: true,
  );

  const thirdCategory = CategoryModel(
    id: 'CAT_TATA_AXLE',
    name: 'Axle & Differential',
    imageUrl: '',
    companyId: 'COMP_TATA',
    companyName: 'Tata Commercial',
    isActive: true,
  );

  const sampleProduct1 = ProductModel(
    id: 'PRD_001',
    name: 'Heavy Duty Ceramic Brake Pad Assembly for Prima & Signa',
    imageUrl: '',
    companyId: 'COMP_HONDA',
    companyName: 'Honda Heavy Motors',
    categoryId: 'CAT_BRAKE',
    categoryName: 'Heavy Brake & Drum Assembly',
    application: 'Prima 4018 / Signa 4923 Heavy Haulage',
    refNo: 'SORL-889911',
    price: 4850.0,
    description: 'High-friction commercial ceramic brake pad kit.',
    isActive: true,
    searchKeywords: ['brake', 'pad', 'ceramic', 'honda'],
  );

  const sampleProduct2 = ProductModel(
    id: 'PRD_002',
    name: 'Primary Air & Fuel Separator Element',
    imageUrl: '',
    companyId: 'COMP_HONDA',
    companyName: 'Honda Heavy Motors',
    categoryId: 'CAT_ENGINE',
    categoryName: 'Engine & Filtration Systems',
    application: 'BS6 Multi-Axle Series',
    refNo: 'FLT-44210',
    price: 1650.0,
    isActive: true,
    searchKeywords: ['filter', 'engine', 'fuel'],
  );

  const sampleProduct3 = ProductModel(
    id: 'PRD_003',
    name: 'Heavy Duty Wheel Bearing Set',
    imageUrl: '',
    companyId: 'COMP_HONDA',
    companyName: 'Honda Heavy Motors',
    categoryId: 'CAT_BRAKE',
    categoryName: 'Heavy Brake & Drum Assembly',
    application: 'Rear Hub 10-Bolt',
    refNo: 'HUB-7712',
    price: 3100.0,
    isActive: true,
    searchKeywords: ['bearing', 'wheel', 'brake'],
  );

  final sampleOrder1 = OrderModel(
    id: 'ORD_1001',
    orderNumber: '#ORD-1001',
    userId: 'USR_919876543210',
    userName: 'Ameen Commercial Garage',
    userPhone: '9876543210',
    productId: 'PRD_001',
    productName: 'Heavy Duty Ceramic Brake Pad Assembly',
    companyName: 'Honda Heavy Motors',
    categoryName: 'Heavy Brake & Drum Assembly',
    unitPrice: 4850.0,
    quantity: 2,
    totalAmount: 9700.0,
    status: 'PENDING',
    customerNote: 'Please confirm morning dispatch availability.',
    createdAt: DateTime(2026, 11, 10, 10, 15),
  );

  final sampleOrder2 = OrderModel(
    id: 'ORD_1002',
    orderNumber: '#ORD-1002',
    userId: 'USR_919876543210',
    userName: 'Ameen Commercial Garage',
    userPhone: '9876543210',
    productId: 'PRD_002',
    productName: 'Primary Air & Fuel Separator Element',
    companyName: 'Honda Heavy Motors',
    categoryName: 'Engine & Filtration Systems',
    unitPrice: 1650.0,
    quantity: 3,
    totalAmount: 4950.0,
    status: 'CONFIRMED',
    adminRemark: 'Packed and ready for counter collection.',
    createdAt: DateTime(2026, 11, 11, 14, 45),
  );

  late CompanyProvider companyProvider;
  late CategoryProvider categoryProvider;
  late ProductProvider productProvider;
  late CartProvider cartProvider;
  late UserAuthProvider userAuthProvider;
  late OrderProvider orderProvider;

  ThemeData testTheme() => AppTheme.userTheme.copyWith(
        splashFactory: InkRipple.splashFactory,
      );

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CompanyProvider>.value(value: companyProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
        ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
        ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
        ChangeNotifierProvider<UserAuthProvider>.value(value: userAuthProvider),
        ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
      ],
      child: MaterialApp(
        theme: testTheme(),
        home: child,
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    companyProvider = CompanyProvider();
    categoryProvider = CategoryProvider();
    productProvider = ProductProvider();
    cartProvider = CartProvider();
    userAuthProvider = UserAuthProvider();
    orderProvider = OrderProvider();

    companyProvider.setCompaniesForTesting([sampleCompany, secondCompany]);
    categoryProvider.setCategoriesForTesting([
      sampleCategory,
      secondCategory,
      thirdCategory,
    ]);
    productProvider.setProductsForTesting([
      sampleProduct1,
      sampleProduct2,
      sampleProduct3,
    ]);
    orderProvider.setCustomerOrdersForTesting([sampleOrder1, sampleOrder2]);
  });

  group('UserHomeScreen Mobile vs Tablet Responsive Tests', () {
    testWidgets('renders mobile bottom navigation on phone (<720dp)', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrapWithProviders(const UserHomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // Mobile bottom bar items exist
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My Orders'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Tablet sidebar destinations are omitted on phone
      expect(find.text('Browse Parts'), findsNothing);
      expect(find.text('Account & Profile'), findsNothing);
      expect(find.text('Contact Store'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'survives compact phone (320x568) at 1.4x text scale across catalog drill-down',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: wrapWithProviders(const UserHomeScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Brands'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Level 2: Categories
        await tester.ensureVisible(find.text('Honda Heavy Motors'));
        await tester.pump();
        await tester.tap(find.text('Honda Heavy Motors'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Heavy Brake & Drum Assembly'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Level 3: Spare Part Cards
        await tester.ensureVisible(find.text('Heavy Brake & Drum Assembly'));
        await tester.pump();
        await tester.tap(find.text('Heavy Brake & Drum Assembly'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text('Heavy Duty Ceramic Brake Pad Assembly for Prima & Signa'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // Search inside Level 3 on compact 320px at 1.4x text scale
        await tester.enterText(find.byType(TextField).first, 'Separator');
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('1 Spares Found in Honda Heavy Motors'), findsOneWidget);
        expect(find.text('Primary Air & Fuel Separator Element'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch to guest Profile tab on 320x568 at 1.4x scale
        await tester.tap(find.text('Profile'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Login to Garage'), findsOneWidget);
        expect(find.text('Register New Garage'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders persistent tablet sidebar on portrait tablet (>=720dp)', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrapWithProviders(const UserHomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // Persistent tablet sidebar & branding
      expect(find.text('AutoSpare Hub'), findsOneWidget);
      expect(find.text('Garage Portal'), findsOneWidget);
      expect(find.text('Guest Garage'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('Browse Parts'), findsAtLeastNWidgets(1));
      expect(find.text('My Orders'), findsOneWidget);
      expect(find.text('Shopping Cart'), findsOneWidget);
      expect(find.text('Account & Profile'), findsOneWidget);
      expect(find.text('Contact Store'), findsOneWidget);
      expect(find.text('Login / Register'), findsOneWidget);

      // Mobile bottom nav does not render
      expect(find.text('Home'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'navigates tablet sidebar tabs and displays wide Master-Detail orders & profile cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const customer = CustomerModel(
          id: 'USR_919876543210',
          name: 'Ameen Commercial Garage',
          phoneNumber: '9876543210',
          status: 'APPROVED',
        );
        await UserSessionService().saveCustomerSession(customer);
        userAuthProvider.setCustomerForTesting(customer);

        await tester.pumpWidget(wrapWithProviders(const UserHomeScreen()));
        await tester.pump(const Duration(milliseconds: 120));

        // Logged-in customer info in sidebar
        expect(find.text('Ameen Commercial Garage'), findsWidgets);
        expect(find.text('APPROVED'), findsOneWidget);
        expect(find.text('Sign Out'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch via sidebar to My Orders -> wide tablet renders Master-Detail
        await tester.tap(find.text('My Orders').first);
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('#ORD-1001'), findsWidgets);
        expect(find.text('Ordered Spare Parts (1 items)'), findsOneWidget);
        expect(find.text('Fulfillment & Contact'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch via sidebar to Account & Profile
        await tester.tap(find.text('Account & Profile'));
        await tester.pump(const Duration(milliseconds: 120));
        expect(find.text('Verified & Approved Garage Customer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UserOrdersScreen Responsive & Master-Detail Tests', () {
    setUp(() {
      userAuthProvider.setCustomerForTesting(
        const CustomerModel(
          id: 'USR_919876543210',
          name: 'Ameen Commercial Garage',
          phoneNumber: '9876543210',
          status: 'APPROVED',
        ),
      );
    });

    testWidgets('wraps status filters without overflow on compact 320x568 at 1.4x scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: wrapWithProviders(const UserOrdersScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('#ORD-1001'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap order card to open mobile detail modal sheet at 320x568 1.4x scale
      await tester.tap(find.text('#ORD-1001'));
      await tester.pumpAndSettle();
      expect(find.text('Ordered Spare Parts (1 items)'), findsOneWidget);
      expect(find.text('Grand Total'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders wide Master-Detail split view and updates pane on order tap (1200x800)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrapWithProviders(const UserOrdersScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // First order auto-selected in detail pane
      expect(find.text('#ORD-1001'), findsNWidgets(2));
      expect(
        find.text('Note: "Please confirm morning dispatch availability."'),
        findsOneWidget,
      );

      // Select second order (#ORD-1002)
      await tester.tap(find.text('#ORD-1002').first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Admin Update / Remark:'), findsOneWidget);
      expect(find.text('Packed and ready for counter collection.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CartScreen & UserProductDetailScreen Responsive Tests', () {
    testWidgets('CartScreen empty and populated states do not overflow at 320x568 (1.4x)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Empty cart
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: wrapWithProviders(const CartScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Your Cart is Empty'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Populated cart
      await cartProvider.addToCart(sampleProduct1, quantity: 3);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Proceed to Order (3)'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CartScreen uses 2-column checkout and hides bottom nav on tablet (1024x768)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await cartProvider.addToCart(sampleProduct1, quantity: 2);
      await tester.pumpWidget(wrapWithProviders(const CartScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('My Cart (1)'), findsOneWidget);
      expect(find.text('Total Payable'), findsOneWidget);
      expect(find.text('Proceed to Order (2)'), findsOneWidget);
      expect(find.text('PRICE DETAILS'), findsOneWidget);

      // Mobile bottom navigation labels are absent on tablet
      expect(find.text('Home'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UserProductDetailScreen renders single-column on 320x568 (1.4x) and two-column on tablet', (tester) async {
      // Compact mobile
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: wrapWithProviders(const UserProductDetailScreen(product: sampleProduct1)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Product Specifications'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tablet 2-column showcase
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(
        wrapWithProviders(const UserProductDetailScreen(product: sampleProduct1)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Product Specifications'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Modal detail sheet at 320x568 (1.4x)
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: wrapWithProviders(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => UserProductDetailScreen.show(context, sampleProduct1),
                  child: const Text('Show Detail Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show Detail Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Product Specifications'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OrderSuccessScreen, Login, Modals & Dialogs Responsive Tests', () {
    testWidgets('OrderSuccessScreen renders cleanly on 320x568 (1.4x) and tablet (1024x768)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: wrapWithProviders(OrderSuccessScreen(order: sampleOrder1)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Order Request Submitted Successfully!'), findsOneWidget);
      expect(find.text('Estimated Total Amount:'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(
        wrapWithProviders(OrderSuccessScreen(order: sampleOrder1)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('View My Orders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UserLoginScreen fits cleanly on 320x568 (1.4x) and tablet (1024x768)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: wrapWithProviders(const UserLoginScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Sign In'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(
        wrapWithProviders(const UserLoginScreen(initialIsRegister: true)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Create Garage Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'ContactUsSheet, OrderPlacementSheet, ApprovalPendingDialog & ChangeUserPasswordDialog fit on 320x568 (1.4x) and tablet',
      (tester) async {
        Future<void> verifyModalsAtSize(Size size, {double textScale = 1.0}) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: MultiProvider(
                providers: [
                  ChangeNotifierProvider<UserAuthProvider>.value(value: userAuthProvider),
                  ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
                  ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
                ],
                child: MaterialApp(
                  theme: testTheme(),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: Column(
                        children: [
                          ElevatedButton(
                            onPressed: () => ContactUsSheet.show(context),
                            child: const Text('Open Contact'),
                          ),
                          ElevatedButton(
                            onPressed: () => OrderPlacementSheet.show(
                              context,
                              product: sampleProduct1,
                            ),
                            child: const Text('Open Order Sheet'),
                          ),
                          ElevatedButton(
                            onPressed: () => ApprovalPendingDialog.show(
                              context,
                              phone: '9876543210',
                            ),
                            child: const Text('Open Pending Dialog'),
                          ),
                          ElevatedButton(
                            onPressed: () => ChangeUserPasswordDialog.show(context),
                            child: const Text('Open Password Dialog'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          // 1. ContactUsSheet
          await tester.tap(find.text('Open Contact'));
          await tester.pumpAndSettle();
          expect(find.text('Contact Us'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();

          // 2. OrderPlacementSheet
          await tester.tap(find.text('Open Order Sheet'));
          await tester.pumpAndSettle();
          expect(find.text('Submit Order Request'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();

          // 3. ApprovalPendingDialog
          await tester.tap(find.text('Open Pending Dialog'));
          await tester.pumpAndSettle();
          expect(find.text('Approval Pending'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();

          // 4. ChangeUserPasswordDialog
          await tester.tap(find.text('Open Password Dialog'));
          await tester.pumpAndSettle();
          expect(find.text('Change Password'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        }

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await verifyModalsAtSize(const Size(320, 568), textScale: 1.4);
        await verifyModalsAtSize(const Size(1024, 768));
      },
    );
  });
}
