import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../services/user_session_service.dart';
import '../utils/phone_helper.dart';

/// Result outcome of customer registration or lookup
enum CustomerRegistrationResult {
  newRequestSubmitted, // New request created and pending admin approval
  alreadyPending,      // Mobile number is already in database pending approval
  alreadyApproved,     // Mobile number is already approved (auto logged in)
  alreadyRejected,     // Mobile number was previously rejected
  invalidPhone,        // Not a valid 10-digit Indian phone number
  error,               // Firestore or connectivity error
}

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

  /// Register customer profile or detect existing mobile number status.
  /// Enforces mandatory 10-digit Indian mobile number validation and
  /// guarantees single-record uniqueness via 'USR_91{10digit}' document ID.
  Future<CustomerRegistrationResult> registerCustomer({
    required String name,
    required String phoneNumber,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = PhoneHelper.extract10Digits(phoneNumber);

    if (cleanName.isEmpty) {
      _errorMessage = 'Full name is required.';
      notifyListeners();
      return CustomerRegistrationResult.error;
    }

    if (!PhoneHelper.isValidIndianNumber(cleanPhone)) {
      _errorMessage = 'Please enter a valid 10-digit Indian mobile number.';
      notifyListeners();
      return CustomerRegistrationResult.invalidPhone;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docId = PhoneHelper.toDocId(cleanPhone);
      final docRef = _firestore.collection(collectionName).doc(docId);

      // 1. Direct O(1) lookup to check if this 10-digit number already exists
      final existingDoc = await docRef.get().timeout(const Duration(seconds: 8));

      if (existingDoc.exists) {
        final existingCustomer = CustomerModel.fromFirestore(existingDoc);
        _currentCustomer = existingCustomer;
        await _sessionService.saveCustomerSession(existingCustomer);

        _isLoading = false;
        notifyListeners();

        if (existingCustomer.isPending) {
          return CustomerRegistrationResult.alreadyPending;
        } else if (existingCustomer.isApproved) {
          return CustomerRegistrationResult.alreadyApproved;
        } else if (existingCustomer.isRejected) {
          return CustomerRegistrationResult.alreadyRejected;
        }
      }

      // 2. If no record exists, create new PENDING approval request
      final now = DateTime.now();
      final newCustomer = CustomerModel(
        id: docId,
        name: cleanName,
        phoneNumber: cleanPhone,
        status: 'PENDING',
        requestedAt: now,
      );

      final map = newCustomer.toMap();
      map['NORMALIZED_PHONE'] = PhoneHelper.normalizeTo91(cleanPhone);
      map['DISPLAY_PHONE'] = PhoneHelper.formatForDisplay(cleanPhone);

      await docRef.set(map).timeout(const Duration(seconds: 10));

      _currentCustomer = newCustomer;
      await _sessionService.saveCustomerSession(newCustomer);

      _isLoading = false;
      notifyListeners();
      return CustomerRegistrationResult.newRequestSubmitted;
    } catch (e) {
      debugPrint('UserAuthProvider.registerCustomer error: $e');
      _errorMessage = 'Failed to submit registration: $e';
      _isLoading = false;
      notifyListeners();
      return CustomerRegistrationResult.error;
    }
  }

  /// Re-apply for approval if previously rejected
  Future<bool> reapplyRegistration() async {
    if (_currentCustomer == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      await _firestore
          .collection(collectionName)
          .doc(_currentCustomer!.id)
          .update({
            'STATUS': 'PENDING',
            'REQUESTED_AT': Timestamp.fromDate(now),
            'REJECTION_REASON': null,
            'UPDATED_AT': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 8));

      _currentCustomer = _currentCustomer!.copyWith(
        status: 'PENDING',
        requestedAt: now,
        rejectionReason: null,
      );
      await _sessionService.saveCustomerSession(_currentCustomer!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UserAuthProvider.reapplyRegistration error: $e');
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

  /// Clear session (for testing or switching account)
  Future<void> logout() async {
    _currentCustomer = null;
    await _sessionService.clearCustomerSession();
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
