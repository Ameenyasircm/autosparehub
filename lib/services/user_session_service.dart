import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_model.dart';

/// Service managing persistent local customer state, registration identity, and cached approval status.
class UserSessionService {
  static const String _keyCustomerSession = 'autospare_customer_session';

  final SharedPreferences? _prefsInstance;

  UserSessionService({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> get _prefs async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  /// Persist customer profile to local storage
  Future<void> saveCustomerSession(CustomerModel customer) async {
    try {
      final prefs = await _prefs;
      final jsonMap = {
        'id': customer.id,
        'name': customer.name,
        'phoneNumber': customer.phoneNumber,
        'status': customer.status,
        'requestedAt': customer.requestedAt?.millisecondsSinceEpoch,
        'approvedAt': customer.approvedAt?.millisecondsSinceEpoch,
        'rejectionReason': customer.rejectionReason,
        'password': customer.password,
      };
      await prefs.setString(_keyCustomerSession, jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('UserSessionService.saveCustomerSession error: $e');
    }
  }

  /// Retrieve locally saved customer profile
  Future<CustomerModel?> getCustomerSession() async {
    try {
      final prefs = await _prefs;
      final jsonStr = prefs.getString(_keyCustomerSession);
      if (jsonStr == null || jsonStr.trim().isEmpty) return null;

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final id = (data['id'] ?? '').toString();
      if (id.isEmpty) return null;

      return CustomerModel.fromMap(data, id);
    } catch (e) {
      debugPrint('UserSessionService.getCustomerSession error: $e');
      return null;
    }
  }

  /// Update approval status in local cache
  Future<void> updateCustomerStatus(String status) async {
    try {
      final current = await getCustomerSession();
      if (current != null) {
        await saveCustomerSession(current.copyWith(status: status));
      }
    } catch (e) {
      debugPrint('UserSessionService.updateCustomerStatus error: $e');
    }
  }

  /// Clear customer session
  Future<void> clearCustomerSession() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_keyCustomerSession);
    } catch (e) {
      debugPrint('UserSessionService.clearCustomerSession error: $e');
    }
  }
}
