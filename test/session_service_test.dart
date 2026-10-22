import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_spare_hub/models/admin_model.dart';
import 'package:auto_spare_hub/services/session_service.dart';
import 'package:auto_spare_hub/providers/admin_login_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testAdmin = AdminModel(
    id: 'AD1729600000000',
    name: 'Super Admin',
    phoneNumber: '9090001001',
    type: 'MANAGER',
    isActive: true,
  );

  group('SessionService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns null when no session is saved', () async {
      final sessionService = SessionService();
      final admin = await sessionService.getAdminSession();
      final isLoggedIn = await sessionService.isLoggedIn();

      expect(admin, isNull);
      expect(isLoggedIn, isFalse);
    });

    test('saves and retrieves admin session accurately', () async {
      final sessionService = SessionService();
      await sessionService.saveAdminSession(testAdmin);

      final admin = await sessionService.getAdminSession();
      final isLoggedIn = await sessionService.isLoggedIn();

      expect(isLoggedIn, isTrue);
      expect(admin, isNotNull);
      expect(admin!.id, equals('AD1729600000000'));
      expect(admin.name, equals('Super Admin'));
      expect(admin.phoneNumber, equals('9090001001'));
      expect(admin.type, equals('MANAGER'));
      expect(admin.isActive, isTrue);
    });

    test('clears session on logout', () async {
      final sessionService = SessionService();
      await sessionService.saveAdminSession(testAdmin);

      var admin = await sessionService.getAdminSession();
      expect(admin, isNotNull);

      await sessionService.clearSession();
      admin = await sessionService.getAdminSession();
      final isLoggedIn = await sessionService.isLoggedIn();

      expect(admin, isNull);
      expect(isLoggedIn, isFalse);
    });
  });

  group('AdminLoginProvider Session Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('checkSavedSession restores admin if session was persisted', () async {
      final sessionService = SessionService();
      await sessionService.saveAdminSession(testAdmin);

      final provider = AdminLoginProvider(sessionService: sessionService);
      expect(provider.isAuthenticated, isFalse);

      final restored = await provider.checkSavedSession();
      expect(restored, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentAdmin?.id, equals('AD1729600000000'));
      expect(provider.currentAdmin?.name, equals('Super Admin'));
    });

    test('checkSavedSession returns false if no session exists', () async {
      final sessionService = SessionService();
      final provider = AdminLoginProvider(sessionService: sessionService);

      final restored = await provider.checkSavedSession();
      expect(restored, isFalse);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentAdmin, isNull);
    });

    test('logout clears both provider state and SharedPreferences', () async {
      final sessionService = SessionService();
      await sessionService.saveAdminSession(testAdmin);

      final provider = AdminLoginProvider(sessionService: sessionService);
      await provider.checkSavedSession();
      expect(provider.isAuthenticated, isTrue);

      await provider.logout();
      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentAdmin, isNull);

      final sessionAfterLogout = await sessionService.getAdminSession();
      expect(sessionAfterLogout, isNull);
    });
  });
}
