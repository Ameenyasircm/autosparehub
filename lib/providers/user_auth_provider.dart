import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/user_session_service.dart';
import '../utils/phone_helper.dart';

/// Result outcome of customer registration or lookup
enum CustomerRegistrationResult {
  newRequestSubmitted, // New request created and pending admin approval
  alreadyPending, // Mobile number is already in database pending approval
  alreadyApproved, // Mobile number is already approved
  alreadyRejected, // Mobile number was previously rejected
  alreadyExists, // Account already exists with this phone number
  invalidPhone, // Not a valid 10-digit Indian phone number
  invalidPassword, // Password too short or empty
  error, // Firestore or connectivity error
}

/// Result outcome of customer login
enum CustomerLoginResult {
  approved, // Login successful and account is admin-approved
  pendingApproval, // Correct credentials, but account is still pending admin approval
  rejected, // Account registration was rejected by admin
  userNotFound, // No account found with given mobile number
  invalidPassword, // Password mismatch
  invalidPhone, // Not a valid mobile number
  error, // Network or Firestore error
}

/// Result of the server-side check done right before placing an order.
enum OrderAccessResult {
  allowed,
  notLoggedIn,
  accountRemoved, // document deleted by the admin
  notApproved, // pending approval
  rejected,
  networkError, // could not reach the server to confirm
}

/// Provider managing customer registration, approval checking, and identity state.
class UserAuthProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;
  final UserSessionService _sessionService;
  final AuthService _authService;

  UserAuthProvider({
    FirebaseFirestore? firestore,
    UserSessionService? sessionService,
    AuthService? authService,
  })  : _customFirestore = firestore,
        _sessionService = sessionService ?? UserSessionService(),
        _authService = authService ?? AuthService(firestore: firestore);

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'USERS';

  CustomerModel? _currentCustomer;
  bool _isLoading = false;
  bool _isSessionInitialized = false;
  bool _shouldShowApprovalCelebration = false;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot>? _customerSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  CustomerModel? get currentCustomer => _currentCustomer;
  bool get isLoading => _isLoading;
  bool get isSessionInitialized => _isSessionInitialized;
  bool get shouldShowApprovalCelebration => _shouldShowApprovalCelebration;
  String? get errorMessage => _errorMessage;

  bool get isRegistered => _currentCustomer != null;
  bool get isApproved => _currentCustomer?.isApproved ?? false;
  bool get isPending => _currentCustomer?.isPending ?? false;
  bool get isRejected => _currentCustomer?.isRejected ?? false;

  /// Starts real-time Firestore listener on the customer profile document.
  /// Guarantees instant UI reactivity when an administrator approves/rejects the user,
  /// updating the drawer menu, badges, and ordering privileges in real time without page reload.
  void _startListeningToCustomer(String customerDocId) {
    _customerSubscription?.cancel();
    _customerSubscription = _firestore
        .collection(collectionName)
        .doc(customerDocId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) {
        // Deleted by the admin while logged in. Only trust the server here:
        // a missing document in the offline cache does not mean deleted.
        if (!snapshot.metadata.isFromCache) {
          await _handleAccountRemoved();
        }
        return;
      }
      try {
        final updated = CustomerModel.fromFirestore(snapshot);
        final bool wasNotApproved =
            _currentCustomer == null || !_currentCustomer!.isApproved;
        final bool becameApproved = wasNotApproved && updated.isApproved;

        _currentCustomer = updated;
        await _sessionService.saveCustomerSession(updated);

        if (becameApproved) {
          debugPrint(
              'UserAuthProvider: Customer $customerDocId is now APPROVED! Checking celebration notice.');
          final hasSeen =
              await _sessionService.hasSeenApprovalNotice(customerDocId);
          if (!hasSeen) {
            _shouldShowApprovalCelebration = true;
            await NotificationService.instance.showNotification(
              title: 'Account Approved! 🎉',
              body:
                  'Your garage account has been approved by the administrator. You can now place orders!',
            );
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('UserAuthProvider._startListeningToCustomer error: $e');
      }
    }, onError: (e) {
      debugPrint('UserAuthProvider customer stream error: $e');
      // The sign-in no longer owns this record (password reset by the store,
      // or signed out elsewhere): log out instead of showing stale data.
      if (e is FirebaseException && e.code == 'permission-denied') {
        _handleAccountRemoved();
      }
    });
  }

  /// Synchronize FCM Device Token to Firestore for Push Notifications
  Future<void> _syncFcmToken(String customerDocId) async {
    try {
      final token = await NotificationService.instance.getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection(collectionName).doc(customerDocId).update({
          'FCM_TOKEN': token,
          'FCM_UPDATED_AT': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
        debugPrint('User FCM Token synced to Firestore for $customerDocId');
      }

      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          NotificationService.instance.onTokenRefresh.listen((newToken) async {
        try {
          await _firestore
              .collection(collectionName)
              .doc(customerDocId)
              .update({
            'FCM_TOKEN': newToken,
            'FCM_UPDATED_AT': FieldValue.serverTimestamp(),
          });
          debugPrint(
              'User FCM Token refreshed in Firestore for $customerDocId');
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('UserAuthProvider._syncFcmToken error: $e');
    }
  }

  /// Initialize and restore customer session on launch
  Future<void> initSession() async {
    try {
      _currentCustomer = await _sessionService.getCustomerSession();

      // The saved profile is only a cache. Without a Firebase sign-in (e.g. a
      // session saved by an older app version) it is cleared.
      if (_currentCustomer != null && !await _authService.hasSignedInUser()) {
        await _sessionService.clearCustomerSession();
        _currentCustomer = null;
      }

      // If customer was already approved in previous launches, mark notice as seen
      // so normal app openings never trigger the celebration banner
      if (_currentCustomer != null && _currentCustomer!.isApproved) {
        await _sessionService.markApprovalNoticeSeen(_currentCustomer!.id);
      }

      // If user was previously registered, activate real-time listener and FCM sync
      if (_currentCustomer != null) {
        _startListeningToCustomer(_currentCustomer!.id);
        _syncFcmToken(_currentCustomer!.id);
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

    final docId = PhoneHelper.toDocId(cleanPhone);
    final docRef = _firestore.collection(collectionName).doc(docId);
    final email = AuthService.customerEmail(cleanPhone);

    try {
      // 1. Create the sign-in account. Firebase Auth guarantees one account
      //    per mobile number (the e-mail is derived from it).
      String uid;
      try {
        uid = await _authService.register(email: email, password: cleanPassword);
      } on AuthServiceException catch (e) {
        if (e.code != 'email-already-in-use') {
          _errorMessage = e.message;
          _isLoading = false;
          notifyListeners();
          return CustomerRegistrationResult.error;
        }
        // The number is already registered. If the password matches and an
        // earlier attempt never created the profile, finish it; otherwise
        // send the user to login.
        try {
          uid = await _authService.signIn(email: email, password: cleanPassword);
        } on AuthServiceException {
          _isLoading = false;
          _errorMessage = 'This mobile number is already registered. Please log in with your password.';
          notifyListeners();
          return CustomerRegistrationResult.alreadyExists;
        }
        final existing = await _readOwnProfile(docRef);
        if (existing != null) {
          await _authService.signOut();
          return _duplicateRegistration(existing);
        }
      }

      // 2. Create the PENDING profile. No password is stored in Firestore.
      final now = DateTime.now();
      final newCustomer = CustomerModel(
        id: docId,
        name: cleanName,
        phoneNumber: cleanPhone,
        status: 'PENDING',
        requestedAt: now,
        authUid: uid,
      );

      final map = newCustomer.toMap();
      map['NORMALIZED_PHONE'] = PhoneHelper.normalizeTo91(cleanPhone);
      map['DISPLAY_PHONE'] = PhoneHelper.formatForDisplay(cleanPhone);

      try {
        // The rules only allow creating a new record, never overwriting one.
        await docRef.set(map).timeout(const Duration(seconds: 10));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          // A record for this number already exists (e.g. created by the store).
          await _authService.deleteCurrentUserIfOwns(uid);
          _isLoading = false;
          _errorMessage = 'This mobile number is already registered. Please log in, '
              'or contact the store if you do not know the password.';
          notifyListeners();
          return CustomerRegistrationResult.alreadyExists;
        }
        rethrow;
      }

      // 3. Login lookup entry (phone -> sign-in e-mail).
      await _authService.writeOwnCustomerLoginIndex(cleanPhone, email);

      _currentCustomer = newCustomer;
      await _sessionService.saveCustomerSession(newCustomer);
      _startListeningToCustomer(docId);
      _syncFcmToken(docId);
      _notifyAdminsOfRegistration(newCustomer); // not awaited

      _isLoading = false;
      notifyListeners();
      return CustomerRegistrationResult.newRequestSubmitted;
    } catch (e) {
      debugPrint('UserAuthProvider.registerCustomer error: $e');
      _errorMessage = 'Failed to submit registration. Please check your internet connection and try again.';
      _isLoading = false;
      notifyListeners();
      return CustomerRegistrationResult.error;
    }
  }

  /// Reads the signed-in customer's own profile; null when it does not exist
  /// or belongs to a different sign-in.
  Future<CustomerModel?> _readOwnProfile(DocumentReference<Map<String, dynamic>> docRef) async {
    try {
      final doc = await docRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (!doc.exists) return null;
      return CustomerModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  CustomerRegistrationResult _duplicateRegistration(CustomerModel existing) {
    _isLoading = false;
    if (existing.isPending) {
      _errorMessage = 'This mobile number is already registered and waiting for '
          'approval. Please log in with your password to check the status.';
      notifyListeners();
      return CustomerRegistrationResult.alreadyPending;
    }
    if (existing.isRejected) {
      _errorMessage = 'This mobile number is already registered, but the request '
          'was not approved. Please contact the store.';
      notifyListeners();
      return CustomerRegistrationResult.alreadyRejected;
    }
    _errorMessage = existing.isApproved
        ? 'This mobile number is already registered. Please log in with your password.'
        : 'An account already exists for this mobile number. Please log in.';
    notifyListeners();
    return existing.isApproved
        ? CustomerRegistrationResult.alreadyApproved
        : CustomerRegistrationResult.alreadyExists;
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

      // 1. Find the sign-in e-mail for this number.
      final indexedEmail =
          await _authService.lookupEmail(AuthService.customerLoginKey(cleanPhone));
      final email = indexedEmail ?? AuthService.customerEmail(cleanPhone);

      // 2. Verify the password with Firebase Authentication.
      try {
        await _authService.signIn(email: email, password: cleanPassword);
      } on AuthServiceException catch (e) {
        _isLoading = false;
        final isCredentialError = e.code == 'invalid-credential' ||
            e.code == 'wrong-password' ||
            e.code == 'user-not-found';
        if (indexedEmail == null && isCredentialError) {
          _errorMessage = 'No customer account found with this phone number. Please register.';
          notifyListeners();
          return CustomerLoginResult.userNotFound;
        }
        _errorMessage = isCredentialError
            ? 'Incorrect password. Please try again or ask the store to reset it.'
            : e.message;
        notifyListeners();
        return CustomerLoginResult.invalidPassword;
      }

      // 3. Load the profile (the rules only return it to its owner).
      final docSnapshot = await docRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (!docSnapshot.exists) {
        await _authService.signOut();
        _isLoading = false;
        _errorMessage =
            'No customer account found with this phone number. Please register.';
        notifyListeners();
        return CustomerLoginResult.userNotFound;
      }

      final customer = CustomerModel.fromFirestore(docSnapshot);
      _currentCustomer = customer;
      await _sessionService.saveCustomerSession(customer);
      _startListeningToCustomer(customer.id);
      _syncFcmToken(customer.id);

      _isLoading = false;
      notifyListeners();

      if (customer.isPending) {
        return CustomerLoginResult.pendingApproval;
      } else if (customer.isRejected) {
        return CustomerLoginResult.rejected;
      }

      return CustomerLoginResult.approved;
    } on FirebaseException catch (e) {
      debugPrint('UserAuthProvider.loginCustomer FirebaseException [${e.code}]');
      await _authService.signOut();
      _isLoading = false;
      _errorMessage = e.code == 'permission-denied'
          ? 'This login is no longer valid. Please contact the store.'
          : 'Login failed. Please check your internet connection and try again.';
      notifyListeners();
      return CustomerLoginResult.error;
    } catch (e) {
      debugPrint('UserAuthProvider.loginCustomer error: $e');
      await _authService.signOut();
      _isLoading = false;
      _errorMessage = 'Login failed. Please check your internet connection and try again.';
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
      }).timeout(const Duration(seconds: 8));

      _currentCustomer = _currentCustomer!.copyWith(
        status: 'PENDING',
        requestedAt: now,
        rejectionReason: null,
      );
      await _sessionService.saveCustomerSession(_currentCustomer!);
      _notifyAdminsOfRegistration(_currentCustomer!, reapplied: true); // not awaited

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

  /// Records an admin alert for a customer waiting for approval, the same way
  /// new orders do (NOTIFICATIONS collection with active admins' FCM tokens),
  /// so a Cloud Function can push it. The admin app also shows a local
  /// notification from its live customer list. Failures are only logged.
  Future<void> _notifyAdminsOfRegistration(CustomerModel customer, {bool reapplied = false}) async {
    // Customers cannot read the ADMINS collection (it is admin-only), so
    // admin device tokens are not attached here.
    try {
      await _firestore.collection('NOTIFICATIONS').add({
        'RECIPIENT_TYPE': 'ADMIN',
        'TYPE': reapplied ? 'CUSTOMER_REAPPLIED' : 'NEW_CUSTOMER',
        'TITLE': reapplied ? 'Customer Re-applied' : 'New Customer Registration',
        'BODY': '${customer.name} (${PhoneHelper.formatForDisplay(customer.phoneNumber)}) '
            'is waiting for approval.',
        'CUSTOMER_ID': customer.id,
        'CUSTOMER_NAME': customer.name,
        'CUSTOMER_PHONE': customer.phoneNumber,
        'IS_READ': false,
        'CREATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('UserAuthProvider._notifyAdminsOfRegistration error: $e');
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
        final wasNotApproved = !_currentCustomer!.isApproved;
        if (updated.status != _currentCustomer!.status) {
          _currentCustomer = updated;
          await _sessionService.saveCustomerSession(updated);
          if (wasNotApproved && updated.isApproved) {
            final hasSeen =
                await _sessionService.hasSeenApprovalNotice(updated.id);
            if (!hasSeen) {
              _shouldShowApprovalCelebration = true;
            }
          }
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('UserAuthProvider.refreshApprovalStatus error: $e');
    }
    return false;
  }

  /// Consumes the one-time celebration trigger and persists the notice as displayed
  Future<void> consumeApprovalCelebration() async {
    _shouldShowApprovalCelebration = false;
    if (_currentCustomer != null) {
      await _sessionService.markApprovalNoticeSeen(_currentCustomer!.id);
    }
    notifyListeners();
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
      await _authService.changeOwnPassword(
        currentPassword: cleanOld,
        newPassword: cleanNew,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('UserAuthProvider.changePassword error: $e');
      _errorMessage =
          'Failed to update password. Please check your internet connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear session (for testing or switching account)
  /// Set when the account was removed/blocked and the customer was logged out
  /// automatically. The UI shows a message once and clears it.
  bool _accountRemovedNotice = false;
  bool get accountRemovedNotice => _accountRemovedNotice;
  void consumeAccountRemovedNotice() => _accountRemovedNotice = false;

  Future<void> _handleAccountRemoved() async {
    debugPrint('UserAuthProvider: customer account no longer exists, logging out.');
    _accountRemovedNotice = true;
    await logout();
  }

  /// Checks with the server (not the cached login) that the customer still
  /// exists and is approved, right before an order is submitted. Refreshes
  /// the cached customer; logs out if the account was deleted.
  Future<OrderAccessResult> verifyOrderAccess() async {
    final current = _currentCustomer;
    if (current == null) return OrderAccessResult.notLoggedIn;
    try {
      final doc = await _firestore
          .collection(collectionName)
          .doc(current.id)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));

      if (!doc.exists || doc.data() == null) {
        await _handleAccountRemoved();
        return OrderAccessResult.accountRemoved;
      }

      final updated = CustomerModel.fromFirestore(doc);
      _currentCustomer = updated;
      await _sessionService.saveCustomerSession(updated);
      notifyListeners();

      if (updated.isApproved) return OrderAccessResult.allowed;
      if (updated.isRejected) return OrderAccessResult.rejected;
      return OrderAccessResult.notApproved;
    } catch (e) {
      // Offline / timeout: cannot confirm access, so do not place the order.
      debugPrint('UserAuthProvider.verifyOrderAccess error: $e');
      return OrderAccessResult.networkError;
    }
  }

  Future<void> logout() async {
    _customerSubscription?.cancel();
    _customerSubscription = null;
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _currentCustomer = null;
    await _sessionService.clearCustomerSession();
    await _authService.signOut();
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Sets customer directly for unit and widget testing
  void setCustomerForTesting(CustomerModel customer) {
    _currentCustomer = customer;
    _isSessionInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _customerSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}
