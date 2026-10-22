import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

enum OrderDateFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  custom,
}

/// Provider managing customer orders, checkout placement, admin order streams,
/// and date / status filtering on the Admin Home dashboard.
class OrderProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;

  OrderProvider({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'ORDERS';

  List<OrderModel> _adminOrders = [];
  List<OrderModel> _customerOrders = [];
  bool _isLoading = false;
  bool _isPlacingOrder = false;
  String? _errorMessage;

  String _statusFilter = 'ALL'; // ALL, PENDING, CONFIRMED, DISPATCHED, DELIVERED, CANCELLED
  OrderDateFilter _dateFilter = OrderDateFilter.all;
  DateTimeRange? _customDateRange;

  // Getters
  List<OrderModel> get adminOrders => _adminOrders;
  List<OrderModel> get customerOrders => _customerOrders;
  bool get isLoading => _isLoading;
  bool get isPlacingOrder => _isPlacingOrder;
  String? get errorMessage => _errorMessage;
  String get statusFilter => _statusFilter;
  OrderDateFilter get dateFilter => _dateFilter;
  DateTimeRange? get customDateRange => _customDateRange;

  // Order Counts for metrics
  int get totalOrdersCount => _adminOrders.length;
  int get pendingOrdersCount => _adminOrders.where((o) => o.isPending).length;
  int get confirmedOrdersCount => _adminOrders.where((o) => o.isConfirmed).length;
  int get deliveredOrdersCount => _adminOrders.where((o) => o.isDelivered).length;

  /// Returns admin orders filtered by selected status and date range
  List<OrderModel> get filteredAdminOrders {
    final now = DateTime.now();

    return _adminOrders.where((order) {
      // 1. Status Filter
      if (_statusFilter != 'ALL' && order.status != _statusFilter) {
        return false;
      }

      // 2. Date Filter
      if (order.createdAt == null) return true;
      final createdAt = order.createdAt!;

      switch (_dateFilter) {
        case OrderDateFilter.all:
          return true;
        case OrderDateFilter.today:
          return createdAt.year == now.year &&
              createdAt.month == now.month &&
              createdAt.day == now.day;
        case OrderDateFilter.thisWeek:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final beginningOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          return createdAt.isAfter(beginningOfWeek);
        case OrderDateFilter.thisMonth:
          return createdAt.year == now.year && createdAt.month == now.month;
        case OrderDateFilter.custom:
          if (_customDateRange == null) return true;
          final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
          return createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
              createdAt.isBefore(end.add(const Duration(seconds: 1)));
      }
    }).toList();
  }

  void setStatusFilter(String status) {
    if (_statusFilter != status) {
      _statusFilter = status;
      notifyListeners();
    }
  }

  void setDateFilter(OrderDateFilter filter, {DateTimeRange? customRange}) {
    _dateFilter = filter;
    _customDateRange = customRange;
    notifyListeners();
  }

  /// Customer places a new order for a spare part
  Future<OrderModel?> placeOrder({
    required String userId,
    required String userName,
    required String userPhone,
    required ProductModel product,
    required int quantity,
    String? shippingAddress,
    String? customerNote,
  }) async {
    _isPlacingOrder = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final docId = 'ORD${now.millisecondsSinceEpoch}';
      final orderNumber = '#ORD-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
      final unitPrice = product.price ?? 0.0;
      final totalAmount = unitPrice * quantity;

      final order = OrderModel(
        id: docId,
        orderNumber: orderNumber,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        productId: product.id,
        productName: product.name,
        productImage: product.imageUrl,
        companyName: product.companyName,
        categoryName: product.categoryName,
        unitPrice: unitPrice,
        quantity: quantity,
        totalAmount: totalAmount,
        shippingAddress: shippingAddress?.trim(),
        customerNote: customerNote?.trim(),
        status: 'PENDING',
        createdAt: now,
      );

      await _firestore
          .collection(collectionName)
          .doc(docId)
          .set(order.toMap())
          .timeout(const Duration(seconds: 10));

      _customerOrders.insert(0, order);
      _isPlacingOrder = false;
      notifyListeners();
      return order;
    } catch (e) {
      debugPrint('OrderProvider.placeOrder error: $e');
      _errorMessage = 'Failed to place order: $e';
      _isPlacingOrder = false;
      notifyListeners();
      return null;
    }
  }

  /// Fetch orders placed by a specific customer
  Future<void> fetchCustomerOrders(String userId) async {
    if (userId.isEmpty) return;

    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('USER_ID', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 10));

      _customerOrders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      _customerOrders.sort((a, b) {
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return b.id.compareTo(a.id);
      });
      notifyListeners();
    } catch (e) {
      debugPrint('OrderProvider.fetchCustomerOrders error: $e');
    }
  }

  /// Fetch all orders for the Admin Dashboard
  Future<void> fetchAdminOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .get()
          .timeout(const Duration(seconds: 10));

      _adminOrders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();

      // Sort newest first
      _adminOrders.sort((a, b) {
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return b.id.compareTo(a.id);
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('OrderProvider.fetchAdminOrders error: $e');
      _errorMessage = 'Failed to load orders: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update order status (Admin operation: PENDING -> CONFIRMED -> DISPATCHED -> DELIVERED -> CANCELLED)
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(orderId)
          .update({
            'STATUS': newStatus,
            'UPDATED_AT': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 8));

      final index = _adminOrders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _adminOrders[index] = _adminOrders[index].copyWith(status: newStatus);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('OrderProvider.updateOrderStatus error: $e');
      return false;
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
