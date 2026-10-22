import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';

/// Provider managing customer account review, approvals, and rejections in the Admin Portal.
class CustomerManagementProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;

  CustomerManagementProvider({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'USERS';

  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<CustomerModel> get pendingCustomers =>
      _customers.where((c) => c.isPending).toList();

  int get pendingCount => pendingCustomers.length;

  /// Fetch all registered customers
  Future<void> fetchCustomers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .get()
          .timeout(const Duration(seconds: 10));

      _customers = snapshot.docs.map((doc) => CustomerModel.fromFirestore(doc)).toList();

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
      await _firestore
          .collection(collectionName)
          .doc(customerId)
          .update({
            'STATUS': 'APPROVED',
            'APPROVED_AT': Timestamp.fromDate(now),
            'APPROVED_BY_ADMIN_ID': adminId,
            'UPDATED_AT': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 8));

      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        _customers[index] = _customers[index].copyWith(
          status: 'APPROVED',
          approvedAt: now,
        );
        notifyListeners();
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
      await _firestore
          .collection(collectionName)
          .doc(customerId)
          .update({
            'STATUS': 'REJECTED',
            'REJECTION_REASON': reason ?? 'Account request could not be verified.',
            'UPDATED_AT': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 8));

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
}
