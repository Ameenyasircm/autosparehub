import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/notification_service.dart';

enum OrderDateFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  particularDate,
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
  bool _isCustomerOrdersLoading = false;
  bool _isPlacingOrder = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _adminOrdersSubscription;
  bool _isInitialAdminStreamLoad = true;

  String _statusFilter = 'ALL'; // ALL, PENDING, CONFIRMED, DISPATCHED, DELIVERED, CANCELLED
  OrderDateFilter _dateFilter = OrderDateFilter.all;
  DateTimeRange? _customDateRange;
  DateTime? _particularDate;
  String _customerFilter = '';
  String _categoryFilter = 'ALL';

  // Getters
  List<OrderModel> get adminOrders => _adminOrders;
  List<OrderModel> get customerOrders {
    final seen = <String>{};
    final list = <OrderModel>[];
    for (final o in _customerOrders) {
      final key = o.id.isNotEmpty ? o.id : o.orderNumber;
      if (seen.add(key)) {
        list.add(o);
      }
    }
    return list;
  }
  bool get isLoading => _isLoading;
  bool get isCustomerOrdersLoading => _isCustomerOrdersLoading;
  bool get isPlacingOrder => _isPlacingOrder;
  String? get errorMessage => _errorMessage;
  String get statusFilter => _statusFilter;
  OrderDateFilter get dateFilter => _dateFilter;
  DateTimeRange? get customDateRange => _customDateRange;
  DateTime? get particularDate => _particularDate;
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
        case OrderDateFilter.particularDate:
          if (_particularDate == null) return true;
          return createdAt.year == _particularDate!.year &&
              createdAt.month == _particularDate!.month &&
              createdAt.day == _particularDate!.day;
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

  void setDateFilter(OrderDateFilter filter, {DateTimeRange? customRange, DateTime? particularDate}) {
    _dateFilter = filter;
    _customDateRange = customRange;
    _particularDate = particularDate;
    notifyListeners();
  }

  void setParticularDate(DateTime? date) {
    if (date == null) {
      _dateFilter = OrderDateFilter.all;
      _particularDate = null;
    } else {
      _dateFilter = OrderDateFilter.particularDate;
      _particularDate = DateTime(date.year, date.month, date.day);
      _customDateRange = null;
    }
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
    _particularDate = null;
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
        refNo: product.productCode,
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

      // Broadcast order notification to all administrators
      _notifyAdminsOfNewOrder(order);

      _customerOrders.removeWhere((o) => o.id == order.id || o.orderNumber == order.orderNumber);
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
          refNo: p.productCode,
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

      // Broadcast order notification to all administrators
      _notifyAdminsOfNewOrder(order);

      _customerOrders.removeWhere((o) => o.id == order.id || o.orderNumber == order.orderNumber);
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
  Future<void> fetchCustomerOrders(String userId, {String? userPhone}) async {
    if (userId.isEmpty && (userPhone == null || userPhone.isEmpty)) return;

    _isCustomerOrdersLoading = true;
    notifyListeners();

    try {
      final Map<String, OrderModel> orderMap = {};

      if (userId.isNotEmpty) {
        final snapshot = await _firestore
            .collection(collectionName)
            .where('USER_ID', isEqualTo: userId)
            .get()
            .timeout(const Duration(seconds: 10));

        for (final doc in snapshot.docs) {
          final order = OrderModel.fromFirestore(doc);
          final key = order.id.isNotEmpty ? order.id : order.orderNumber;
          orderMap[key] = order;
        }
      }

      // Also if userPhone is provided, fetch by phone in case order was placed with phone or legacy doc
      if (userPhone != null && userPhone.isNotEmpty) {
        final phoneSnapshot = await _firestore
            .collection(collectionName)
            .where('USER_PHONE', isEqualTo: userPhone)
            .get()
            .timeout(const Duration(seconds: 10));

        for (final doc in phoneSnapshot.docs) {
          final order = OrderModel.fromFirestore(doc);
          final key = order.id.isNotEmpty ? order.id : order.orderNumber;
          orderMap[key] = order;
        }
      }

      final list = orderMap.values.toList();
      list.sort((a, b) {
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return b.id.compareTo(a.id);
      });
      _customerOrders = list;
    } catch (e) {
      debugPrint('OrderProvider.fetchCustomerOrders error: $e');
    } finally {
      _isCustomerOrdersLoading = false;
      notifyListeners();
    }
  }

  // --- Live customer orders (user app) ---
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _customerOrderSubs = [];
  String? _listeningCustomerKey;
  Map<String, OrderModel> _ordersById = {};
  Map<String, OrderModel> _ordersByPhone = {};

  /// Keeps the customer's orders in sync in real time, so status changes,
  /// remarks and sales made by the admin show up immediately. Listens by
  /// user ID and by phone (older orders) and merges both without duplicates.
  /// Calling it again for the same customer keeps the existing listeners.
  void listenToCustomerOrders(String userId, {String? userPhone}) {
    if (userId.isEmpty && (userPhone == null || userPhone.isEmpty)) return;
    final key = '$userId|${userPhone ?? ''}';
    if (_listeningCustomerKey == key && _customerOrderSubs.isNotEmpty) return;

    _stopCustomerOrderListeners();
    _listeningCustomerKey = key;
    if (_customerOrders.isEmpty) {
      _isCustomerOrdersLoading = true;
      notifyListeners();
    }

    void listen(Query<Map<String, dynamic>> query, void Function(Map<String, OrderModel>) assign) {
      _customerOrderSubs.add(query.snapshots().listen(
        (snapshot) {
          final map = <String, OrderModel>{};
          for (final doc in snapshot.docs) {
            final order = OrderModel.fromFirestore(doc);
            map[order.id.isNotEmpty ? order.id : order.orderNumber] = order;
          }
          assign(map);
          _rebuildCustomerOrders();
        },
        onError: (e) {
          debugPrint('OrderProvider.listenToCustomerOrders error: $e');
          _isCustomerOrdersLoading = false;
          notifyListeners();
        },
      ));
    }

    try {
      final orders = _firestore.collection(collectionName);
      if (userId.isNotEmpty) {
        listen(orders.where('USER_ID', isEqualTo: userId), (m) => _ordersById = m);
      }
      if (userPhone != null && userPhone.isNotEmpty) {
        listen(orders.where('USER_PHONE', isEqualTo: userPhone), (m) => _ordersByPhone = m);
      }
    } catch (e) {
      debugPrint('OrderProvider.listenToCustomerOrders init error: $e');
      _isCustomerOrdersLoading = false;
      notifyListeners();
    }
  }

  void _rebuildCustomerOrders() {
    // Same order can match both queries; the map key removes duplicates.
    final merged = {..._ordersByPhone, ..._ordersById};
    final list = merged.values.toList()
      ..sort((a, b) {
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return b.id.compareTo(a.id);
      });
    _customerOrders = list;
    _isCustomerOrdersLoading = false;
    notifyListeners();
  }

  void _stopCustomerOrderListeners() {
    for (final sub in _customerOrderSubs) {
      sub.cancel();
    }
    _customerOrderSubs.clear();
    _listeningCustomerKey = null;
    _ordersById = {};
    _ordersByPhone = {};
  }

  /// Clear customer orders on logout or switching accounts
  void clearCustomerOrders() {
    _stopCustomerOrderListeners();
    _customerOrders = [];
    _isCustomerOrdersLoading = false;
    notifyListeners();
  }

  /// Populate customer orders for testing
  void setCustomerOrdersForTesting(List<OrderModel> orders) {
    _customerOrders = List.from(orders);
    notifyListeners();
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

  /// Notify all active system administrators when a customer places an order
  Future<void> _notifyAdminsOfNewOrder(OrderModel order) async {
    try {
      // 1. Fetch active admin documents to get their saved FCM IDs
      final adminSnapshot = await _firestore
          .collection('ADMINS')
          .where('IS_ACTIVE', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 8));

      final List<String> adminTokens = [];
      for (final doc in adminSnapshot.docs) {
        final data = doc.data();
        final token = (data['FCM_TOKEN'] ?? data['fcmToken'])?.toString().trim();
        if (token != null && token.isNotEmpty) {
          adminTokens.add(token);
        }
      }

      // 2. Persist order notification in NOTIFICATIONS collection for admin alerts / Cloud Functions
      await _firestore.collection('NOTIFICATIONS').add({
        'RECIPIENT_TYPE': 'ADMIN',
        'TYPE': 'NEW_ORDER',
        'TITLE': 'New Order Received! 🛒',
        'BODY': 'Order ${order.orderNumber} placed by ${order.userName} (${order.quantity} item${order.quantity > 1 ? 's' : ''}, ₹${order.totalAmount.toStringAsFixed(0)})',
        'ORDER_ID': order.id,
        'ORDER_NUMBER': order.orderNumber,
        'CUSTOMER_NAME': order.userName,
        'CUSTOMER_PHONE': order.userPhone,
        'TOTAL_AMOUNT': order.totalAmount,
        'ITEM_COUNT': order.quantity,
        'ADMIN_FCM_TOKENS': adminTokens,
        'IS_READ': false,
        'CREATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 6));

      debugPrint('OrderProvider: Notified admins of new order ${order.orderNumber}. Active admin tokens: ${adminTokens.length}');
    } catch (e) {
      debugPrint('OrderProvider._notifyAdminsOfNewOrder error: $e');
    }
  }

  /// Start real-time Firestore stream listener for Admin Orders.
  /// Automatically triggers audio/visual local notifications when new orders arrive
  /// and keeps the admin order dashboard updated in real-time.
  void startListeningAdminOrders() {
    _adminOrdersSubscription?.cancel();
    _isInitialAdminStreamLoad = true;

    try {
      _adminOrdersSubscription = _firestore
          .collection(collectionName)
          .snapshots()
          .listen((snapshot) {
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

        // If not the initial load, detect new orders added and display local notification
        if (!_isInitialAdminStreamLoad) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              try {
                final newOrder = OrderModel.fromFirestore(change.doc);
                NotificationService.instance.showNotification(
                  title: 'New Order Received! 🛒',
                  body: 'Order ${newOrder.orderNumber} placed by ${newOrder.userName} (₹${newOrder.totalAmount.toStringAsFixed(0)})',
                  payload: newOrder.id,
                );
              } catch (e) {
                debugPrint('Error triggering new order alert: $e');
              }
            }
          }
        }
        _isInitialAdminStreamLoad = false;
      }, onError: (e) {
        debugPrint('OrderProvider.startListeningAdminOrders stream error: $e');
      });
    } catch (e) {
      debugPrint('OrderProvider.startListeningAdminOrders error: $e');
    }
  }

  void stopListeningAdminOrders() {
    _adminOrdersSubscription?.cancel();
    _adminOrdersSubscription = null;
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopCustomerOrderListeners();
    _adminOrdersSubscription?.cancel();
    super.dispose();
  }
}
