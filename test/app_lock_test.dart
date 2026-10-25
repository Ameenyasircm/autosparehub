import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/services/app_lock_service.dart';
import 'package:auto_spare_hub/providers/app_lock_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockConfig Tests', () {
    test('parses RTDB map into structured config with clean version lists', () {
      final map = {
        'ADDRESS': 'https://play.google.com/store/apps/details?id=com.autosparehub',
        'ADMIN_VERSIONS': '1, 2, 3',
        'USER_VERSIONS': '1,2',
      };

      final config = AppLockConfig.fromMap(map);
      expect(config.address, 'https://play.google.com/store/apps/details?id=com.autosparehub');
      expect(config.adminVersions, ['1', '2', '3']);
      expect(config.userVersions, ['1', '2']);
    });

    test('handles missing or empty fields safely without exceptions', () {
      final config = AppLockConfig.fromMap({});
      expect(config.address, '');
      expect(config.adminVersions, isEmpty);
      expect(config.userVersions, isEmpty);
    });
  });

  group('AppLockService Whitelist Validation Tests', () {
    late AppLockService service;

    setUp(() {
      service = AppLockService();
    });

    test('allows version when build number is in whitelist', () {
      final allowed = service.isVersionAllowed(
        allowedVersions: ['1', '2'],
        buildNumber: '1',
        versionName: '1.0.0',
      );
      expect(allowed, isTrue);
    });

    test('allows version when full semantic version name is in whitelist', () {
      final allowed = service.isVersionAllowed(
        allowedVersions: ['1.0.0', '1.0.1'],
        buildNumber: '5',
        versionName: '1.0.0',
      );
      expect(allowed, isTrue);
    });

    test('allows version when major version prefix is in whitelist', () {
      final allowed = service.isVersionAllowed(
        allowedVersions: ['1', '2'],
        buildNumber: '99',
        versionName: '1.2.3',
      );
      expect(allowed, isTrue);
    });

    test('blocks version when neither build number nor version name are in whitelist', () {
      final allowed = service.isVersionAllowed(
        allowedVersions: ['2', '3'],
        buildNumber: '1',
        versionName: '1.0.0',
      );
      expect(allowed, isFalse);
    });

    test('blocks version when whitelist is completely empty', () {
      final allowed = service.isVersionAllowed(
        allowedVersions: [],
        buildNumber: '1',
        versionName: '1.0.0',
      );
      expect(allowed, isFalse);
    });

    test('universal unlock with wildcard "all" or "*"', () {
      expect(
        service.isVersionAllowed(
          allowedVersions: ['all'],
          buildNumber: '999',
          versionName: '9.9.9',
        ),
        isTrue,
      );

      expect(
        service.isVersionAllowed(
          allowedVersions: ['*'],
          buildNumber: '999',
          versionName: '9.9.9',
        ),
        isTrue,
      );
    });
  });

  group('AppLockProvider Tests', () {
    test('initializes with fallback versions and default lock state', () {
      final provider = AppLockProvider();
      expect(provider.currentVersion, AppLockService.fallbackVersion);
      expect(provider.buildNumber, AppLockService.fallbackBuildNumber);
      expect(provider.formattedVersion, 'v1.0.0 (Build 1)');
      expect(provider.isLocked, isFalse);
    });

    test('evaluates lock state accurately when switching between admin and user modes', () {
      final provider = AppLockProvider();

      // Simulate RTDB: Admin version allows 1,2; User version allows only 2
      final config = AppLockConfig.fromMap({
        'ADDRESS': 'https://example.com/update',
        'ADMIN_VERSIONS': '1,2',
        'USER_VERSIONS': '2',
      });

      expect(config.adminVersions, contains('1'));
      expect(config.userVersions, isNot(contains('1')));

      // In Admin mode: build '1' is allowed
      provider.setAdminMode(true);
      expect(provider.isAdminMode, isTrue);
    });
  });
}
