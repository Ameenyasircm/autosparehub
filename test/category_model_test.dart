import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/models/category_model.dart';
import 'package:auto_spare_hub/providers/category_provider.dart';

void main() {
  group('CategoryModel Tests', () {
    test('creates CategoryModel correctly from map matching Firestore schema', () {
      final data = {
        'NAME': 'Engine Parts',
        'IMAGE_URL': 'https://res.cloudinary.com/dt9qsvvp2/image/upload/engine.png',
        'COMPANY_ID': 'COMP_01',
        'COMPANY_NAME': 'Toyota',
        'DESCRIPTION': 'Pistons, spark plugs, timing belts, camshafts',
        'IS_ACTIVE': true,
      };

      final category = CategoryModel.fromMap(data, 'cat_01');

      expect(category.id, 'cat_01');
      expect(category.name, 'Engine Parts');
      expect(category.imageUrl, 'https://res.cloudinary.com/dt9qsvvp2/image/upload/engine.png');
      expect(category.companyId, 'COMP_01');
      expect(category.companyName, 'Toyota');
      expect(category.description, 'Pistons, spark plugs, timing belts, camshafts');
      expect(category.isActive, true);
    });

    test('parses lowercase companyId and companyName fallback keys', () {
      final data = {
        'name': 'Filters',
        'imageUrl': 'https://example.com/filters.png',
        'companyId': 'COMP_02',
        'companyName': 'Honda',
        'isActive': false,
      };

      final category = CategoryModel.fromMap(data, 'cat_lc');
      expect(category.companyId, 'COMP_02');
      expect(category.companyName, 'Honda');
      expect(category.isActive, false);
    });

    test('handles missing optional fields with safe defaults', () {
      final Map<String, dynamic> data = {
        'NAME': 'Braking Systems',
      };

      final category = CategoryModel.fromMap(data, 'cat_02');

      expect(category.id, 'cat_02');
      expect(category.name, 'Braking Systems');
      expect(category.imageUrl, '');
      expect(category.companyId, '');
      expect(category.companyName, '');
      expect(category.description, null);
      expect(category.isActive, true);
    });

    test('serializes toMap including COMPANY_ID and COMPANY_NAME', () {
      const category = CategoryModel(
        id: 'cat_03',
        name: 'Transmission',
        imageUrl: 'https://res.cloudinary.com/transmission.png',
        companyId: 'COMP_01',
        companyName: 'Toyota',
        description: 'Gearboxes and clutches',
        isActive: false,
      );

      final map = category.toMap();
      expect(map['NAME'], 'Transmission');
      expect(map['IMAGE_URL'], 'https://res.cloudinary.com/transmission.png');
      expect(map['COMPANY_ID'], 'COMP_01');
      expect(map['COMPANY_NAME'], 'Toyota');
      expect(map['DESCRIPTION'], 'Gearboxes and clutches');
      expect(map['IS_ACTIVE'], false);
    });

    test('copyWith and value equality respect company fields', () {
      const base = CategoryModel(
        id: 'cat_04',
        name: 'Engine Parts',
        imageUrl: 'https://example.com/a.png',
        companyId: 'COMP_1',
        companyName: 'Toyota',
        isActive: true,
      );

      final copiedSame = base.copyWith();
      expect(copiedSame, equals(base));
      expect(copiedSame.hashCode, equals(base.hashCode));

      final otherCompany = base.copyWith(
        companyId: 'COMP_2',
        companyName: 'Honda',
      );
      expect(otherCompany, isNot(equals(base)));
      expect(otherCompany.companyId, 'COMP_2');
      expect(otherCompany.companyName, 'Honda');
    });
  });

  group('CategoryProvider Company-Scoping Tests', () {
    late CategoryProvider provider;

    setUp(() {
      provider = CategoryProvider();
      provider.setCategoriesForTesting(const [
        CategoryModel(
          id: 'CAT_1',
          name: 'Engine Parts',
          imageUrl: '',
          companyId: 'COMP_TOYOTA',
          companyName: 'Toyota',
          isActive: true,
        ),
        CategoryModel(
          id: 'CAT_2',
          name: 'Engine Parts',
          imageUrl: '',
          companyId: 'COMP_HONDA',
          companyName: 'Honda',
          isActive: true,
        ),
        CategoryModel(
          id: 'CAT_3',
          name: 'Brake System',
          imageUrl: '',
          companyId: 'COMP_HONDA',
          companyName: 'Honda',
          isActive: true,
        ),
        CategoryModel(
          id: 'CAT_LEGACY',
          name: 'Unassigned Suspension',
          imageUrl: '',
          isActive: true,
        ),
      ]);
    });

    test('categoriesForCompany and unassignedCategories partition categories accurately', () {
      expect(provider.categoriesForCompany('COMP_TOYOTA').map((c) => c.id), ['CAT_1']);
      expect(provider.categoriesForCompany('COMP_HONDA').map((c) => c.id), ['CAT_2', 'CAT_3']);
      expect(provider.unassignedCategories.map((c) => c.id), ['CAT_LEGACY']);
    });

    test('filteredCategories supports company filter, unassigned filter, and companyName search', () {
      expect(provider.filteredCategories.length, 4);

      provider.setSelectedCompanyId('COMP_HONDA');
      expect(provider.filteredCategories.map((c) => c.id), ['CAT_2', 'CAT_3']);

      provider.setSelectedCompanyId(CategoryProvider.unassignedCompanyFilter);
      expect(provider.filteredCategories.map((c) => c.id), ['CAT_LEGACY']);

      provider.setSelectedCompanyId('ALL');
      provider.setSearchQuery('toyota');
      expect(provider.filteredCategories.map((c) => c.id), ['CAT_1']);
    });

    test('duplicate name detection is scoped per company rather than global', () {
      // Duplicate inside the same company (case-insensitive)
      expect(
        provider.hasDuplicateNameInCompany(
          name: '  engine parts  ',
          companyId: 'COMP_TOYOTA',
        ),
        isTrue,
      );

      // Editing same category record should not flag itself as duplicate
      expect(
        provider.hasDuplicateNameInCompany(
          name: 'Engine Parts',
          companyId: 'COMP_TOYOTA',
          excludeId: 'CAT_1',
        ),
        isFalse,
      );

      // Same category name in a third company is allowed
      expect(
        provider.hasDuplicateNameInCompany(
          name: 'Engine Parts',
          companyId: 'COMP_TATA',
        ),
        isFalse,
      );
    });

    test('addCategory and editCategory require non-empty companyId and block same-company duplicates', () async {
      final dummyFile = File('missing.png');

      final missingCompanyAdd = await provider.addCategory(
        name: 'Filters',
        companyId: '  ',
        companyName: '',
        imageFile: dummyFile,
      );
      expect(missingCompanyAdd, isFalse);
      expect(provider.errorMessage, 'Please select a company for this category.');

      final dupAdd = await provider.addCategory(
        name: 'engine parts',
        companyId: 'COMP_HONDA',
        companyName: 'Honda',
        imageFile: dummyFile,
      );
      expect(dupAdd, isFalse);
      expect(provider.errorMessage, contains('already exists under Honda'));

      final missingCompanyEdit = await provider.editCategory(
        id: 'CAT_1',
        name: 'Engine Parts',
        companyId: '',
        companyName: '',
        currentImageUrl: '',
        isActive: true,
      );
      expect(missingCompanyEdit, isFalse);
      expect(provider.errorMessage, 'Please select a company for this category.');

      final dupEdit = await provider.editCategory(
        id: 'CAT_3',
        name: 'Engine Parts',
        companyId: 'COMP_HONDA',
        companyName: 'Honda',
        currentImageUrl: '',
        isActive: true,
      );
      expect(dupEdit, isFalse);
      expect(provider.errorMessage, contains('already exists under Honda'));
    });
  });
}
