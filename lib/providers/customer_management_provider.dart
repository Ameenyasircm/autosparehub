import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/phone_helper.dart';

/// Provider managing customer account review, approvals, and rejections in the Admin Portal.
class CustomerManagementProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;
  final AuthService _authService;

  CustomerManagementProvider({FirebaseFirestore? firestore, AuthService? authService})
      : _customFirestore = firestore,
        _authService = authService ?? AuthService(firestore: firestore);

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'USERS';

  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _customersSubscription;

  List<CustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<CustomerModel> get pendingCustomers =>
      _customers.where((c) => c.isPending).toList();

  int get pendingCount => pendingCustomers.length;

  @visibleForTesting
  void setCustomersForTesting(List<CustomerModel> list) {
    _customers = List.from(list);
    _isLoading = false;
    notifyListeners();
  }

  /// Start real-time Firestore listener for customer requests.
  /// After the first load, shows a local notification on the admin device
  /// whenever a customer registers (or re-applies after rejection) and is
  /// waiting for approval. Calling it again while already listening keeps
  /// the existing listener, so no alerts are missed or repeated.
  void listenToCustomers() {
    if (_customersSubscription != null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    var isInitialLoad = true;
    try {
      _customersSubscription =
          _firestore.collection(collectionName).snapshots().listen(
        (snapshot) {
          if (!isInitialLoad) _alertNewPendingCustomers(snapshot);
          isInitialLoad = false;

          _customers = snapshot.docs
              .map((doc) => CustomerModel.fromFirestore(doc))
              .toList();
          _customers.sort((a, b) {
            if (a.requestedAt != null && b.requestedAt != null) {
              return b.requestedAt!.compareTo(a.requestedAt!);
            }
            return b.id.compareTo(a.id);
          });
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('CustomerManagementProvider stream error: $e');
          _errorMessage = 'Failed to load customers: $e';
          _isLoading = false;
          _customersSubscription = null; // allow listenToCustomers() to retry
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('CustomerManagementProvider.listenToCustomers error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Notifies for customers that just became PENDING: new registrations, and
  /// rejected customers who re-applied. Admin-created customers are already
  /// approved, so they never trigger this.
  void _alertNewPendingCustomers(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final previousStatus = {for (final c in _customers) c.id: c.status};
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;
      try {
        final customer = CustomerModel.fromFirestore(change.doc);
        if (!customer.isPending) continue;
        final wasPending = previousStatus[customer.id] == 'PENDING';
        if (wasPending) continue;
        final reapplied = previousStatus[customer.id] != null;
        NotificationService.instance.showNotification(
          title: reapplied ? 'Customer Re-applied' : 'New Customer Registration',
          body: '${customer.name} (${PhoneHelper.formatForDisplay(customer.phoneNumber)}) '
              'is waiting for approval.',
          payload: customer.id,
        );
      } catch (e) {
        debugPrint('CustomerManagementProvider: new customer alert error: $e');
      }
    }
  }

  /// Fetch all registered customers once (for pull-to-refresh)
  Future<void> fetchCustomers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .get()
          .timeout(const Duration(seconds: 10));

      _customers =
          snapshot.docs.map((doc) => CustomerModel.fromFirestore(doc)).toList();

      // Sort newest request first
      _customers.sort((a, b) {
        if (a.requestedAt != null && b.requestedAt != null) {
          return b.requestedAt!.compareTo(a.requestedAt!);
        }
        return b.id.compareTo(a.id);
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('CustomerManagementProvider.fetchCustomers error: $e');
      _errorMessage = 'Failed to load customers: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approve customer account allowing order placement
  Future<bool> approveCustomer(String customerId, {String? adminId}) async {
    try {
      final now = DateTime.now();
      await _firestore.collection(collectionName).doc(customerId).update({
        'STATUS': 'APPROVED',
        'APPROVED_AT': Timestamp.fromDate(now),
        'APPROVED_BY_ADMIN_ID': adminId,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));

      final index = _customers.indexWhere((c) => c.id == customerId);
      CustomerModel? targetCustomer;
      if (index != -1) {
        targetCustomer = _customers[index];
        _customers[index] = _customers[index].copyWith(
          status: 'APPROVED',
          approvedAt: now,
        );
        notifyListeners();
      }

      // Record system notification for User & Cloud Functions/FCM trigger
      try {
        await _firestore.collection('NOTIFICATIONS').add({
          'RECIPIENT_ID': customerId,
          'RECIPIENT_TYPE': 'USER',
          'TITLE': 'Account Approved! 🎉',
          'BODY':
              'Your garage account has been approved by the administrator. You can now place orders.',
          'TYPE': 'ACCOUNT_APPROVED',
          'IS_READ': false,
          'FCM_TOKEN': targetCustomer?.fcmToken,
          'CREATED_AT': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint(
            'CustomerManagementProvider: Failed to write notification record: $e');
      }

      return true;
    } catch (e) {
      debugPrint('CustomerManagementProvider.approveCustomer error: $e');
      return false;
    }
  }

  /// Reject customer registration request
  Future<bool> rejectCustomer(String customerId, {String? reason}) async {
    try {
      await _firestore.collection(collectionName).doc(customerId).update({
        'STATUS': 'REJECTED',
        'REJECTION_REASON': reason ?? 'Account request could not be verified.',
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));

      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        _customers[index] = _customers[index].copyWith(
          status: 'REJECTED',
          rejectionReason: reason,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('CustomerManagementProvider.rejectCustomer error: $e');
      return false;
    }
  }

  /// Sets a new password for a customer (admin "reset password").
  ///
  /// Firebase Auth does not let one user change another user's password from
  /// the app, so a fresh sign-in account is created with the new password and
  /// the customer record is pointed at it. The old sign-in stops working at
  /// once, because the rules only accept the uid stored in AUTH_UID.
  Future<bool> updateCustomerPassword(
      String customerId, String newPassword) async {
    final cleanPass = newPassword.trim();
    if (cleanPass.length < AuthService.minPasswordLength) {
      _errorMessage = 'Password must be at least ${AuthService.minPasswordLength} characters.';
      notifyListeners();
      return false;
    }

    try {
      final docRef = _firestore.collection(collectionName).doc(customerId);
      final doc = await docRef.get().timeout(const Duration(seconds: 8));
      if (!doc.exists) {
        _errorMessage = 'Customer not found.';
        notifyListeners();
        return false;
      }
      final phone = PhoneHelper.extract10Digits(CustomerModel.fromFirestore(doc).phoneNumber);
      if (!PhoneHelper.isValidIndianNumber(phone)) {
        _errorMessage = 'This customer has no valid mobile number.';
        notifyListeners();
        return false;
      }

      final email = AuthService.customerEmail(phone, suffix: AuthService.resetSuffix());
      final uid = await _authService.createAccountForOther(email: email, password: cleanPass);

      final batch = _firestore.batch();
      batch.update(docRef, {
        'AUTH_UID': uid,
        'PASSWORD': FieldValue.delete(), // remove any legacy plain-text value
        'UPDATED_AT': FieldValue.serverTimestamp(),
      });
      batch.set(
        _authService.loginIndexRef(AuthService.customerLoginKey(phone)),
        AuthService.loginIndexData(email),
      );
      await batch.commit().timeout(const Duration(seconds: 10));

      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        _customers[index] = _customers[index].copyWith(authUid: uid);
        notifyListeners();
      }
      return true;
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('CustomerManagementProvider.updateCustomerPassword error: $e');
      _errorMessage = 'Failed to update password. Please check your internet connection.';
      notifyListeners();
      return false;
    }
  }

  /// Creates an already-approved customer from the admin app (e.g. for a
  /// counter sale). Uses the same phone-based document ID as self
  /// registration, so a phone number can only exist once. The password lets
  /// the customer log in to the user app later.
  /// Returns the new customer, or null with [errorMessage] set.
  Future<CustomerModel?> addCustomerByAdmin({
    required String name,
    required String phone,
    required String password,
    String? adminId,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = PhoneHelper.extract10Digits(phone);
    final cleanPassword = password.trim();
    _errorMessage = null;

    if (cleanName.isEmpty) {
      _errorMessage = 'Customer name is required.';
    } else if (!PhoneHelper.isValidIndianNumber(cleanPhone)) {
      _errorMessage = 'Enter a valid 10-digit mobile number.';
    } else if (cleanPassword.length < AuthService.minPasswordLength) {
      _errorMessage = 'Password must be at least ${AuthService.minPasswordLength} characters.';
    }
    if (_errorMessage != null) {
      notifyListeners();
      return null;
    }

    final docId = PhoneHelper.toDocId(cleanPhone);
    final docRef = _firestore.collection(collectionName).doc(docId);
    final now = DateTime.now();
    try {
      // Check first, so no sign-in account is created for a duplicate.
      final existing = await docRef.get().timeout(const Duration(seconds: 8));
      if (existing.exists) {
        final current = CustomerModel.fromFirestore(existing);
        _errorMessage = 'This number is already registered to ${current.name} '
            '(${current.status.toLowerCase()}).';
        notifyListeners();
        return null;
      }

      // Sign-in account for the customer (the admin stays signed in).
      final account = await _authService.createAccountWithFallback(
        emailFor: (suffix) => AuthService.customerEmail(cleanPhone, suffix: suffix),
        password: cleanPassword,
      );

      final customer = CustomerModel(
        id: docId,
        name: cleanName,
        phoneNumber: cleanPhone,
        status: 'APPROVED',
        requestedAt: now,
        approvedAt: now,
        authUid: account.uid,
      );

      // Returns an error message instead of throwing, because errors thrown
      // inside a transaction can come back wrapped by the plugin.
      final duplicateError = await _firestore.runTransaction<String?>((tx) async {
        final existing = await tx.get(docRef);
        if (existing.exists) {
          final current = CustomerModel.fromFirestore(existing);
          return 'This number is already registered to ${current.name} '
              '(${current.status.toLowerCase()}).';
        }
        final map = customer.toMap();
        map['NORMALIZED_PHONE'] = PhoneHelper.normalizeTo91(cleanPhone);
        map['DISPLAY_PHONE'] = PhoneHelper.formatForDisplay(cleanPhone);
        map['APPROVED_BY_ADMIN_ID'] = adminId;
        map['CREATED_BY_ADMIN'] = true;
        tx.set(docRef, map);
        tx.set(
          _authService.loginIndexRef(AuthService.customerLoginKey(cleanPhone)),
          AuthService.loginIndexData(account.email),
        );
        return null;
      }).timeout(const Duration(seconds: 10));

      if (duplicateError != null) {
        _errorMessage = duplicateError;
        notifyListeners();
        return null;
      }

      if (!_customers.any((c) => c.id == docId)) {
        _customers.insert(0, customer);
      }
      notifyListeners();
      return customer;
    } on TimeoutException {
      _errorMessage = 'Connection timed out. Please check your internet and try again.';
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      debugPrint('CustomerManagementProvider.addCustomerByAdmin error: $e');
      _errorMessage = 'Failed to create customer: $e';
    }
    notifyListeners();
    return null;
  }

  @override
  void dispose() {
    _customersSubscription?.cancel();
    super.dispose();
  }
}
