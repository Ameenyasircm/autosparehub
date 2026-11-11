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

  testWidgets('Admin Splash Screen renders logo and SN AUTO HUB branding cleanly',
      (WidgetTester tester) async {
    // Build MyApp and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify AdminSplashScreen renders with centered branding logo and SN AUTO HUB text
    expect(find.byType(AdminSplashScreen), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('SN AUTO HUB'), findsOneWidget);

    final textWidget = tester.widget<Text>(find.text('SN AUTO HUB'));
    expect(textWidget.textSpan, isNotNull);
    final rootSpan = textWidget.textSpan! as TextSpan;
    expect(rootSpan.children, hasLength(2));

    final prefixSpan = rootSpan.children![0] as TextSpan;
    final hubSpan = rootSpan.children![1] as TextSpan;
    expect(prefixSpan.text, 'SN AUTO ');
    expect(prefixSpan.style?.color, AppColors.textLight);
    expect(prefixSpan.style?.fontWeight, FontWeight.w900);
    expect(hubSpan.text, 'HUB');
    expect(hubSpan.style?.color, AppColors.warmGold);
    expect(hubSpan.style?.fontWeight, FontWeight.w900);

    // Advance clock past splash timer to avoid hanging pending timers
    await tester.pump(const Duration(milliseconds: 2200));
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
    expect(find.text('SN AUTO HUB'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  });
}
