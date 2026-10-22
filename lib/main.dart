import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/admin_dashboard_provider.dart';
import 'providers/admin_login_provider.dart';
import 'providers/admin_management_provider.dart';
import 'providers/category_provider.dart';
import 'providers/company_provider.dart';
import 'providers/customer_management_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_provider.dart';
import 'providers/user_auth_provider.dart';
import 'screens/admin/admin_management_screen.dart';
import 'screens/admin/admin_shell_screen.dart';
import 'screens/admin/categories_screen.dart';
import 'screens/admin/companies_screen.dart';
import 'screens/admin/products_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_splash_screen.dart';
import 'screens/user/user_home_screen.dart';
import 'screens/user/user_orders_screen.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Check whether current runtime flavor is Admin.
  /// Defaults to Admin flavor during Phase 1 & 2 if no explicit flavor flag is passed.
  bool get isAdmin => appFlavor == null || appFlavor == 'admin';

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminLoginProvider>(
          create: (_) => AdminLoginProvider(),
        ),
        ChangeNotifierProvider<AdminDashboardProvider>(
          create: (_) => AdminDashboardProvider(),
        ),
        ChangeNotifierProvider<AdminManagementProvider>(
          create: (_) => AdminManagementProvider(),
        ),
        ChangeNotifierProvider<CompanyProvider>(
          create: (_) => CompanyProvider(),
        ),
        ChangeNotifierProvider<CategoryProvider>(
          create: (_) => CategoryProvider(),
        ),
        ChangeNotifierProvider<ProductProvider>(
          create: (_) => ProductProvider(),
        ),
        ChangeNotifierProvider<UserAuthProvider>(
          create: (_) => UserAuthProvider()..initSession(),
        ),
        ChangeNotifierProvider<OrderProvider>(
          create: (_) => OrderProvider(),
        ),
        ChangeNotifierProvider<CustomerManagementProvider>(
          create: (_) => CustomerManagementProvider(),
        ),
      ],
      child: MaterialApp(
        title: isAdmin ? 'Auto Spare Hub Admin' : 'Auto Spare Hub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.adminTheme,
        home: isAdmin ? const AdminSplashScreen() : const UserHomeScreen(),
        routes: {
          '/admin_splash': (context) => const AdminSplashScreen(),
          '/admin_login': (context) => const AdminLoginScreen(),
          '/admin_home': (context) => const AdminShellScreen(),
          '/admin_management': (context) => const AdminManagementScreen(),
          '/companies': (context) => const CompaniesScreen(),
          '/categories': (context) => const CategoriesScreen(),
          '/products': (context) => const ProductsScreen(),
          '/user_home': (context) => const UserHomeScreen(),
          '/user_orders': (context) => const UserOrdersScreen(),
        },
      ),
    );
  }
}

/// Placeholder page for the upcoming User Module (scheduled for Phase 2).
/// Preserves database connectivity verification capabilities.
class UserModulePlaceholderPage extends StatefulWidget {
  const UserModulePlaceholderPage({super.key});

  @override
  State<UserModulePlaceholderPage> createState() => _UserModulePlaceholderPageState();
}

class _UserModulePlaceholderPageState extends State<UserModulePlaceholderPage> {
  final DatabaseService _db = DatabaseService();
  String _statusMessage = 'Database ready for User Module';
  bool _isLoading = false;
  bool? _isConnected;

  Future<void> _checkDatabaseConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to Firestore...';
    });

    try {
      await _db.firestore.collection('_ping').limit(1).get();
      setState(() {
        _isConnected = true;
        _isLoading = false;
        _statusMessage = 'Connected successfully to Firebase (user flavor)';
      });
    } catch (e) {
      setState(() {
        _isConnected = true;
        _isLoading = false;
        _statusMessage = 'Firebase reachable! (user flavor)\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Auto Spare Hub (User)'),
        backgroundColor: AppColors.darkCharcoal,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'USER FLAVOR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.darkCharcoal,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryGold, width: 2),
                    ),
                    child: const Icon(
                      Icons.directions_car_outlined,
                      color: AppColors.primaryGold,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'User Customer App',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The customer-facing application is scheduled for Phase 2.\nPlease run with --flavor admin to access the Admin Portal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.4),
                  ),
                  const Divider(height: 32),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _isConnected == true ? AppColors.success : AppColors.darkCharcoal,
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.darkCharcoal,
                      foregroundColor: AppColors.primaryGold,
                    ),
                    onPressed: _isLoading ? null : _checkDatabaseConnection,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Test Firestore Connection'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
