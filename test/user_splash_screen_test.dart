import 'package:auto_spare_hub/screens/user/user_splash_screen.dart';
import 'package:auto_spare_hub/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserSplashScreen Tests', () {
    testWidgets('renders logo and SN AUTO HUB branding cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.userTheme,
          home: UserSplashScreen(
            destinationBuilder: (_) => const Scaffold(
              body: Center(child: Text('Home Destination')),
            ),
          ),
        ),
      );

      expect(find.byType(UserSplashScreen), findsOneWidget);
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

      // Advance through animations and splash timer to verify clean navigation
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      expect(find.text('Home Destination'), findsOneWidget);
    });

    testWidgets('fits on compact screen without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.userTheme,
          home: UserSplashScreen(
            destinationBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('SN AUTO HUB'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
    });

    testWidgets('cancels pending navigation timer when disposed early',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.userTheme,
          home: UserSplashScreen(
            destinationBuilder: (_) => const Text('Should Not Navigate'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 2000));

      expect(find.text('Should Not Navigate'), findsNothing);
    });
  });
}

