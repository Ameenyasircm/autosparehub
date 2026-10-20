import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/models/admin_model.dart';

void main() {
  group('AdminModel Tests', () {
    test('creates AdminModel correctly from Map data matching Firestore structure', () {
      final data = {
        'IS_ACTIVE': true,
        'NAME': 'codemates admin',
        'PASSWORD': '001001',
        'PHONE_NUMBER': '9090001001',
        'TYPE': 'MANAGER',
      };

      final admin = AdminModel.fromMap(data, '111');

      expect(admin.id, '111');
      expect(admin.name, 'codemates admin');
      expect(admin.phoneNumber, '9090001001');
      expect(admin.type, 'MANAGER');
      expect(admin.isActive, true);
    });

    test('handles inactive admin properly', () {
      final data = {
        'IS_ACTIVE': false,
        'NAME': 'inactive admin',
        'PHONE_NUMBER': '9999999999',
        'TYPE': 'STAFF',
      };

      final admin = AdminModel.fromMap(data, '222');
      expect(admin.isActive, false);
    });

    test('handles missing or unexpected fields safely', () {
      final Map<String, dynamic> emptyData = {};

      final admin = AdminModel.fromMap(emptyData, '333');
      expect(admin.id, '333');
      expect(admin.name, 'Admin');
      expect(admin.phoneNumber, '');
      expect(admin.type, 'STAFF');
      expect(admin.isActive, false);
    });

    test('serializes toMap without exposing passwords', () {
      final admin = AdminModel(
        id: '111',
        name: 'codemates admin',
        phoneNumber: '9090001001',
        type: 'MANAGER',
        isActive: true,
      );

      final map = admin.toMap();
      expect(map.containsKey('PASSWORD'), false);
      expect(map.containsKey('password'), false);
      expect(map['NAME'], 'codemates admin');
      expect(map['PHONE_NUMBER'], '9090001001');
      expect(map['TYPE'], 'MANAGER');
      expect(map['IS_ACTIVE'], true);
    });
  });
}
