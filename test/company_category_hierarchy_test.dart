import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auto_spare_hub/models/category_model.dart';
import 'package:auto_spare_hub/models/company_model.dart';
import 'package:auto_spare_hub/models/product_model.dart';
import 'package:auto_spare_hub/providers/cart_provider.dart';
import 'package:auto_spare_hub/providers/category_provider.dart';
import 'package:auto_spare_hub/providers/company_provider.dart';
import 'package:auto_spare_hub/providers/order_provider.dart';
import 'package:auto_spare_hub/providers/product_provider.dart';
import 'package:auto_spare_hub/providers/user_auth_provider.dart';
import 'package:auto_spare_hub/screens/admin/categories_screen.dart';
import 'package:auto_spare_hub/screens/admin/category_form_screen.dart';
import 'package:auto_spare_hub/screens/admin/companies_screen.dart';
import 'package:auto_spare_hub/screens/admin/product_form_screen.dart';
import 'package:auto_spare_hub/screens/user/user_home_screen.dart';
import 'package:auto_spare_hub/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Admin Company -> Category Hierarchy Tests', () {
    late CompanyProvider companyProvider;
    late CategoryProvider categoryProvider;
    late ProductProvider productProvider;

    const honda = CompanyModel(
      id: 'COMP_HONDA',
      name: 'Honda',
      logoUrl: '',
      description: 'Honda Motors',
      isActive: true,
    );
    const toyota = CompanyModel(
      id: 'COMP_TOYOTA',
      name: 'Toyota',
      logoUrl: '',
      description: 'Toyota Genuine Parts',
      isActive: true,
    );

    const hondaEngine = CategoryModel(
      id: 'CAT_H_ENG',
      name: 'Engine Parts',
      imageUrl: '',
      companyId: 'COMP_HONDA',
      companyName: 'Honda',
      isActive: true,
    );
    const hondaBrake = CategoryModel(
      id: 'CAT_H_BRK',
      name: 'Brake System',
      imageUrl: '',
      companyId: 'COMP_HONDA',
      companyName: 'Honda',
      isActive: true,
    );
    const toyotaEngine = CategoryModel(
      id: 'CAT_T_ENG',
      name: 'Engine Parts',
      imageUrl: '',
      companyId: 'COMP_TOYOTA',
      companyName: 'Toyota',
      isActive: true,
    );
    const legacyUnassigned = CategoryModel(
      id: 'CAT_LEGACY',
      name: 'Legacy Belts',
      imageUrl: '',
      isActive: true,
    );

    setUp(() {
      companyProvider = CompanyProvider();
      categoryProvider = CategoryProvider();
      productProvider = ProductProvider();

      companyProvider.setCompaniesForTesting([honda, toyota]);
      categoryProvider.setCategoriesForTesting([
        hondaEngine,
        hondaBrake,
        toyotaEngine,
        legacyUnassigned,
      ]);
      productProvider.setProductsForTesting([]);
    });

    Widget wrapAdmin(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CompanyProvider>.value(value: companyProvider),
          ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
          ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.adminTheme,
          home: child,
        ),
      );
    }

    testWidgets('CategoryFormScreen requires company selection and honors initialCompanyId',
        (tester) async {
      await tester.pumpWidget(wrapAdmin(const CategoryFormScreen()));
      await tester.pump();

      expect(find.text('Select brand'), findsOneWidget);

      await tester.ensureVisible(find.text('Save Category'));
      await tester.tap(find.text('Save Category'));
      await tester.pump();

      expect(find.text('Please select a brand'), findsOneWidget);
      expect(find.text('Category name is required'), findsOneWidget);

      // Mount a fresh CategoryFormScreen pre-selected from a company's category list
      await tester.pumpWidget(wrapAdmin(const CategoryFormScreen(
        key: ValueKey('initial-toyota'),
        initialCompanyId: 'COMP_TOYOTA',
        initialCompanyName: 'Toyota',
      )));
      await tester.pump();

      expect(find.text('Toyota'), findsOneWidget);
      expect(find.text('Select brand'), findsNothing);
    });

    testWidgets('CategoriesScreen filters by company, flags unassigned, and drills from CompaniesScreen',
        (tester) async {
      await tester.pumpWidget(wrapAdmin(const CategoriesScreen()));
      await tester.pump();

      // Unassigned banner + all categories visible initially
      expect(find.text('Unassigned (1)'), findsOneWidget);
      expect(find.text('Unassigned — Tap to set brand'), findsOneWidget);
      expect(find.text('Engine Parts'), findsNWidgets(2));
      expect(find.text('Brake System'), findsOneWidget);
      expect(find.text('Legacy Belts'), findsOneWidget);

      // Filter to Toyota
      await tester.tap(find.text('Toyota').first);
      await tester.pump();

      expect(find.text('Engine Parts'), findsOneWidget);
      expect(find.text('Brake System'), findsNothing);
      expect(find.text('Legacy Belts'), findsNothing);

      // Filter to Unassigned & tap to open Edit Category form to map company
      await tester.tap(find.text('Unassigned (1)'));
      await tester.pump();

      expect(find.text('Legacy Belts'), findsOneWidget);
      expect(find.text('Engine Parts'), findsNothing);

      await tester.tap(find.text('Legacy Belts'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Category'), findsOneWidget);
      expect(find.text('Legacy Belts'), findsOneWidget);
      expect(
        find.text(
          'This existing category is not mapped to a brand yet. Select the brand it belongs to and tap Update Category.',
        ),
        findsOneWidget,
      );
      expect(find.text('Select brand'), findsOneWidget);
      expect(find.text('Update Category'), findsOneWidget);
    });

    testWidgets('CompaniesScreen displays category count and navigates to company categories',
        (tester) async {
      await tester.pumpWidget(wrapAdmin(const CompaniesScreen()));
      await tester.pump();

      expect(find.text('2 Categories'), findsOneWidget);
      expect(find.text('1 Category'), findsOneWidget);

      await tester.tap(find.text('Honda'));
      await tester.pumpAndSettle();

      expect(find.text('Honda Categories'), findsOneWidget);
      expect(find.text('Engine Parts'), findsOneWidget);
      expect(find.text('Brake System'), findsOneWidget);
      expect(find.text('Legacy Belts'), findsNothing);
    });

    testWidgets('ProductFormScreen filters categories by selected brand and resets on brand change',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrapAdmin(const ProductFormScreen()));
      await tester.pump();

      // Category selector disabled before brand selection
      expect(find.text('Select brand first'), findsOneWidget);

      // Select Honda brand
      final brandDropdown = find.byType(DropdownButtonFormField<String>).at(0);
      final categoryDropdown = find.byType(DropdownButtonFormField<String>).at(1);
      await tester.ensureVisible(brandDropdown);
      await tester.tap(brandDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Honda').last);
      await tester.pumpAndSettle();

      // Open category dropdown -> sees only Honda categories
      await tester.ensureVisible(categoryDropdown);
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();
      expect(find.text('Brake System'), findsWidgets);
      expect(find.text('Legacy Belts'), findsNothing);

      // Pick Brake System
      await tester.tap(find.text('Brake System').last);
      await tester.pumpAndSettle();
      expect(find.text('Brake System'), findsOneWidget);

      // Switch Brand to Toyota -> Brake System doesn't belong to Toyota, so it resets
      await tester.ensureVisible(brandDropdown);
      await tester.tap(brandDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toyota').last);
      await tester.pumpAndSettle();

      expect(find.text('Brake System'), findsNothing);
      expect(find.text('Select category'), findsOneWidget);
    });
  });

  group('UserHomeScreen Company -> Category -> Items Flow Tests', () {
    late CompanyProvider companyProvider;
    late CategoryProvider categoryProvider;
    late ProductProvider productProvider;
    late CartProvider cartProvider;
    late UserAuthProvider userAuthProvider;
    late OrderProvider orderProvider;

    const honda = CompanyModel(
      id: 'COMP_HONDA',
      name: 'Honda',
      logoUrl: '',
      isActive: true,
    );
    const toyota = CompanyModel(
      id: 'COMP_TOYOTA',
      name: 'Toyota',
      logoUrl: '',
      isActive: true,
    );
    const emptyCompany = CompanyModel(
      id: 'COMP_TATA',
      name: 'Tata',
      logoUrl: '',
      isActive: true,
    );
    const hiddenCompany = CompanyModel(
      id: 'COMP_HIDDEN',
      name: 'Hidden Brand',
      logoUrl: '',
      isActive: false,
    );

    const hondaEngine = CategoryModel(
      id: 'CAT_H_ENG',
      name: 'Engine Parts',
      imageUrl: '',
      companyId: 'COMP_HONDA',
      companyName: 'Honda',
      isActive: true,
    );
    const hondaBrake = CategoryModel(
      id: 'CAT_H_BRK',
      name: 'Brake System',
      imageUrl: '',
      companyId: 'COMP_HONDA',
      companyName: 'Honda',
      isActive: true,
    );
    const hondaEmptyCat = CategoryModel(
      id: 'CAT_H_EMPTY',
      name: 'Air Conditioning',
      imageUrl: '',
      companyId: 'COMP_HONDA',
      companyName: 'Honda',
      isActive: true,
    );
    const hondaHiddenCat = CategoryModel(
      id: 'CAT_H_HIDE',
      name: 'Hidden Honda Cat',
      imageUrl: '',
      companyId: 'COMP_HONDA',
      companyName: 'Honda',
      isActive: false,
    );
    const toyotaSuspension = CategoryModel(
      id: 'CAT_T_SUSP',
      name: 'Suspension',
      imageUrl: '',
      companyId: 'COMP_TOYOTA',
      companyName: 'Toyota',
      isActive: true,
    );

    const prodHondaBelt = ProductModel(
      id: 'P_H_1',
      name: 'Honda Timing Belt',
      imageUrl: '',
      companyId: 'COMP_HONDA',
      companyName: 'Honda',
      categoryId: 'CAT_H_ENG',
      categoryName: 'Engine Parts',
      application: 'City i-VTEC',
      refNo: 'HND-TB-01',
      price: 1200,
      isActive: true,
      searchKeywords: ['honda', 'timing', 'belt', 'engine'],
    );
    const prodHondaPad = ProductModel(
      id: 'P_H_2',
      name: 'Honda Ceramic Pads',
      imageUrl: '',
      companyId: 'COMP_HONDA',
      companyName: 'Honda',
      categoryId: 'CAT_H_BRK',
      categoryName: 'Brake System',
      application: 'Civic',
      refNo: 'HND-BRK-02',
      price: 2100,
      isActive: true,
      searchKeywords: ['honda', 'ceramic', 'pads', 'brake'],
    );
    const prodToyotaShock = ProductModel(
      id: 'P_T_1',
      name: 'Toyota Shock Absorber',
      imageUrl: '',
      companyId: 'COMP_TOYOTA',
      companyName: 'Toyota',
      categoryId: 'CAT_T_SUSP',
      categoryName: 'Suspension',
      application: 'Innova',
      refNo: 'TYT-SUS-01',
      price: 3400,
      isActive: true,
      searchKeywords: ['toyota', 'shock', 'absorber', 'suspension'],
    );

    setUp(() {
      companyProvider = CompanyProvider();
      categoryProvider = CategoryProvider();
      productProvider = ProductProvider();
      cartProvider = CartProvider();
      userAuthProvider = UserAuthProvider();
      orderProvider = OrderProvider();

      companyProvider.setCompaniesForTesting([
        honda,
        toyota,
        emptyCompany,
        hiddenCompany,
      ]);
      categoryProvider.setCategoriesForTesting([
        hondaEngine,
        hondaBrake,
        hondaEmptyCat,
        hondaHiddenCat,
        toyotaSuspension,
      ]);
      productProvider.setProductsForTesting([
        prodHondaBelt,
        prodHondaPad,
        prodToyotaShock,
      ]);
    });

    Widget createUserHome() {
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
          theme: AppTheme.userTheme,
          home: const UserHomeScreen(),
        ),
      );
    }

    testWidgets('shows Companies first, then company Categories, then Items, with back navigation',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createUserHome());
      await tester.pump(const Duration(milliseconds: 100));

      // LEVEL 1: Companies first (active only)
      expect(find.text('Brands'), findsOneWidget);
      expect(find.text('3 Brands'), findsOneWidget);
      expect(find.text('Honda'), findsOneWidget);
      expect(find.text('Toyota'), findsOneWidget);
      expect(find.text('Tata'), findsOneWidget);
      expect(find.text('Hidden Brand'), findsNothing);
      expect(find.text('3 Categories'), findsOneWidget); // Honda has 3 active cats
      expect(find.text('Engine Parts'), findsNothing);
      expect(find.text('Honda Timing Belt'), findsNothing);

      // Tapping an empty company shows empty company alert
      await tester.ensureVisible(find.text('Tata'));
      await tester.tap(find.text('Tata'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('No categories are added under this brand yet. Please check back later.'),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Honda -> LEVEL 2: Honda's active Categories only
      await tester.ensureVisible(find.text('Honda'));
      await tester.tap(find.text('Honda'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Brands'), findsOneWidget);
      expect(find.text('Honda'), findsOneWidget);
      expect(find.text('3 Categories Available'), findsOneWidget);
      expect(find.text('Engine Parts'), findsOneWidget);
      expect(find.text('Brake System'), findsOneWidget);
      expect(find.text('Air Conditioning'), findsOneWidget);
      expect(find.text('Suspension'), findsNothing); // Toyota's category hidden
      expect(find.text('Hidden Honda Cat'), findsNothing);

      // Tapping an empty category shows empty category dialog
      await tester.ensureVisible(find.text('Air Conditioning'));
      await tester.tap(find.text('Air Conditioning'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('No items are added in this category yet. Please check back later.'),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Engine Parts -> LEVEL 3: Honda Engine Parts items only
      await tester.ensureVisible(find.text('Engine Parts'));
      await tester.tap(find.text('Engine Parts'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Honda • 1 Part Available'), findsOneWidget);
      expect(find.text('Honda Timing Belt'), findsOneWidget);
      expect(find.text('Honda Ceramic Pads'), findsNothing);
      expect(find.text('Toyota Shock Absorber'), findsNothing);
      // Cross-company "All Makes" filter strip removed
      expect(find.text('All Makes'), findsNothing);

      // Quick Category Jump pill switches to Brake System within Honda
      await tester.tap(find.text('Brake System'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Honda Ceramic Pads'), findsOneWidget);
      expect(find.text('Honda Timing Belt'), findsNothing);

      // System back step 1 -> returns from Items to Honda Categories
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('3 Categories Available'), findsOneWidget);
      expect(find.text('Honda Ceramic Pads'), findsNothing);

      // System back step 2 -> returns from Categories to Companies
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Brands'), findsOneWidget);
      expect(find.text('3 Categories Available'), findsNothing);
    });

    testWidgets('supports global search on Level 1 and company-scoped search on Level 2 & 3',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createUserHome());
      await tester.pump(const Duration(milliseconds: 100));

      // Search for a Toyota part on Level 1
      await tester.enterText(find.byType(TextField), 'Shock');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1 Spares Found (All Brands)'), findsOneWidget);
      expect(find.text('Toyota Shock Absorber'), findsOneWidget);
      expect(find.text('Honda Timing Belt'), findsNothing);

      // Clear search returns to Companies list
      await tester.tap(find.text('Clear Search ×'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Brands'), findsOneWidget);

      // Enter Honda Level 2 and search for Toyota's "Shock" -> must NOT appear inside Honda
      await tester.ensureVisible(find.text('Honda'));
      await tester.tap(find.text('Honda'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'Shock');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No Matching Categories or Parts'), findsOneWidget);
      expect(find.text('Toyota Shock Absorber'), findsNothing);

      // Search within Honda Level 2 for "Ceramic" -> finds Honda Ceramic Pads
      await tester.enterText(find.byType(TextField), 'Ceramic');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('1 Spares Found in Honda'), findsOneWidget);
      expect(find.text('Honda Ceramic Pads'), findsOneWidget);

      // Clear search, enter Engine Parts (Level 3), and verify Level 3 search is scoped to Honda
      await tester.tap(find.text('Clear Search ×'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text('Engine Parts'));
      await tester.tap(find.text('Engine Parts'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Honda Timing Belt'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Ceramic');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('1 Spares Found in Honda'), findsOneWidget);
      expect(find.text('Honda Ceramic Pads'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Shock');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('No Matching Spares Found'), findsOneWidget);
      expect(find.text('Toyota Shock Absorber'), findsNothing);

      await tester.tap(find.text('Clear Search'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Honda Timing Belt'), findsOneWidget);
    });

    testWidgets('returns to Companies view automatically if open company is hidden in real time',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createUserHome());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Honda'));
      await tester.tap(find.text('Honda'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('3 Categories Available'), findsOneWidget);

      // Admin deactivates Honda while customer has Honda open
      companyProvider.setCompaniesForTesting([
        honda.copyWith(isActive: false),
        toyota,
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Brands'), findsOneWidget);
      expect(find.text('Honda'), findsNothing);
      expect(find.text('Toyota'), findsOneWidget);
    });

    testWidgets(
        'renders compact blurred heavy truck welcome poster banner above Vehicle Companies',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createUserHome());
      await tester.pump(const Duration(milliseconds: 100));

      final bannerFinder = find.byKey(const ValueKey('welcome_truck_poster_banner'));
      final headerFinder = find.text('Brands');
      expect(bannerFinder, findsOneWidget);
      expect(headerFinder, findsOneWidget);

      // Banner appears cleanly above Vehicle Companies and stays compact
      final bannerRect = tester.getRect(bannerFinder);
      final headerRect = tester.getRect(headerFinder);
      expect(bannerRect.bottom, lessThanOrEqualTo(headerRect.top));
      expect(bannerRect.height, inInclusiveRange(140.0, 200.0));

      // Verify blurred heavy truck asset and SN AUTO welcome copy
      expect(
        find.descendant(of: bannerFinder, matching: find.byType(ImageFiltered)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bannerFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == 'assets/heavy_truck_banner.jpg',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('WELCOME TO'), findsOneWidget);
      expect(find.text('SN AUTO HUB'), findsOneWidget);
      expect(find.text('Heavy Truck & Commercial Spares'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Hides while searching so search results stay prioritized
      await tester.enterText(find.byType(TextField), 'Honda');
      await tester.pump(const Duration(milliseconds: 100));
      expect(bannerFinder, findsNothing);

      // Reappears cleanly when search is cleared
      await tester.tap(find.text('Clear Search ×'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(bannerFinder, findsOneWidget);

      // Compact phone + large accessibility text scale stays overflow-free
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: createUserHome(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(bannerFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tablet width also keeps poster banner compact and overflow-free
      tester.view.physicalSize = const Size(900, 1200);
      await tester.pumpWidget(createUserHome());
      await tester.pump(const Duration(milliseconds: 100));
      expect(bannerFinder, findsOneWidget);
      expect(tester.getRect(bannerFinder).height, inInclusiveRange(170.0, 210.0));
      expect(tester.takeException(), isNull);
    });
  });
}
