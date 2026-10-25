import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/app_lock_service.dart';

/// Provider orchestrating real-time version lock state across Admin and User modules.
/// Monitors Firebase Realtime Database (/0) and evaluates whether current app
/// version from pubspec.yaml is authorized or requires an update lock.
class AppLockProvider with ChangeNotifier {
  final AppLockService _service;

  bool _isLocked = false;
  bool _isChecking = true;
  bool _isAdminMode = true;

  String _currentVersion = AppLockService.fallbackVersion;
  String _buildNumber = AppLockService.fallbackBuildNumber;
  String _updateAddress = '';
  List<String> _adminVersions = ['1', '2'];
  List<String> _userVersions = ['1', '2'];
  String _adminVersionsRaw = '1,2';
  String _userVersionsRaw = '1,2';

  StreamSubscription<AppLockConfig?>? _rtdbSubscription;

  AppLockProvider({AppLockService? service})
      : _service = service ?? AppLockService();

  bool get isLocked => _isLocked;
  bool get isChecking => _isChecking;
  bool get isAdminMode => _isAdminMode;
  String get currentVersion => _currentVersion;
  String get buildNumber => _buildNumber;
  String get updateAddress => _updateAddress;
  List<String> get adminVersions => _adminVersions;
  List<String> get userVersions => _userVersions;
  String get adminVersionsRaw => _adminVersionsRaw;
  String get userVersionsRaw => _userVersionsRaw;

  /// Human-readable installed version representation (e.g. "v1.0.0 (Build 1)")
  String get formattedVersion => 'v$_currentVersion (Build $_buildNumber)';

  /// Initialize lock listener and verify initial version whitelist
  Future<void> init({bool isAdmin = true}) async {
    _isAdminMode = isAdmin;
    _isChecking = true;
    notifyListeners();

    // 1. Fetch installed app version from pubspec.yaml / platform
    final info = await _service.getAppVersionInfo();
    _currentVersion = info['version'] ?? AppLockService.fallbackVersion;
    _buildNumber = info['buildNumber'] ?? AppLockService.fallbackBuildNumber;

    // 2. Initial fetch via REST for instant availability
    final initialConfig = await _service.fetchLockConfig();
    if (initialConfig != null) {
      _applyConfig(initialConfig);
    } else {
      // Evaluate with defaults if network unavailable on boot
      _evaluateLock();
    }

    _isChecking = false;
    notifyListeners();

    // 3. Listen in real-time to Realtime Database changes
    await _rtdbSubscription?.cancel();
    _rtdbSubscription = _service.listenToLockConfig().listen((config) {
      if (config != null) {
        _applyConfig(config);
      }
    });
  }

  void _applyConfig(AppLockConfig config) {
    _updateAddress = config.address;
    _adminVersions = config.adminVersions;
    _userVersions = config.userVersions;
    _adminVersionsRaw = config.adminVersionsRaw;
    _userVersionsRaw = config.userVersionsRaw;
    _evaluateLock();
  }

  void _evaluateLock() {
    final allowedList = _isAdminMode ? _adminVersions : _userVersions;

    final allowed = _service.isVersionAllowed(
      allowedVersions: allowedList,
      buildNumber: _buildNumber,
      versionName: _currentVersion,
    );

    final newLockState = !allowed;
    if (_isLocked != newLockState) {
      _isLocked = newLockState;
      debugPrint('AppLockProvider: lock state updated -> isLocked=$_isLocked (mode: ${_isAdminMode ? 'ADMIN' : 'USER'}, installed: $_currentVersion+$_buildNumber)');
      notifyListeners();
    }
  }

  /// Switch the active lock mode between Admin and User evaluations
  void setAdminMode(bool isAdmin) {
    if (_isAdminMode != isAdmin) {
      _isAdminMode = isAdmin;
      _evaluateLock();
      notifyListeners();
    }
  }

  /// Manually re-check Firebase Realtime Database for updated whitelist
  Future<bool> recheckLock() async {
    _isChecking = true;
    notifyListeners();

    final config = await _service.fetchLockConfig();
    if (config != null) {
      _applyConfig(config);
    } else {
      _evaluateLock();
    }

    _isChecking = false;
    notifyListeners();
    return !_isLocked;
  }

  @override
  void dispose() {
    _rtdbSubscription?.cancel();
    super.dispose();
  }
}
