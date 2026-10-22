import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/admin_model.dart';

/// Service managing persistent admin session in device local storage via SharedPreferences.
/// Plaintext passwords are NEVER stored.
class SessionService {
  static const String _keyAdminSession = 'autospare_admin_session';
  static const String _keyIsLoggedIn = 'autospare_is_logged_in';

  final SharedPreferences? _prefsInstance;

  SessionService({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> get _prefs async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  /// Persist authenticated Admin session to local storage
  Future<void> saveAdminSession(AdminModel admin) async {
    try {
      final prefs = await _prefs;
      final jsonStr = jsonEncode(admin.toMap());
      await prefs.setString(_keyAdminSession, jsonStr);
      await prefs.setBool(_keyIsLoggedIn, true);
    } catch (e) {
      debugPrint('SessionService.saveAdminSession error: $e');
    }
  }

  /// Retrieve saved Admin session, if any exists and is valid
  Future<AdminModel?> getAdminSession() async {
    try {
      final prefs = await _prefs;
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      if (!isLoggedIn) return null;

      final jsonStr = prefs.getString(_keyAdminSession);
      if (jsonStr == null || jsonStr.trim().isEmpty) return null;

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final id = (data['id'] ?? '').toString();
      if (id.isEmpty) return null;

      return AdminModel.fromMap(data, id);
    } catch (e) {
      debugPrint('SessionService.getAdminSession error: $e');
      // If corrupted data was found, clean up
      await clearSession();
      return null;
    }
  }

  /// Clear saved session upon explicit logout
  Future<void> clearSession() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_keyAdminSession);
      await prefs.setBool(_keyIsLoggedIn, false);
    } catch (e) {
      debugPrint('SessionService.clearSession error: $e');
    }
  }

  /// Check whether an active session flag exists
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await _prefs;
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      debugPrint('SessionService.isLoggedIn error: $e');
      return false;
    }
  }
}
