import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../utils/phone_helper.dart';

/// Provider managing customer account review, approvals, and rejections in the Admin Portal.
class CustomerManagementProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;

  CustomerManagementProvider({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

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

  /// Start real-time Firestore listener for customer requests
  void listenToCustomers() {
    _customersSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _customersSubscription =
          _firestore.collection(collectionName).snapshots().listen(
        (snapshot) {
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
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('CustomerManagementProvider.listenToCustomers error: $e');
      _isLoading = false;
      notifyListeners();
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

  /// Update customer password by administrator
  Future<bool> updateCustomerPassword(
      String customerId, String newPassword) async {
    final cleanPass = newPassword.trim();
    if (cleanPass.length < 6) {
      _errorMessage = 'Password must be at least 6 characters.';
      notifyListeners();
      return false;
    }

    try {
      await _firestore.collection(collectionName).doc(customerId).update({
        'PASSWORD': cleanPass,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));

      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        _customers[index] = _customers[index].copyWith(password: cleanPass);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('CustomerManagementProvider.updateCustomerPassword error: $e');
      _errorMessage = 'Failed to update password: $e';
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
    } else if (cleanPassword.length < 6) {
      _errorMessage = 'Password must be at least 6 characters.';
    }
    if (_errorMessage != null) {
      notifyListeners();
      return null;
    }

    final docId = PhoneHelper.toDocId(cleanPhone);
    final docRef = _firestore.collection(collectionName).doc(docId);
    final now = DateTime.now();
    final customer = CustomerModel(
      id: docId,
      name: cleanName,
      phoneNumber: cleanPhone,
      status: 'APPROVED',
      requestedAt: now,
      approvedAt: now,
      password: cleanPassword,
    );

    try {
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
