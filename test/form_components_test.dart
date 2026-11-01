import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/widgets/app_text_field.dart';
import 'package:auto_spare_hub/widgets/app_dropdown_field.dart';
import 'package:auto_spare_hub/widgets/app_submit_button.dart';
import 'package:auto_spare_hub/widgets/app_form_card.dart';

void main() {
  group('AppTextField Widget Tests', () {
    testWidgets('renders label and red asterisk when isRequired is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Full Name',
              hint: 'Enter your full name',
              isRequired: true,
            ),
          ),
        ),
      );

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);
      expect(find.text('Enter your full name'), findsOneWidget);
    });

    testWidgets('does not show asterisk when isRequired is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Optional Notes',
              hint: 'Enter notes',
              isRequired: false,
            ),
          ),
        ),
      );

      expect(find.text('Optional Notes'), findsOneWidget);
      expect(find.text('*'), findsNothing);
    });

    testWidgets('triggers validator on Form validation', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                label: 'Spare Part',
                hint: 'Enter part name',
                controller: controller,
                isRequired: true,
                validator: (val) => val == null || val.isEmpty ? 'Part name is required' : null,
              ),
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('Part name is required'), findsOneWidget);
    });
  });

  group('AppSubmitButton Widget Tests', () {
    testWidgets('renders action label and icon in idle state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSubmitButton(
              label: 'Publish to Catalog',
              icon: Icons.cloud_upload_outlined,
              isLoading: false,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Publish to Catalog'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders circular spinner and loadingLabel when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSubmitButton(
              label: 'Publish to Catalog',
              loadingLabel: 'Saving Spare Part...',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Saving Spare Part...'), findsOneWidget);
      expect(find.text('Publish to Catalog'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppFormCard Widget Tests', () {
    testWidgets('renders section title, icon, and child correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppFormCard(
              title: 'General Information',
              icon: Icons.info_outline,
              isRequired: true,
              child: Text('Card Content Inside'),
            ),
          ),
        ),
      );

      expect(find.text('General Information'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Card Content Inside'), findsOneWidget);
    });
  });

  group('AppDropdownField Widget Tests', () {
    testWidgets('renders dropdown with label and selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDropdownField<String>(
              label: 'Brand',
              hint: 'Select brand',
              value: 'toyota',
              isRequired: true,
              items: const [
                DropdownMenuItem(value: 'toyota', child: Text('Toyota')),
                DropdownMenuItem(value: 'honda', child: Text('Honda')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);
      expect(find.text('Toyota'), findsOneWidget);
    });

    testWidgets('updates displayed selection when value changes dynamically', (tester) async {
      String? selectedBrand;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    AppDropdownField<String>(
                      label: 'Brand',
                      hint: 'Select brand',
                      value: selectedBrand,
                      isRequired: true,
                      items: const [
                        DropdownMenuItem(value: 'toyota', child: Text('Toyota')),
                      ],
                      onChanged: (val) => setState(() => selectedBrand = val),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => selectedBrand = 'toyota'),
                      child: const Text('Auto-select'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Toyota'), findsNothing);
      expect(find.text('Select brand'), findsOneWidget);

      await tester.tap(find.text('Auto-select'));
      await tester.pumpAndSettle();

      expect(find.text('Toyota'), findsOneWidget);
    });
  });
}

