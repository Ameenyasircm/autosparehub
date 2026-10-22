import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_spare_hub/models/customer_model.dart';
import 'package:auto_spare_hub/models/order_model.dart';
import 'package:auto_spare_hub/services/keyword_generator.dart';
import 'package:auto_spare_hub/services/user_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeywordGenerator Tests', () {
    test('generates lowercase tokens and prefix n-grams correctly', () {
      final keywords = KeywordGenerator.generateKeywords(
        name: 'Power Steering Pump',
        companyName: 'Toyota',
        categoryName: 'Steering',
        application: 'Hilux Vigo 2015',
        refNo: '44310-0K040',
      );

      // Verify essential tokens exist
      expect(keywords.contains('power'), isTrue);
      expect(keywords.contains('steering'), isTrue);
      expect(keywords.contains('pump'), isTrue);
      expect(keywords.contains('toyota'), isTrue);
      expect(keywords.contains('hilux'), isTrue);
      expect(keywords.contains('vigo'), isTrue);
      expect(keywords.contains('2015'), isTrue);

      // Verify prefix autocomplete n-grams exist (e.g. "pow", "powe", "power")
      expect(keywords.contains('pow'), isTrue);
      expect(keywords.contains('toyo'), isTrue);
      expect(keywords.contains('hilu'), isTrue);

      // Verify refNo is sanitized and added
      expect(keywords.contains('443100k040'), isTrue);
    });

    test('handles empty and null fields safely without errors', () {
      final keywords = KeywordGenerator.generateKeywords(
        name: 'Brake Disc',
        companyName: null,
        categoryName: null,
        application: null,
        refNo: null,
      );

      expect(keywords.isNotEmpty, isTrue);
      expect(keywords.contains('brake'), isTrue);
      expect(keywords.contains('disc'), isTrue);
    });
  });

  group('CustomerModel Tests', () {
    test('serializes toMap and parses fromMap accurately', () {
      final now = DateTime.now();
      final customer = CustomerModel(
        id: 'USR1776788421000',
        name: 'Ameen Yasir',
        phone: '+919876543210',
        status: 'PENDING',
        requestedAt: now,
      );

      final map = customer.toMap();
      expect(map['ID'], 'USR1776788421000');
      expect(map['NAME'], 'Ameen Yasir');
      expect(map['PHONE_NUMBER'], '+919876543210');
      expect(map['STATUS'], 'PENDING');

      final fromMap = CustomerModel.fromMap(map, 'USR1776788421000');
      expect(fromMap.id, 'USR1776788421000');
      expect(fromMap.name, 'Ameen Yasir');
      expect(fromMap.phone, '+919876543210');
      expect(fromMap.isPending, isTrue);
      expect(fromMap.isApproved, isFalse);
    });

    test('status helper getters report correct state', () {
      const pendingUser = CustomerModel(id: '1', name: 'A', phone: '1', status: 'PENDING');
      const approvedUser = CustomerModel(id: '2', name: 'B', phone: '2', status: 'APPROVED');
      const rejectedUser = CustomerModel(id: '3', name: 'C', phone: '3', status: 'REJECTED');

      expect(pendingUser.isPending, isTrue);
      expect(approvedUser.isApproved, isTrue);
      expect(rejectedUser.isRejected, isTrue);
    });
  });

  group('OrderModel Tests', () {
    test('computes total amount accurately and serializes toMap', () {
      final now = DateTime.now();
      final order = OrderModel(
        id: 'ORD1776788421000',
        orderNumber: '#ORD-1001',
        userId: 'USR123',
        userName: 'Ameen',
        userPhone: '+919876543210',
        productId: 'PRD456',
        productName: 'Alternator 12V 90A',
        productImage: 'https://img.com/alt.jpg',
        companyName: 'Toyota',
        categoryName: 'Electrical',
        unitPrice: 3500.0,
        quantity: 2,
        totalAmount: 7000.0,
        shippingAddress: '123 Main Street, Cochin',
        status: 'PENDING',
        createdAt: now,
      );

      final map = order.toMap();
      expect(map['ID'], 'ORD1776788421000');
      expect(map['ORDER_NUMBER'], '#ORD-1001');
      expect(map['USER_ID'], 'USR123');
      expect(map['PRODUCT_NAME'], 'Alternator 12V 90A');
      expect(map['UNIT_PRICE'], 3500.0);
      expect(map['QUANTITY'], 2);
      expect(map['TOTAL_AMOUNT'], 7000.0);
      expect(map['SHIPPING_ADDRESS'], '123 Main Street, Cochin');
      expect(map['STATUS'], 'PENDING');

      final fromMap = OrderModel.fromMap(map, 'ORD1776788421000');
      expect(fromMap.id, 'ORD1776788421000');
      expect(fromMap.isPending, isTrue);
      expect(fromMap.isConfirmed, isFalse);
    });
  });

  group('UserSessionService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and restores customer session correctly in SharedPreferences', () async {
      final sessionService = UserSessionService();
      const customer = CustomerModel(
        id: 'USR999',
        name: 'Rahul',
        phone: '9988776655',
        status: 'APPROVED',
      );

      await sessionService.saveCustomerSession(customer);

      final session = await sessionService.getCustomerSession();
      expect(session, isNotNull);
      expect(session!.id, 'USR999');
      expect(session.name, 'Rahul');
      expect(session.phone, '9988776655');
      expect(session.status, 'APPROVED');

      await sessionService.clearCustomerSession();
      final cleared = await sessionService.getCustomerSession();
      expect(cleared, isNull);
    });
  });
}
