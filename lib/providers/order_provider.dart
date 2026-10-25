import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
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
/// and date, status, customer, and category filtering on the Admin Home dashboard.
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
  String _customerFilter = '';
  String _categoryFilter = 'ALL';

  // Getters
  List<OrderModel> get adminOrders => _adminOrders;
  List<OrderModel> get customerOrders => _customerOrders;
  bool get isLoading => _isLoading;
  bool get isPlacingOrder => _isPlacingOrder;
  String? get errorMessage => _errorMessage;
  String get statusFilter => _statusFilter;
  OrderDateFilter get dateFilter => _dateFilter;
  DateTimeRange? get customDateRange => _customDateRange;
  String get customerFilter => _customerFilter;
  String get categoryFilter => _categoryFilter;

  // Order Counts for metrics
  int get totalOrdersCount => _adminOrders.length;
  int get pendingOrdersCount => _adminOrders.where((o) => o.isPending).length;
  int get confirmedOrdersCount => _adminOrders.where((o) => o.isConfirmed).length;
  int get dispatchedOrdersCount => _adminOrders.where((o) => o.isDispatched).length;
  int get deliveredOrdersCount => _adminOrders.where((o) => o.isDelivered).length;
  int get cancelledOrdersCount => _adminOrders.where((o) => o.isCancelled).length;

  /// Returns admin orders filtered by status, date range, customer (name/phone), and category
  List<OrderModel> get filteredAdminOrders {
    final now = DateTime.now();

    return _adminOrders.where((order) {
      // 1. Status Filter
      if (_statusFilter != 'ALL' && order.status != _statusFilter) {
        return false;
      }

      // 2. Customer Filter (Customer name, mobile number, or order number)
      if (_customerFilter.isNotEmpty) {
        final query = _customerFilter.toLowerCase();
        final matchesName = order.userName.toLowerCase().contains(query);
        final matchesPhone = order.userPhone.contains(query);
        final matchesOrderNum = order.orderNumber.toLowerCase().contains(query);
        if (!matchesName && !matchesPhone && !matchesOrderNum) {
          return false;
        }
      }

      // 3. Category Filter
      if (_categoryFilter != 'ALL') {
        final matchesCategoryList = order.categoryNames.any(
          (c) => c.toLowerCase() == _categoryFilter.toLowerCase(),
        );
        final matchesRootCategory =
            order.categoryName.toLowerCase() == _categoryFilter.toLowerCase();
        final matchesAnyItem = order.items.any(
          (item) => item.categoryName.toLowerCase() == _categoryFilter.toLowerCase(),
        );

        if (!matchesCategoryList && !matchesRootCategory && !matchesAnyItem) {
          return false;
        }
      }

      // 4. Date Filter
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

  void setCustomerFilter(String query) {
    _customerFilter = query.trim();
    notifyListeners();
  }

  void setCategoryFilter(String categoryName) {
    _categoryFilter = categoryName;
    notifyListeners();
  }

  void resetAllFilters() {
    _statusFilter = 'ALL';
    _dateFilter = OrderDateFilter.all;
    _customDateRange = null;
    _customerFilter = '';
    _categoryFilter = 'ALL';
    notifyListeners();
  }

  /// Customer places a direct order for a single spare part (e.g. via "Buy Now")
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

      final item = OrderItemModel(
        productId: product.id,
        productName: product.name,
        productImage: product.imageUrl,
        companyName: product.companyName,
        categoryName: product.categoryName,
        refNo: product.refNo,
        unitPrice: unitPrice,
        quantity: quantity,
        totalPrice: totalAmount,
      );

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
        items: [item],
        categoryNames: [product.categoryName],
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

  /// Customer places an order from their shopping cart containing 1 or more items
  Future<OrderModel?> placeCartOrder({
    required String userId,
    required String userName,
    required String userPhone,
    required List<CartItemModel> cartItems,
    String? shippingAddress,
    String? customerNote,
  }) async {
    if (cartItems.isEmpty) {
      _errorMessage = 'Cannot place an empty order.';
      notifyListeners();
      return null;
    }

    _isPlacingOrder = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final docId = 'ORD${now.millisecondsSinceEpoch}';
      final orderNumber = '#ORD-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

      final items = cartItems.map((cartItem) {
        final p = cartItem.product;
        return OrderItemModel(
          productId: p.id,
          productName: p.name,
          productImage: p.imageUrl,
          companyName: p.companyName,
          categoryName: p.categoryName,
          refNo: p.refNo,
          unitPrice: p.price ?? 0.0,
          quantity: cartItem.quantity,
          totalPrice: cartItem.totalPrice,
        );
      }).toList();

      final totalAmount = items.fold<double>(0.0, (total, i) => total + i.totalPrice);
      final categoryNames = items.map((i) => i.categoryName).where((c) => c.isNotEmpty).toSet().toList();
      final totalQuantity = items.fold<int>(0, (total, i) => total + i.quantity);

      final order = OrderModel(
        id: docId,
        orderNumber: orderNumber,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        productId: items.first.productId,
        productName: items.length == 1 ? items.first.productName : '${items.first.productName} & ${items.length - 1} more',
        productImage: items.first.productImage,
        companyName: items.first.companyName,
        categoryName: items.first.categoryName,
        unitPrice: items.first.unitPrice,
        quantity: totalQuantity,
        totalAmount: totalAmount,
        shippingAddress: shippingAddress?.trim(),
        customerNote: customerNote?.trim(),
        status: 'PENDING',
        items: items,
        categoryNames: categoryNames,
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
      debugPrint('OrderProvider.placeCartOrder error: $e');
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

  /// Update order status with optional remark (Admin operation)
  Future<bool> updateOrderStatus(String orderId, String newStatus, {String? adminRemark}) async {
    try {
      final Map<String, dynamic> updateData = {
        'STATUS': newStatus,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      };
      if (adminRemark != null) {
        updateData['ADMIN_REMARK'] = adminRemark.trim();
      }

      await _firestore
          .collection(collectionName)
          .doc(orderId)
          .update(updateData)
          .timeout(const Duration(seconds: 8));

      final index = _adminOrders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _adminOrders[index] = _adminOrders[index].copyWith(
          status: newStatus,
          adminRemark: adminRemark?.trim() ?? _adminOrders[index].adminRemark,
        );
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
