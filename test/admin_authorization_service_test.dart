import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/models/admin_model.dart';
import 'package:auto_spare_hub/services/admin_authorization_service.dart';

void main() {
  group('AdminAuthorizationService Tests', () {
    test('permits MANAGER to manage admins', () {
      final manager = AdminModel(
        id: '111',
        name: 'Manager Admin',
        phoneNumber: '9090001001',
        type: 'MANAGER',
        isActive: true,
      );

      expect(AdminAuthorizationService.canManageAdmins(manager), true);
    });

    test('denies STAFF from managing admins', () {
      final staff = AdminModel(
        id: '222',
        name: 'Staff Admin',
        phoneNumber: '9090001002',
        type: 'STAFF',
        isActive: true,
      );

      expect(AdminAuthorizationService.canManageAdmins(staff), false);
    });

    test('denies inactive manager from managing admins', () {
      final inactiveManager = AdminModel(
        id: '333',
        name: 'Inactive Manager',
        phoneNumber: '9090001003',
        type: 'MANAGER',
        isActive: false,
      );

      expect(AdminAuthorizationService.canManageAdmins(inactiveManager), false);
    });

    test('permits active admins to manage companies and categories', () {
      final staff = AdminModel(
        id: '222',
        name: 'Staff Admin',
        phoneNumber: '9090001002',
        type: 'STAFF',
        isActive: true,
      );

      expect(AdminAuthorizationService.canManageCompanies(staff), true);
      expect(AdminAuthorizationService.canManageCategories(staff), true);
    });
  });
}
