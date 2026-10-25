import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_spare_hub/models/cart_item_model.dart';
import 'package:auto_spare_hub/models/order_model.dart';
import 'package:auto_spare_hub/models/product_model.dart';
import 'package:auto_spare_hub/providers/cart_provider.dart';
import 'package:auto_spare_hub/providers/order_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleProduct1 = ProductModel(
    id: 'PRD001',
    name: 'Power Steering Pump',
    companyId: 'CMP01',
    companyName: 'Toyota',
    categoryId: 'CAT01',
    categoryName: 'Steering & Suspension',
    application: 'Toyota Hilux Vigo 2012-2016',
    price: 4500.0,
    imageUrl: 'https://img.com/pump.jpg',
    refNo: '44310-0K040',
    isActive: true,
  );

  final sampleProduct2 = ProductModel(
    id: 'PRD002',
    name: 'Brake Disc Rotor',
    companyId: 'CMP02',
    companyName: 'Honda',
    categoryId: 'CAT02',
    categoryName: 'Braking System',
    application: 'Honda Civic 2016-2021',
    price: 2200.0,
    imageUrl: 'https://img.com/disc.jpg',
    refNo: '45251-SM4-000',
    isActive: true,
  );

  group('CartItemModel Tests', () {
    test('computes line item subtotal correctly', () {
      final cartItem = CartItemModel(product: sampleProduct1, quantity: 3);
      expect(cartItem.totalPrice, 13500.0);
    });

    test('serializes toMap and deserializes fromMap', () {
      final cartItem = CartItemModel(product: sampleProduct1, quantity: 2);
      final map = cartItem.toMap();

      expect(map['quantity'], 2);
      expect(map['product'], isA<Map>());

      final restored = CartItemModel.fromMap(map);
      expect(restored.product.id, 'PRD001');
      expect(restored.product.name, 'Power Steering Pump');
      expect(restored.quantity, 2);
      expect(restored.totalPrice, 9000.0);
    });
  });

  group('CartProvider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts empty and adds items correctly', () async {
      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cart.isEmpty, isTrue);
      expect(cart.totalItemCount, 0);
      expect(cart.subtotalAmount, 0.0);

      await cart.addToCart(sampleProduct1, quantity: 2);
      expect(cart.items.length, 1);
      expect(cart.totalItemCount, 2);
      expect(cart.subtotalAmount, 9000.0);
      expect(cart.isInCart('PRD001'), isTrue);

      // Adding the same item increments quantity
      await cart.addToCart(sampleProduct1, quantity: 1);
      expect(cart.items.length, 1);
      expect(cart.totalItemCount, 3);
      expect(cart.subtotalAmount, 13500.0);

      // Adding distinct product
      await cart.addToCart(sampleProduct2, quantity: 1);
      expect(cart.items.length, 2);
      expect(cart.distinctItemCount, 2);
      expect(cart.totalItemCount, 4);
      expect(cart.subtotalAmount, 15700.0);
    });

    test('stepper increment, decrement, and removal', () async {
      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      await cart.addToCart(sampleProduct1, quantity: 2);
      await cart.incrementQuantity('PRD001');
      expect(cart.getQuantity('PRD001'), 3);

      await cart.decrementQuantity('PRD001');
      expect(cart.getQuantity('PRD001'), 2);

      // Decrementing to 0 removes product
      await cart.decrementQuantity('PRD001');
      await cart.decrementQuantity('PRD001');
      expect(cart.isInCart('PRD001'), isFalse);
      expect(cart.isEmpty, isTrue);
    });

    test('clearCart empties all items', () async {
      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      await cart.addToCart(sampleProduct1, quantity: 1);
      await cart.addToCart(sampleProduct2, quantity: 2);
      expect(cart.items.length, 2);

      await cart.clearCart();
      expect(cart.isEmpty, isTrue);
      expect(cart.totalItemCount, 0);
      expect(cart.subtotalAmount, 0.0);
    });

    test('sets user ID and handles user logout correctly', () async {
      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      cart.setUserId('USR_TEST_01');
      expect(cart.currentUserId, 'USR_TEST_01');

      await cart.addToCart(sampleProduct1, quantity: 1);
      expect(cart.items.length, 1);

      await cart.onUserLogout();
      expect(cart.currentUserId, isNull);
      expect(cart.isEmpty, isTrue);
    });
  });

  group('Multi-Item OrderModel Tests', () {
    test('handles multi-item cart order serialization and calculations', () {
      final item1 = OrderItemModel(
        productId: sampleProduct1.id,
        productName: sampleProduct1.name,
        productImage: sampleProduct1.imageUrl,
        companyName: sampleProduct1.companyName,
        categoryName: sampleProduct1.categoryName,
        refNo: sampleProduct1.refNo,
        unitPrice: 4500.0,
        quantity: 2,
        totalPrice: 9000.0,
      );

      final item2 = OrderItemModel(
        productId: sampleProduct2.id,
        productName: sampleProduct2.name,
        productImage: sampleProduct2.imageUrl,
        companyName: sampleProduct2.companyName,
        categoryName: sampleProduct2.categoryName,
        refNo: sampleProduct2.refNo,
        unitPrice: 2200.0,
        quantity: 1,
        totalPrice: 2200.0,
      );

      final order = OrderModel(
        id: 'ORD12345',
        orderNumber: '#ORD-1002',
        userId: 'USR_919876543210',
        userName: 'Ameen',
        userPhone: '9876543210',
        totalAmount: 11200.0,
        items: [item1, item2],
        categoryNames: ['Steering & Suspension', 'Braking System'],
        shippingAddress: 'Workshop 4, Industrial Area',
      );

      expect(order.items.length, 2);
      expect(order.totalItemUnits, 3);
      expect(order.categoryNames.contains('Braking System'), isTrue);
      expect(order.categoryNames.contains('Steering & Suspension'), isTrue);

      final map = order.toMap();
      expect(map['ITEMS'], isA<List>());
      expect((map['ITEMS'] as List).length, 2);
      expect(map['TOTAL_AMOUNT'], 11200.0);

      // Deserialization
      final restored = OrderModel.fromMap(map, 'ORD12345');
      expect(restored.items.length, 2);
      expect(restored.totalItemUnits, 3);
      expect(restored.items[0].productName, 'Power Steering Pump');
      expect(restored.items[1].productName, 'Brake Disc Rotor');
      expect(restored.categoryNames.length, 2);
    });

    test('backward-compatibility: parses legacy single-item map without ITEMS', () {
      final legacyMap = {
        'ORDER_NUMBER': '#ORD-0001',
        'USER_ID': 'USR_OLD',
        'USER_NAME': 'Legacy Customer',
        'USER_PHONE': '9876500000',
        'PRODUCT_ID': 'PRD_LEGACY',
        'PRODUCT_NAME': 'Clutch Plate',
        'PRODUCT_IMAGE': 'https://img.com/clutch.jpg',
        'COMPANY_NAME': 'Tata',
        'CATEGORY_NAME': 'Clutch System',
        'UNIT_PRICE': 3000.0,
        'QUANTITY': 1,
        'TOTAL_AMOUNT': 3000.0,
        'STATUS': 'PENDING',
      };

      final order = OrderModel.fromMap(legacyMap, 'ORD_LEGACY');
      expect(order.id, 'ORD_LEGACY');
      expect(order.items.length, 1);
      expect(order.items.first.productName, 'Clutch Plate');
      expect(order.items.first.totalPrice, 3000.0);
      expect(order.categoryNames, ['Clutch System']);
      expect(order.totalItemUnits, 1);
    });
  });

  group('OrderProvider Multi-Filter Tests', () {
    test('filters by customer name and phone query', () {
      final order1 = OrderModel(
        id: 'ORD1',
        orderNumber: '#ORD-1001',
        userId: 'USR1',
        userName: 'Ameen Yasir',
        userPhone: '9876543210',
        totalAmount: 4500.0,
        categoryName: 'Steering',
      );

      final order2 = OrderModel(
        id: 'ORD2',
        orderNumber: '#ORD-1002',
        userId: 'USR2',
        userName: 'Rahul Sharma',
        userPhone: '9123456789',
        totalAmount: 2200.0,
        categoryName: 'Braking',
      );

      final provider = OrderProvider();
      // Populate internal list using fromMap simulation
      provider.adminOrders.addAll([order1, order2]);

      // No filter -> All 2 returned
      expect(provider.filteredAdminOrders.length, 2);

      // Filter by customer name
      provider.setCustomerFilter('ameen');
      expect(provider.filteredAdminOrders.length, 1);
      expect(provider.filteredAdminOrders.first.userName, 'Ameen Yasir');

      // Filter by customer phone
      provider.setCustomerFilter('91234');
      expect(provider.filteredAdminOrders.length, 1);
      expect(provider.filteredAdminOrders.first.userName, 'Rahul Sharma');

      // Clear customer filter
      provider.setCustomerFilter('');
      expect(provider.filteredAdminOrders.length, 2);
    });

    test('filters by category name accurately', () {
      final order1 = OrderModel(
        id: 'ORD1',
        orderNumber: '#ORD-1001',
        userId: 'USR1',
        userName: 'Customer 1',
        userPhone: '9876543210',
        totalAmount: 5000.0,
        categoryNames: ['Braking System'],
      );

      final order2 = OrderModel(
        id: 'ORD2',
        orderNumber: '#ORD-1002',
        userId: 'USR2',
        userName: 'Customer 2',
        userPhone: '9876543211',
        totalAmount: 7000.0,
        categoryNames: ['Steering & Suspension'],
      );

      final provider = OrderProvider();
      provider.adminOrders.addAll([order1, order2]);

      provider.setCategoryFilter('Braking System');
      expect(provider.filteredAdminOrders.length, 1);
      expect(provider.filteredAdminOrders.first.id, 'ORD1');

      provider.setCategoryFilter('Steering & Suspension');
      expect(provider.filteredAdminOrders.length, 1);
      expect(provider.filteredAdminOrders.first.id, 'ORD2');

      provider.setCategoryFilter('ALL');
      expect(provider.filteredAdminOrders.length, 2);
    });

    test('serializes and deserializes adminRemark in OrderModel', () {
      final order = OrderModel(
        id: 'ORD_REMARK',
        orderNumber: '#ORD-2001',
        userId: 'USR_R',
        userName: 'Remark Customer',
        userPhone: '9876543210',
        totalAmount: 3500.0,
        status: 'CONFIRMED',
        adminRemark: 'Verified with customer, ready for store pickup',
      );

      final map = order.toMap();
      expect(map['ADMIN_REMARK'], 'Verified with customer, ready for store pickup');

      final parsed = OrderModel.fromMap(map, 'ORD_REMARK');
      expect(parsed.adminRemark, 'Verified with customer, ready for store pickup');

      final updated = parsed.copyWith(adminRemark: 'Dispatched via transport');
      expect(updated.adminRemark, 'Dispatched via transport');
      expect(updated.status, 'CONFIRMED');
    });

    test('filters by status marked and computes live count badges', () {
      final orderPending = OrderModel(
        id: 'ORD_P',
        orderNumber: '#ORD-001',
        userId: 'U1',
        userName: 'User 1',
        userPhone: '9876543210',
        totalAmount: 1000.0,
        status: 'PENDING',
      );

      final orderConfirmed = OrderModel(
        id: 'ORD_C',
        orderNumber: '#ORD-002',
        userId: 'U2',
        userName: 'User 2',
        userPhone: '9876543211',
        totalAmount: 2000.0,
        status: 'CONFIRMED',
        adminRemark: 'Confirmed on call',
      );

      final orderDispatched = OrderModel(
        id: 'ORD_D',
        orderNumber: '#ORD-003',
        userId: 'U3',
        userName: 'User 3',
        userPhone: '9876543212',
        totalAmount: 3000.0,
        status: 'DISPATCHED',
      );

      final orderDelivered = OrderModel(
        id: 'ORD_DEL',
        orderNumber: '#ORD-004',
        userId: 'U4',
        userName: 'User 4',
        userPhone: '9876543213',
        totalAmount: 4000.0,
        status: 'DELIVERED',
      );

      final orderCancelled = OrderModel(
        id: 'ORD_CAN',
        orderNumber: '#ORD-005',
        userId: 'U5',
        userName: 'User 5',
        userPhone: '9876543214',
        totalAmount: 5000.0,
        status: 'CANCELLED',
      );

      final provider = OrderProvider();
      provider.adminOrders.addAll([
        orderPending,
        orderConfirmed,
        orderDispatched,
        orderDelivered,
        orderCancelled,
      ]);

      // Counts verify all statuses
      expect(provider.totalOrdersCount, 5);
      expect(provider.pendingOrdersCount, 1);
      expect(provider.confirmedOrdersCount, 1);
      expect(provider.dispatchedOrdersCount, 1);
      expect(provider.deliveredOrdersCount, 1);
      expect(provider.cancelledOrdersCount, 1);

      // Status filters
      provider.setStatusFilter('PENDING');
      expect(provider.filteredAdminOrders.length, 1);
      expect(provider.filteredAdminOrders.first.id, 'ORD_P');

      provider.setStatusFilter('CONFIRMED');
      expect(provider.filteredAdminOrders.length, 1);
      expect(provider.filteredAdminOrders.first.id, 'ORD_C');
      expect(provider.filteredAdminOrders.first.adminRemark, 'Confirmed on call');

      provider.setStatusFilter('DISPATCHED');
      expect(provider.filteredAdminOrders.length, 1);
      expect(provider.filteredAdminOrders.first.id, 'ORD_D');

      provider.setStatusFilter('DELIVERED');
      expect(provider.filteredAdminOrders.length, 1);
      expect(provider.filteredAdminOrders.first.id, 'ORD_DEL');

      provider.setStatusFilter('CANCELLED');
      expect(provider.filteredAdminOrders.length, 1);
      expect(provider.filteredAdminOrders.first.id, 'ORD_CAN');

      provider.setStatusFilter('ALL');
      expect(provider.filteredAdminOrders.length, 5);
    });
  });
}
