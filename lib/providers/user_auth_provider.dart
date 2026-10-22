import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../services/user_session_service.dart';

/// Provider managing customer registration, approval checking, and identity state.
class UserAuthProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;
  final UserSessionService _sessionService;

  UserAuthProvider({
    FirebaseFirestore? firestore,
    UserSessionService? sessionService,
  })  : _customFirestore = firestore,
        _sessionService = sessionService ?? UserSessionService();

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'USERS';

  CustomerModel? _currentCustomer;
  bool _isLoading = false;
  String? _errorMessage;

  CustomerModel? get currentCustomer => _currentCustomer;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isRegistered => _currentCustomer != null;
  bool get isApproved => _currentCustomer?.isApproved ?? false;
  bool get isPending => _currentCustomer?.isPending ?? false;
  bool get isRejected => _currentCustomer?.isRejected ?? false;

  /// Initialize and restore customer session on launch
  Future<void> initSession() async {
    try {
      _currentCustomer = await _sessionService.getCustomerSession();
      notifyListeners();

      // If user was previously registered, refresh status from Firestore
      if (_currentCustomer != null) {
        await refreshApprovalStatus();
      }
    } catch (e) {
      debugPrint('UserAuthProvider.initSession error: $e');
    }
  }

  /// Register customer profile with Name and Phone Number (Awaiting Admin Approval)
  Future<bool> registerCustomer({
    required String name,
    required String phoneNumber,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phoneNumber.trim();

    if (cleanName.isEmpty || cleanPhone.isEmpty) {
      _errorMessage = 'Name and phone number are required.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docId = 'USR${DateTime.now().millisecondsSinceEpoch}';
      final newCustomer = CustomerModel(
        id: docId,
        name: cleanName,
        phoneNumber: cleanPhone,
        status: 'PENDING',
        requestedAt: DateTime.now(),
      );

      await _firestore
          .collection(collectionName)
          .doc(docId)
          .set(newCustomer.toMap())
          .timeout(const Duration(seconds: 10));

      _currentCustomer = newCustomer;
      await _sessionService.saveCustomerSession(newCustomer);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UserAuthProvider.registerCustomer error: $e');
      _errorMessage = 'Failed to submit registration: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Synchronize active customer approval status from Firestore
  Future<bool> refreshApprovalStatus() async {
    if (_currentCustomer == null) return false;

    try {
      final doc = await _firestore
          .collection(collectionName)
          .doc(_currentCustomer!.id)
          .get()
          .timeout(const Duration(seconds: 8));

      if (doc.exists) {
        final updated = CustomerModel.fromFirestore(doc);
        if (updated.status != _currentCustomer!.status) {
          _currentCustomer = updated;
          await _sessionService.saveCustomerSession(updated);
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('UserAuthProvider.refreshApprovalStatus error: $e');
    }
    return false;
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
