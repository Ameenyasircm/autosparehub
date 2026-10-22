import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/models/product_model.dart';

void main() {
  group('ProductModel Tests', () {
    test('creates ProductModel correctly from map matching flat Firestore schema', () {
      final data = {
        'NAME': 'Power Steering Pump',
        'IMAGE_URL': 'https://res.cloudinary.com/dt9qsvvp2/image/upload/pump.jpg',
        'COMPANY_ID': 'CO1776788421000',
        'COMPANY_NAME': 'Toyota',
        'CATEGORY_ID': 'CAT1776788421000',
        'CATEGORY_NAME': 'Steering & Suspension',
        'APPLICATION': 'Toyota Hilux Vigo 2.5/3.0 D-4D 2005-2015',
        'DESCRIPTION': 'High precision hydraulic pump engineered for heavy duty commercial use.',
        'REF_NO': '44310-0K040',
        'DISPLACEMENT': '16.0 ml/r',
        'MAX_PRESSURE': '120 bar',
        'CONTROLLED_FLOW': '9.0 L/min',
        'SPEED_RANGE': '600 - 4500 r/min',
        'ROTATION': 'Right (Clockwise)',
        'FUEL_FEED_HOLE': 'M16 x 1.5',
        'PRICE': 250.0,
        'STOCK_QUANTITY': 15,
        'IS_ACTIVE': true,
      };

      final product = ProductModel.fromMap(data, 'PRD1776788523000');

      expect(product.id, 'PRD1776788523000');
      expect(product.name, 'Power Steering Pump');
      expect(product.companyName, 'Toyota');
      expect(product.categoryName, 'Steering & Suspension');
      expect(product.application, 'Toyota Hilux Vigo 2.5/3.0 D-4D 2005-2015');
      expect(product.description, 'High precision hydraulic pump engineered for heavy duty commercial use.');
      expect(product.refNo, '44310-0K040');
      expect(product.displacement, '16.0 ml/r');
      expect(product.maxPressure, '120 bar');
      expect(product.controlledFlow, '9.0 L/min');
      expect(product.speedRange, '600 - 4500 r/min');
      expect(product.rotation, 'Right (Clockwise)');
      expect(product.fuelFeedHole, 'M16 x 1.5');
      expect(product.price, 250.0);
      expect(product.stockQuantity, 15);
      expect(product.isActive, true);
    });

    test('handles missing non-mandatory specification fields safely with nulls', () {
      final Map<String, dynamic> data = {
        'NAME': 'Brake Pad Set',
        'IMAGE_URL': 'https://res.cloudinary.com/dt9qsvvp2/image/upload/pads.jpg',
        'COMPANY_ID': 'CO001',
        'COMPANY_NAME': 'Honda',
        'CATEGORY_ID': 'CAT001',
        'CATEGORY_NAME': 'Braking System',
        'APPLICATION': 'Honda Civic 2016-2021',
      };

      final product = ProductModel.fromMap(data, 'PRD9999');

      expect(product.id, 'PRD9999');
      expect(product.name, 'Brake Pad Set');
      expect(product.description, isNull);
      expect(product.refNo, isNull);
      expect(product.displacement, isNull);
      expect(product.maxPressure, isNull);
      expect(product.controlledFlow, isNull);
      expect(product.speedRange, isNull);
      expect(product.rotation, isNull);
      expect(product.fuelFeedHole, isNull);
      expect(product.price, isNull);
      expect(product.stockQuantity, isNull);
      expect(product.isActive, true);
    });

    test('serializes toMap correctly with flat fields and description', () {
      const product = ProductModel(
        id: 'PRD123',
        name: 'Oil Filter',
        imageUrl: 'https://img.jpg',
        companyId: 'CO1',
        companyName: 'Toyota',
        categoryId: 'CAT1',
        categoryName: 'Filters',
        application: 'All Toyota Petrol engines',
        description: 'OEM grade oil filter element.',
        refNo: '90915-YZZD2',
        isActive: true,
      );

      final map = product.toMap();

      expect(map['ID'], 'PRD123');
      expect(map['NAME'], 'Oil Filter');
      expect(map['DESCRIPTION'], 'OEM grade oil filter element.');
      expect(map['REF_NO'], '90915-YZZD2');
      expect(map['COMPANY_NAME'], 'Toyota');
      expect(map['CATEGORY_NAME'], 'Filters');
      expect(map['DISPLACEMENT'], isNull);
      expect(map['IS_ACTIVE'], true);
    });
  });
}
