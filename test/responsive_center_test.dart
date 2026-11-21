import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/widgets/responsive_center.dart';

void main() {
  Future<double> contentWidth(WidgetTester tester, Size screen, Widget Function(Widget) wrap) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const key = ValueKey('content');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: wrap(const SizedBox.expand(key: key))),
    ));
    return tester.getSize(find.byKey(key)).width;
  }

  testWidgets('forms fill the width on phones', (tester) async {
    final w = await contentWidth(tester, const Size(390, 844), (c) => ResponsiveCenter.form(child: c));
    expect(w, 390);
  });

  testWidgets('forms are capped and centred on tablets', (tester) async {
    final w = await contentWidth(tester, const Size(1280, 800), (c) => ResponsiveCenter.form(child: c));
    expect(w, 680);
  });

  testWidgets('lists use a wider cap on tablets', (tester) async {
    final w = await contentWidth(tester, const Size(1280, 800), (c) => ResponsiveCenter.list(child: c));
    expect(w, 1040);
  });
}
