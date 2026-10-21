import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/models/category_model.dart';

void main() {
  group('CategoryModel Tests', () {
    test('creates CategoryModel correctly from map matching Firestore schema', () {
      final data = {
        'NAME': 'Engine Parts',
        'IMAGE_URL': 'https://res.cloudinary.com/dt9qsvvp2/image/upload/engine.png',
        'DESCRIPTION': 'Pistons, spark plugs, timing belts, camshafts',
        'IS_ACTIVE': true,
      };

      final category = CategoryModel.fromMap(data, 'cat_01');

      expect(category.id, 'cat_01');
      expect(category.name, 'Engine Parts');
      expect(category.imageUrl, 'https://res.cloudinary.com/dt9qsvvp2/image/upload/engine.png');
      expect(category.description, 'Pistons, spark plugs, timing belts, camshafts');
      expect(category.isActive, true);
    });

    test('handles missing optional fields with safe defaults', () {
      final Map<String, dynamic> data = {
        'NAME': 'Braking Systems',
      };

      final category = CategoryModel.fromMap(data, 'cat_02');

      expect(category.id, 'cat_02');
      expect(category.name, 'Braking Systems');
      expect(category.imageUrl, '');
      expect(category.description, null);
      expect(category.isActive, true);
    });

    test('serializes toMap correctly', () {
      final category = CategoryModel(
        id: 'cat_03',
        name: 'Transmission',
        imageUrl: 'https://res.cloudinary.com/transmission.png',
        description: 'Gearboxes and clutches',
        isActive: false,
      );

      final map = category.toMap();
      expect(map['NAME'], 'Transmission');
      expect(map['IMAGE_URL'], 'https://res.cloudinary.com/transmission.png');
      expect(map['DESCRIPTION'], 'Gearboxes and clutches');
      expect(map['IS_ACTIVE'], false);
    });
  });
}
