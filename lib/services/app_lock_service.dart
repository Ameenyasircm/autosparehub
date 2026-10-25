import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Data class holding the version lock configuration from Firebase Realtime Database (/0)
class AppLockConfig {
  final String address;
  final String adminVersionsRaw;
  final String userVersionsRaw;
  final List<String> adminVersions;
  final List<String> userVersions;

  const AppLockConfig({
    required this.address,
    required this.adminVersionsRaw,
    required this.userVersionsRaw,
    required this.adminVersions,
    required this.userVersions,
  });

  factory AppLockConfig.fromMap(Map<dynamic, dynamic> map) {
    final address = (map['ADDRESS'] ?? map['address'] ?? map['url'] ?? '').toString().trim();
    final adminRaw = (map['ADMIN_VERSIONS'] ?? map['adminVersions'] ?? map['ADMIN_VERSION'] ?? '').toString().trim();
    final userRaw = (map['USER_VERSIONS'] ?? map['userVersions'] ?? map['USER_VERSION'] ?? '').toString().trim();

    List<String> parseVersions(String raw) {
      if (raw.isEmpty) return [];
      return raw.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    }

    return AppLockConfig(
      address: address,
      adminVersionsRaw: adminRaw,
      userVersionsRaw: userRaw,
      adminVersions: parseVersions(adminRaw),
      userVersions: parseVersions(userRaw),
    );
  }
}

/// Service managing version-based app lock against Firebase Realtime Database
/// URL: https://autosparehub-ce005-default-rtdb.firebaseio.com/0
class AppLockService {
  static const String rtdbUrl = 'https://autosparehub-ce005-default-rtdb.firebaseio.com';
  static const String rtdbRestEndpoint = 'https://autosparehub-ce005-default-rtdb.firebaseio.com/0.json';

  // Fallback defaults reflecting pubspec.yaml version (1.0.0+1)
  static const String fallbackVersion = '1.0.0';
  static const String fallbackBuildNumber = '1';

  http.Client? _customClient;
  http.Client get _client => _customClient ??= http.Client();
  FirebaseDatabase? _database;

  AppLockService({http.Client? client, FirebaseDatabase? database})
      : _customClient = client,
        _database = database;

  FirebaseDatabase get _rtdb {
    if (_database != null) return _database!;
    try {
      final app = Firebase.apps.isNotEmpty ? Firebase.app() : null;
      if (app != null) {
        _database = FirebaseDatabase.instanceFor(
          app: app,
          databaseURL: rtdbUrl,
        );
      } else {
        _database = FirebaseDatabase.instance;
      }
    } catch (_) {
      _database = FirebaseDatabase.instance;
    }
    return _database!;
  }

  /// Get app version information from platform / pubspec.yaml
  Future<Map<String, String>> getAppVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim().isNotEmpty ? info.version.trim() : fallbackVersion;
      final buildNumber = info.buildNumber.trim().isNotEmpty ? info.buildNumber.trim() : fallbackBuildNumber;

      return {
        'version': version,
        'buildNumber': buildNumber,
        'major': version.split('.').first,
        'full': '$version+$buildNumber',
      };
    } catch (e) {
      debugPrint('AppLockService.getAppVersionInfo fallback: $e');
      return {
        'version': fallbackVersion,
        'buildNumber': fallbackBuildNumber,
        'major': fallbackVersion.split('.').first,
        'full': '$fallbackVersion+$fallbackBuildNumber',
      };
    }
  }

  /// Fetch app lock configuration from Firebase Realtime Database (/0) via fast REST
  Future<AppLockConfig?> fetchLockConfig() async {
    try {
      final uri = Uri.parse(rtdbRestEndpoint);
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body.isNotEmpty && response.body != 'null') {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return AppLockConfig.fromMap(decoded);
        }
      }
    } catch (e) {
      debugPrint('AppLockService.fetchLockConfig REST error: $e');
    }
    return null;
  }

  /// Subscribe to realtime updates from Firebase Realtime Database (/0)
  Stream<AppLockConfig?> listenToLockConfig() {
    try {
      return _rtdb.ref('0').onValue.map((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          return AppLockConfig.fromMap(val);
        }
        return null;
      }).handleError((error) {
        debugPrint('AppLockService.listenToLockConfig error: $error');
        return null;
      });
    } catch (e) {
      debugPrint('AppLockService.listenToLockConfig setup error: $e');
      return const Stream.empty();
    }
  }

  /// Determines if an app version is allowed based on the whitelist of versions.
  /// Strict Whitelist logic matching TeamOne:
  /// - Empty whitelist = locked (safe fallback)
  /// - Whitelist containing 'all' or '*' = allowed
  /// - Whitelist matching buildNumber, version, majorVersion, or full version = allowed
  bool isVersionAllowed({
    required List<String> allowedVersions,
    required String buildNumber,
    required String versionName,
  }) {
    if (allowedVersions.isEmpty) return false;

    final lowerVersions = allowedVersions.map((v) => v.toLowerCase().trim()).toSet();

    // Universal unlock wildcard
    if (lowerVersions.contains('all') || lowerVersions.contains('*')) {
      return true;
    }

    final cleanBuild = buildNumber.toLowerCase().trim();
    final cleanVersion = versionName.toLowerCase().trim();
    final major = cleanVersion.split('.').first;
    final full = '$cleanVersion+$cleanBuild';

    return lowerVersions.contains(cleanBuild) ||
        lowerVersions.contains(cleanVersion) ||
        lowerVersions.contains(major) ||
        lowerVersions.contains(full);
  }
}
