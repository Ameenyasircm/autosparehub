import 'package:auto_spare_hub/models/sales_models.dart';
import 'package:auto_spare_hub/providers/customer_management_provider.dart';
import 'package:auto_spare_hub/providers/sales_provider.dart';
import 'package:auto_spare_hub/models/customer_model.dart';
import 'package:auto_spare_hub/utils/sales_helper.dart';
import 'package:auto_spare_hub/services/sales_report_pdf.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

StockLineItem line(String id, int qty, double price) =>
    StockLineItem(productId: id, productName: 'Part $id', quantity: qty, unitPrice: price);

SaleModel sale(
  String id,
  DateTime date,
  List<StockLineItem> items, {
  String customerId = 'C1',
  String status = SaleModel.statusCompleted,
}) =>
    SaleModel.fromItems(
      id: id,
      saleNumber: 'SAL-$id',
      customerId: customerId,
      customerName: 'Customer $customerId',
      customerPhone: '9876543210',
      items: items,
      saleDate: date,
      status: status,
    );

void main() {
  group('StockLineItem / SaleModel', () {
    test('totals and item summary', () {
      final s = sale('1', DateTime(2026, 11, 9), [line('A', 2, 150), line('B', 1, 99.5)]);
      expect(s.totalAmount, 399.5);
      expect(s.totalQuantity, 3);
      expect(s.itemSummary, 'Part A × 2, Part B × 1');
    });

    test('sale document holds the summary, not the lines', () {
      final s = sale('SL1', DateTime(2026, 11, 9, 10), [line('A', 2, 150), line('B', 1, 50)]);
      final map = s.toMap()..['SALE_DATE'] = Timestamp.fromDate(s.saleDate);
      expect(map.containsKey('ITEMS'), isFalse);
      expect(map['PRODUCT_IDS'], ['A', 'B']);
      expect(map['TOTAL_AMOUNT'], 350);

      final back = SaleModel.fromMap(map, 'SL1');
      expect(back.items, isEmpty); // lines live in the subcollection
      expect(back.totalAmount, 350);
      expect(back.products['A']!.quantity, 2);
      expect(back.products['A']!.amount, 300);
      expect(back.saleDate, s.saleDate);
    });

    test('item document carries sale fields for later querying', () {
      final s = sale('SL1', DateTime(2026, 11, 9), [line('A', 2, 150)]);
      final item = s.itemToMap(s.items.single);
      expect(item['SALE_ID'], 'SL1');
      expect(item['PRODUCT_ID'], 'A');
      expect(item['QUANTITY'], 2);
      expect(item['TOTAL'], 300);
    });

    test('reads early sales that stored an ITEMS array', () {
      final legacy = SaleModel.fromMap({
        'SALE_NUMBER': 'SAL-0001',
        'ITEMS': [
          {'PRODUCT_ID': 'PRD1', 'PRODUCT_NAME': 'Clutch', 'QUANTITY': 1, 'UNIT_PRICE': 500},
        ],
        'SALE_DATE': Timestamp.fromDate(DateTime(2026, 11, 9)),
        'STATUS': 'COMPLETED',
      }, 'Ul8Q5lkW2XLHR52xItL5');
      expect(legacy.totalAmount, 500);
      expect(legacy.products['PRD1']!.quantity, 1);
      expect(legacy.items.single.productName, 'Clutch');
    });

    test('copyWith changes only the status', () {
      final s = sale('1', DateTime(2026, 11, 9), [line('A', 1, 10)]);
      final c = s.copyWith(status: SaleModel.statusCancelled);
      expect(c.isCancelled, isTrue);
      expect(c.saleNumber, s.saleNumber);
      expect(c.totalAmount, s.totalAmount);
    });
  });

  group('SalesHelper stock checks', () {
    test('mergeLines combines the same product', () {
      final merged = SalesHelper.mergeLines([line('A', 2, 10), line('B', 1, 5), line('A', 3, 12)]);
      expect(merged.length, 2);
      expect(merged.firstWhere((l) => l.productId == 'A').quantity, 5);
    });

    test('allows a sale within stock', () {
      expect(SalesHelper.stockShortages([line('A', 3, 10)], {'A': 3}), isEmpty);
    });

    test('blocks a sale above stock, counting duplicate lines together', () {
      final errors = SalesHelper.stockShortages([line('A', 2, 10), line('A', 2, 10)], {'A': 3});
      expect(errors.single, contains('only 3 in stock'));
    });

    test('treats missing stock as zero', () {
      expect(SalesHelper.stockShortages([line('A', 1, 10)], {'A': null}), isNotEmpty);
      expect(SalesHelper.stockShortages([line('A', 1, 10)], {}), isNotEmpty);
    });
  });

  group('SalesHelper day-wise view', () {
    final d1 = DateTime(2026, 11, 8, 10);
    final d2 = DateTime(2026, 11, 9, 9);
    final d2late = DateTime(2026, 11, 9, 18);
    final sales = [
      sale('1', d1, [line('A', 1, 100)], customerId: 'C1'),
      sale('2', d2, [line('A', 2, 100), line('B', 1, 50)], customerId: 'C2'),
      sale('3', d2late, [line('B', 4, 50)], customerId: 'C1'),
      sale('4', d2late, [line('A', 5, 100)], customerId: 'C1', status: SaleModel.statusCancelled),
    ];

    test('groups by day, newest first, cancelled excluded from totals', () {
      final days = SalesHelper.groupByDay(sales);
      expect(days.map((d) => d.day), [DateTime(2026, 11, 9), DateTime(2026, 11, 8)]);
      expect(days.first.totalAmount, 250 + 200);
      expect(days.first.saleCount, 2);
      expect(days.first.sales.length, 3); // cancelled still listed
      expect(days.last.totalAmount, 100);
    });

    test('product filter keeps matching sales and counts only that product', () {
      final filtered = SalesHelper.filterSales(sales, productId: 'B');
      expect(filtered.map((s) => s.id), ['2', '3']);
      final days = SalesHelper.groupByDay(filtered, productId: 'B');
      expect(days.single.totalAmount, 50 + 200);
      expect(days.single.totalQuantity, 5);
    });

    test('customer filter and cancelled handling', () {
      expect(SalesHelper.filterSales(sales, customerId: 'C1').map((s) => s.id), ['1', '3']);
      expect(SalesHelper.filterSales(sales, customerId: 'C1', includeCancelled: true).length, 3);
    });
  });

  group('SalesHelper formatting', () {
    test('formatAmount uses Indian grouping', () {
      expect(SalesHelper.formatAmount(0), '₹0');
      expect(SalesHelper.formatAmount(999), '₹999');
      expect(SalesHelper.formatAmount(1234.5), '₹1,234.50');
      expect(SalesHelper.formatAmount(123456), '₹1,23,456');
      expect(SalesHelper.formatAmount(12345678), '₹1,23,45,678');
    });

    test('formatDay', () {
      expect(SalesHelper.formatDay(DateTime(2026, 11, 9)), 'Mon, 09 Nov 2026');
    });
  });

  group('Validation before touching Firestore', () {
    test('addCustomerByAdmin rejects bad input', () async {
      final p = CustomerManagementProvider();
      expect(await p.addCustomerByAdmin(name: '', phone: '9876543210', password: 'secret1'), isNull);
      expect(p.errorMessage, contains('name'));
      expect(await p.addCustomerByAdmin(name: 'Garage', phone: '12345', password: 'secret1'), isNull);
      expect(p.errorMessage, contains('mobile'));
      expect(await p.addCustomerByAdmin(name: 'Garage', phone: '9876543210', password: '123'), isNull);
      expect(p.errorMessage, contains('6 characters'));
    });

    test('createSale and createPurchase need products', () async {
      final p = SalesProvider();
      const customer = CustomerModel(id: 'C1', name: 'G', phoneNumber: '9876543210');
      expect(await p.createSale(customer: customer, items: [], saleDate: DateTime.now()), isNull);
      expect(p.errorMessage, 'Add at least one product.');
      expect(
          await p.createPurchase(supplierName: '', items: [line('A', 1, 1)], purchaseDate: DateTime.now()),
          isNull);
      expect(p.errorMessage, 'Supplier name is required.');
    });
  });

  group('SalesReportPdf', () {
    test('builds a PDF with logo, cancelled bill and non-English name', () async {
      final days = SalesHelper.groupByDay([
        sale('1', DateTime(2026, 11, 9, 10), [line('A', 2, 1500)]),
        sale('2', DateTime(2026, 11, 9, 11), [line('B', 1, 50)], status: SaleModel.statusCancelled),
        SaleModel.fromItems(
          id: '3',
          saleNumber: 'SAL-0003',
          customerId: 'C9',
          customerName: 'ജോഹർ Garage', // Malayalam + Latin
          customerPhone: '9876543210',
          items: [line('A', 1, 1500)],
          saleDate: DateTime(2026, 11, 8),
        ),
      ]);
      final bytes = await SalesReportPdf.build(
        days: days,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 9),
        customerName: 'All',
        logoBytes: File('assets/AutoSpareLogo.jpg').readAsBytesSync(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(10000)); // logo embedded
    });

    test('safe() replaces characters the PDF font cannot draw', () {
      expect(SalesReportPdf.safe('Clutch × 2'), 'Clutch × 2');
      expect(SalesReportPdf.safe('ജ Garage'), '? Garage');
      expect(SalesHelper.formatAmount(1234, symbol: 'Rs. '), 'Rs. 1,234');
    });
  });
}
