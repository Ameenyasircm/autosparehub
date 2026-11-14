import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_spare_hub/main.dart';
import 'package:auto_spare_hub/screens/admin_splash_screen.dart';
import 'package:auto_spare_hub/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Admin Splash Screen renders logo and SN AUTO SPARE HUB branding cleanly',
      (WidgetTester tester) async {
    // Build MyApp and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify AdminSplashScreen renders with centered branding logo and SN AUTO SPARE HUB text
    expect(find.byType(AdminSplashScreen), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('SN AUTO'), findsOneWidget);
    expect(find.text('SPARE HUB'), findsOneWidget);
    expect(find.text('ADMIN PORTAL'), findsOneWidget);

    final title = tester.widget<Text>(find.text('SN AUTO'));
    expect(title.style?.color, AppColors.textLight);
    expect(title.style?.fontWeight, FontWeight.w900);
    final subtitle = tester.widget<Text>(find.text('SPARE HUB'));
    expect(subtitle.style?.color, AppColors.warmGold);

    // Advance clock past splash timer to avoid hanging pending timers
    await tester.pump(const Duration(milliseconds: 3200));
    await tester.pumpAndSettle();
  });

  testWidgets('Admin Splash Screen fits on compact screen without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text('SN AUTO'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
  });
}
