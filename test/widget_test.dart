import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_spare_hub/main.dart';
import 'package:auto_spare_hub/screens/admin_splash_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Admin Splash Screen smoke test', (WidgetTester tester) async {
    // Build MyApp and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify AdminSplashScreen renders with branding elements
    expect(find.byType(AdminSplashScreen), findsOneWidget);
    expect(find.text('AUTO SPARE HUB'), findsOneWidget);
    expect(find.text('ADMIN PORTAL'), findsOneWidget);
  });
}
