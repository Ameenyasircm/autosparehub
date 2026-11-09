import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auto_spare_hub/models/admin_model.dart';
import 'package:auto_spare_hub/models/category_model.dart';
import 'package:auto_spare_hub/models/customer_model.dart';
import 'package:auto_spare_hub/models/order_model.dart';
import 'package:auto_spare_hub/models/product_model.dart';
import 'package:auto_spare_hub/providers/admin_login_provider.dart';
import 'package:auto_spare_hub/providers/admin_management_provider.dart';
import 'package:auto_spare_hub/providers/category_provider.dart';
import 'package:auto_spare_hub/providers/company_provider.dart';
import 'package:auto_spare_hub/providers/customer_management_provider.dart';
import 'package:auto_spare_hub/providers/order_provider.dart';
import 'package:auto_spare_hub/providers/product_provider.dart';
import 'package:auto_spare_hub/screens/admin/admin_home_screen.dart';
import 'package:auto_spare_hub/screens/admin/admin_management_screen.dart';
import 'package:auto_spare_hub/screens/admin/admin_shell_screen.dart';
import 'package:auto_spare_hub/screens/admin/categories_screen.dart';
import 'package:auto_spare_hub/screens/admin/customer_approvals_screen.dart';
import 'package:auto_spare_hub/screens/admin/products_screen.dart';
import 'package:auto_spare_hub/utils/responsive_helper.dart';

void main() {
  group('ResponsiveHelper Breakpoint Tests', () {
    testWidgets('identifies mobile, tablet, and wide tablet sizes accurately', (tester) async {
      bool? isMobile;
      bool? isTablet;
      bool? isWideTablet;
      String? selectedValue;

      Widget buildTestWidget() {
        return MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = ResponsiveHelper.isMobile(context);
              isTablet = ResponsiveHelper.isTablet(context);
              isWideTablet = ResponsiveHelper.isWideTablet(context);
              selectedValue = ResponsiveHelper.value(
                context,
                mobile: 'phone',
                tablet: 'tab',
                wideTablet: 'desktop',
              );
              return const SizedBox();
            },
          ),
        );
      }

      // 1. Mobile screen (400 x 800)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(buildTestWidget());
      expect(isMobile, isTrue);
      expect(isTablet, isFalse);
      expect(isWideTablet, isFalse);
      expect(selectedValue, 'phone');

      // 2. Tablet portrait screen (800 x 1200)
      tester.view.physicalSize = const Size(800, 1200);
      await tester.pumpWidget(buildTestWidget());
      expect(isMobile, isFalse);
      expect(isTablet, isTrue);
      expect(isWideTablet, isFalse);
      expect(selectedValue, 'tab');

      // 3. Wide tablet / landscape workstation (1200 x 800)
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpWidget(buildTestWidget());
      expect(isMobile, isFalse);
      expect(isTablet, isTrue);
      expect(isWideTablet, isTrue);
      expect(selectedValue, 'desktop');

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('AdminShellScreen Responsive Form Factor Tests', () {
    late AdminLoginProvider adminLoginProvider;
    late AdminManagementProvider adminManagementProvider;
    late OrderProvider orderProvider;
    late CustomerManagementProvider customerProvider;
    late ProductProvider productProvider;
    late CompanyProvider companyProvider;
    late CategoryProvider categoryProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      adminLoginProvider = AdminLoginProvider();
      adminManagementProvider = AdminManagementProvider();
      orderProvider = OrderProvider();
      customerProvider = CustomerManagementProvider();
      productProvider = ProductProvider();
      companyProvider = CompanyProvider();
      categoryProvider = CategoryProvider();

      // Set logged in manager admin
      adminLoginProvider.setCurrentAdminForTesting(
        const AdminModel(
          id: 'ADM_01',
          name: 'Super Manager',
          phoneNumber: '9876543210',
          type: 'MANAGER',
          isActive: true,
        ),
      );
    });

    Widget createShellWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminLoginProvider>.value(value: adminLoginProvider),
          ChangeNotifierProvider<AdminManagementProvider>.value(value: adminManagementProvider),
          ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ChangeNotifierProvider<CustomerManagementProvider>.value(value: customerProvider),
          ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
          ChangeNotifierProvider<CompanyProvider>.value(value: companyProvider),
          ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
        ],
        child: const MaterialApp(
          home: AdminShellScreen(),
        ),
      );
    }

    testWidgets('renders mobile layout with bottom navigation on small screens (<720dp)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createShellWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Mobile Bottom Nav should exist
      expect(find.text('Orders'), findsWidgets);
      expect(find.text('Menu'), findsOneWidget);

      // Tablet Sidebar destinations should NOT exist in mobile view
      expect(find.text('Orders & Requests'), findsNothing);
      expect(find.text('Customer Approvals'), findsNothing);
      expect(find.text('Products Catalog'), findsNothing);
    });

    testWidgets('renders luxury sidebar with tablet layout on tablet screens (>=720dp)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createShellWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Tablet Sidebar should exist
      expect(find.text('Admin Console'), findsOneWidget);
      expect(find.text('Super Manager'), findsOneWidget);
      expect(find.text('MANAGER'), findsOneWidget);
      expect(find.text('Orders & Requests'), findsOneWidget);
      expect(find.text('Customer Approvals'), findsOneWidget);
      expect(find.text('Products Catalog'), findsOneWidget);
      expect(find.text('Car Companies'), findsOneWidget);
      expect(find.text('Part Categories'), findsOneWidget);
      expect(find.text('Admin Accounts'), findsOneWidget);
      expect(find.text('Store Helpline'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Mobile bottom nav should NOT be rendered
      expect(find.text('Menu'), findsNothing);
    });
  });

  group('AdminHomeScreen Tablet Master-Detail Tests', () {
    late OrderProvider orderProvider;
    late CategoryProvider categoryProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      orderProvider = OrderProvider();
      categoryProvider = CategoryProvider();

      final sampleOrder = OrderModel(
        id: 'ORD_TAB_1',
        orderNumber: '#ORD-7001',
        userId: 'USR_10',
        userName: 'Ameen Tablet User',
        userPhone: '9048112233',
        productName: 'Ceramic Brake Pads',
        companyName: 'Brembo',
        unitPrice: 3200.0,
        quantity: 2,
        totalAmount: 6400.0,
        status: 'PENDING',
        createdAt: DateTime.now(),
      );

      orderProvider.adminOrders.add(sampleOrder);
    });

    Widget createOrderScreen() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
        ],
        child: const MaterialApp(
          home: AdminHomeScreen(isTablet: true),
        ),
      );
    }

    testWidgets('renders master-detail split view on wide tablet workstation screen', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createOrderScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Master list shows order summary
      expect(find.text('#ORD-7001'), findsWidgets);
      expect(find.text('Ameen Tablet User'), findsWidgets);

      // Detail pane shows customer information and payment breakdown
      expect(find.text('Customer Information'), findsOneWidget);
      expect(find.text('Payment & Fulfillment'), findsOneWidget);
      expect(find.text('Ordered Spare Parts'), findsOneWidget);
      expect(find.text('Ceramic Brake Pads'), findsWidgets);
      expect(find.text('Change Status'), findsOneWidget);
    });
  });

  group('CustomerApprovalsScreen Tablet List View Tests', () {
    late CustomerManagementProvider customerProvider;
    late AdminLoginProvider adminLoginProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      customerProvider = CustomerManagementProvider();
      adminLoginProvider = AdminLoginProvider();

      customerProvider.setCustomersForTesting([
        CustomerModel(
          id: 'CUST_101',
          name: 'Mohammed Ameen',
          phoneNumber: '9846012345',
          status: 'PENDING',
          requestedAt: DateTime.now(),
        ),
      ]);
    });

    Widget createCustomerApprovalWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CustomerManagementProvider>.value(value: customerProvider),
          ChangeNotifierProvider<AdminLoginProvider>.value(value: adminLoginProvider),
        ],
        child: const MaterialApp(
          home: CustomerApprovalsScreen(),
        ),
      );
    }

    testWidgets('renders list view instead of grid on tablet viewports and does not overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createCustomerApprovalWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies customer details in ListView
      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(GridView), findsNothing);
      expect(find.text('Mohammed Ameen'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
    });
  });

  group('ProductsScreen Tablet Grid View Tests', () {
    late ProductProvider productProvider;
    late CompanyProvider companyProvider;
    late CategoryProvider categoryProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      productProvider = ProductProvider();
      companyProvider = CompanyProvider();
      categoryProvider = CategoryProvider();

      productProvider.setProductsForTesting([
        const ProductModel(
          id: 'PROD_TEST_1',
          name: 'Heavy Duty Premium Brake Shoes Assembly',
          imageUrl: '',
          companyId: 'COMP_1',
          companyName: 'Brembo Systems',
          categoryId: 'CAT_1',
          categoryName: 'Brake Parts',
          application: 'Tata Prima / Signa 4018 Heavy Haulage',
          refNo: 'SORL-998811',
          price: 4850.0,
          stockQuantity: 12,
          isActive: true,
          searchKeywords: ['brake', 'shoes', 'brembo'],
        ),
      ]);
    });

    Widget createProductsScreen({bool embedded = false}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
          ChangeNotifierProvider<CompanyProvider>.value(value: companyProvider),
          ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
        ],
        child: MaterialApp(
          home: ProductsScreen(embedded: embedded),
        ),
      );
    }

    testWidgets('renders products grid on tablet viewport without vertical RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createProductsScreen(embedded: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies product rendered properly without bottom overflow
      expect(find.text('Heavy Duty Premium Brake Shoes Assembly'), findsOneWidget);
      expect(find.text('BREMBO SYSTEMS • BRAKE PARTS'), findsOneWidget);
      expect(find.text('App: Tata Prima / Signa 4018 Heavy Haulage'), findsOneWidget);
      expect(find.text('Sorl: SORL-998811'), findsOneWidget);
      expect(find.text('₹ 4850.00'), findsOneWidget);
    });
  });

  group('AdminManagementScreen Tablet List View Tests', () {
    late AdminManagementProvider adminManagementProvider;
    late AdminLoginProvider adminLoginProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      adminManagementProvider = AdminManagementProvider();
      adminLoginProvider = AdminLoginProvider();

      adminLoginProvider.setCurrentAdminForTesting(
        const AdminModel(
          id: 'ADM_01',
          name: 'Super Manager',
          phoneNumber: '9876543210',
          type: 'MANAGER',
          isActive: true,
        ),
      );

      adminManagementProvider.setAdminsForTesting([
        const AdminModel(
          id: 'ADM_01',
          name: 'Super Manager',
          phoneNumber: '9876543210',
          type: 'MANAGER',
          isActive: true,
        ),
        const AdminModel(
          id: 'ADM_02',
          name: 'Counter Staff Executive',
          phoneNumber: '9123456780',
          type: 'STAFF',
          isActive: true,
        ),
      ]);
    });

    Widget createAdminManagementScreen({bool embedded = false}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminManagementProvider>.value(value: adminManagementProvider),
          ChangeNotifierProvider<AdminLoginProvider>.value(value: adminLoginProvider),
        ],
        child: MaterialApp(
          home: AdminManagementScreen(embedded: embedded),
        ),
      );
    }

    testWidgets('renders list view instead of grid on tablet viewports and does not overflow badges', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createAdminManagementScreen(embedded: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies list view is used on tablet
      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(GridView), findsNothing);

      // Verifies admin cards render cleanly without overflow
      expect(find.text('Super Manager'), findsOneWidget);
      expect(find.text('Counter Staff Executive'), findsOneWidget);
      expect(find.text('MANAGER'), findsOneWidget);
      expect(find.text('STAFF'), findsOneWidget);
      expect(find.text('Active'), findsNWidgets(2));
    });
  });

  group('CategoriesScreen Tablet List View Tests', () {
    late CategoryProvider categoryProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      categoryProvider = CategoryProvider();

      categoryProvider.setCategoriesForTesting([
        const CategoryModel(
          id: 'CAT_TEST_1',
          name: 'Heavy Duty Clutch Systems',
          imageUrl: '',
          description: 'Clutch plates, pressure plates, and release bearings',
          isActive: true,
        ),
      ]);
    });

    Widget createCategoriesScreen({bool embedded = false}) {
      return ChangeNotifierProvider<CategoryProvider>.value(
        value: categoryProvider,
        child: MaterialApp(
          home: CategoriesScreen(embedded: embedded),
        ),
      );
    }

    testWidgets('renders list view instead of grid on tablet viewports and renders cleanly', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createCategoriesScreen(embedded: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies list view is used on tablet
      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(GridView), findsNothing);

      // Verifies category card details
      expect(find.text('Heavy Duty Clutch Systems'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });
  });
}
