import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/models/company_model.dart';

void main() {
  group('CompanyModel Tests', () {
    test('creates CompanyModel correctly from map matching Firestore schema', () {
      final data = {
        'NAME': 'Toyota',
        'LOGO_URL': 'https://res.cloudinary.com/dt9qsvvp2/image/upload/toyota.png',
        'DESCRIPTION': 'Japanese multinational automotive manufacturer',
        'IS_ACTIVE': true,
      };

      final company = CompanyModel.fromMap(data, 'c_01');

      expect(company.id, 'c_01');
      expect(company.name, 'Toyota');
      expect(company.logoUrl, 'https://res.cloudinary.com/dt9qsvvp2/image/upload/toyota.png');
      expect(company.description, 'Japanese multinational automotive manufacturer');
      expect(company.isActive, true);
    });

    test('handles missing optional fields with safe defaults', () {
      final Map<String, dynamic> data = {
        'NAME': 'Honda',
      };

      final company = CompanyModel.fromMap(data, 'c_02');

      expect(company.id, 'c_02');
      expect(company.name, 'Honda');
      expect(company.logoUrl, '');
      expect(company.description, null);
      expect(company.isActive, true);
    });

    test('serializes toMap correctly', () {
      final company = CompanyModel(
        id: 'c_03',
        name: 'Hyundai',
        logoUrl: 'https://res.cloudinary.com/test.png',
        description: 'Korean auto manufacturer',
        isActive: false,
      );

      final map = company.toMap();
      expect(map['NAME'], 'Hyundai');
      expect(map['LOGO_URL'], 'https://res.cloudinary.com/test.png');
      expect(map['DESCRIPTION'], 'Korean auto manufacturer');
      expect(map['IS_ACTIVE'], false);
    });
  });
}
