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
  alreadyApproved,     // Mobile number is already approved
  alreadyRejected,     // Mobile number was previously rejected
  alreadyExists,       // Account already exists with this phone number
  invalidPhone,        // Not a valid 10-digit Indian phone number
  invalidPassword,     // Password too short or empty
  error,               // Firestore or connectivity error
}

/// Result outcome of customer login
enum CustomerLoginResult {
  approved,            // Login successful and account is admin-approved
  pendingApproval,     // Correct credentials, but account is still pending admin approval
  rejected,            // Account registration was rejected by admin
  userNotFound,        // No account found with given mobile number
  invalidPassword,     // Password mismatch
  invalidPhone,        // Not a valid mobile number
  error,               // Network or Firestore error
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
  bool _isSessionInitialized = false;
  String? _errorMessage;

  CustomerModel? get currentCustomer => _currentCustomer;
  bool get isLoading => _isLoading;
  bool get isSessionInitialized => _isSessionInitialized;
  String? get errorMessage => _errorMessage;

  bool get isRegistered => _currentCustomer != null;
  bool get isApproved => _currentCustomer?.isApproved ?? false;
  bool get isPending => _currentCustomer?.isPending ?? false;
  bool get isRejected => _currentCustomer?.isRejected ?? false;

  /// Initialize and restore customer session on launch
  Future<void> initSession() async {
    try {
      _currentCustomer = await _sessionService.getCustomerSession();

      // If user was previously registered, refresh status from Firestore
      if (_currentCustomer != null) {
        await refreshApprovalStatus();
      }
    } catch (e) {
      debugPrint('UserAuthProvider.initSession error: $e');
    } finally {
      _isSessionInitialized = true;
      notifyListeners();
    }
  }

  /// Register customer profile with mandatory password.
  /// Enforces mandatory 10-digit Indian mobile number validation and
  /// guarantees single-record uniqueness via 'USR_91{10digit}' document ID.
  Future<CustomerRegistrationResult> registerCustomer({
    required String name,
    required String phoneNumber,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = PhoneHelper.extract10Digits(phoneNumber);
    final cleanPassword = password.trim();

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

    if (cleanPassword.length < 6) {
      _errorMessage = 'Password must be at least 6 characters.';
      notifyListeners();
      return CustomerRegistrationResult.invalidPassword;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docId = PhoneHelper.toDocId(cleanPhone);
      final docRef = _firestore.collection(collectionName).doc(docId);

      // 1. Direct lookup to check if this 10-digit number already exists
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
        return CustomerRegistrationResult.alreadyExists;
      }

      // 2. If no record exists, create new PENDING approval request with password
      final now = DateTime.now();
      final newCustomer = CustomerModel(
        id: docId,
        name: cleanName,
        phoneNumber: cleanPhone,
        password: cleanPassword,
        status: 'PENDING',
        requestedAt: now,
      );

      final map = newCustomer.toMap();
      map['PASSWORD'] = cleanPassword;
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

  /// Sign in customer using phone number and password.
  /// Checks whether customer has been approved by admin.
  Future<CustomerLoginResult> loginCustomer({
    required String phoneNumber,
    required String password,
  }) async {
    final cleanPhone = PhoneHelper.extract10Digits(phoneNumber);
    final cleanPassword = password.trim();

    if (!PhoneHelper.isValidIndianNumber(cleanPhone)) {
      _errorMessage = 'Please enter a valid 10-digit Indian mobile number.';
      notifyListeners();
      return CustomerLoginResult.invalidPhone;
    }

    if (cleanPassword.isEmpty) {
      _errorMessage = 'Password cannot be empty.';
      notifyListeners();
      return CustomerLoginResult.invalidPassword;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docId = PhoneHelper.toDocId(cleanPhone);
      final docRef = _firestore.collection(collectionName).doc(docId);
      final docSnapshot = await docRef.get().timeout(const Duration(seconds: 10));

      if (!docSnapshot.exists) {
        _isLoading = false;
        _errorMessage = 'No customer account found with this phone number. Please register.';
        notifyListeners();
        return CustomerLoginResult.userNotFound;
      }

      final data = docSnapshot.data() ?? {};
      final storedPassword = (data['PASSWORD'] ?? data['password'] ?? '').toString();

      if (storedPassword.isNotEmpty && storedPassword != cleanPassword) {
        _isLoading = false;
        _errorMessage = 'Incorrect password. Please try again or ask admin to reset.';
        notifyListeners();
        return CustomerLoginResult.invalidPassword;
      }

      final customer = CustomerModel.fromFirestore(docSnapshot);
      _currentCustomer = customer;
      await _sessionService.saveCustomerSession(customer);

      _isLoading = false;
      notifyListeners();

      if (customer.isPending) {
        return CustomerLoginResult.pendingApproval;
      } else if (customer.isRejected) {
        return CustomerLoginResult.rejected;
      }

      return CustomerLoginResult.approved;
    } catch (e) {
      debugPrint('UserAuthProvider.loginCustomer error: $e');
      _isLoading = false;
      _errorMessage = 'Login failed: $e';
      notifyListeners();
      return CustomerLoginResult.error;
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

  /// Update customer's own password from the user app.
  /// Validates that the customer is logged in, new password is >= 6 chars,
  /// verifies old password if previously set, updates Firestore USERS collection,
  /// and updates the active customer session.
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_currentCustomer == null) {
      _errorMessage = 'You must be signed in to change your password.';
      notifyListeners();
      return false;
    }

    final cleanOld = oldPassword.trim();
    final cleanNew = newPassword.trim();

    if (cleanNew.length < 6) {
      _errorMessage = 'New password must be at least 6 characters.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef = _firestore.collection(collectionName).doc(_currentCustomer!.id);
      final doc = await docRef.get().timeout(const Duration(seconds: 8));

      if (!doc.exists) {
        _errorMessage = 'User account not found.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final currentStoredPassword = data['PASSWORD']?.toString() ?? _currentCustomer!.password;

      // If a password was previously set on the account, verify oldPassword matches
      if (currentStoredPassword != null && currentStoredPassword.isNotEmpty) {
        if (currentStoredPassword != cleanOld) {
          _errorMessage = 'Current password is incorrect.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Update Firestore
      await docRef.update({
        'PASSWORD': cleanNew,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));

      // Update in-memory customer and persisted session
      _currentCustomer = _currentCustomer!.copyWith(password: cleanNew);
      await _sessionService.saveCustomerSession(_currentCustomer!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UserAuthProvider.changePassword error: $e');
      _errorMessage = 'Failed to update password. Please check your internet connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
