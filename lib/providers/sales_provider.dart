import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/sales_models.dart';
import '../utils/sales_helper.dart';

/// Counter sales, stock purchases and the day-wise sales list (admin app).
///
/// Every sale/purchase changes product stock inside one Firestore transaction
/// together with the entry itself, so stock and entries never drift apart and
/// two admins cannot oversell the same stock.
class SalesProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;

  SalesProvider({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String salesCollection = 'SALES';
  static const String purchasesCollection = 'PURCHASES';
  static const String productsCollection = 'PRODUCTS';
  static const String countersCollection = 'COUNTERS';
  static const String ordersCollection = 'ORDERS';

  List<SaleModel> _sales = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<SaleModel> get sales => _sales;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @visibleForTesting
  void setSalesForTesting(List<SaleModel> list) {
    _sales = List.from(list);
    notifyListeners();
  }

  static String _formatNumber(String prefix, int n) => '$prefix-${n.toString().padLeft(4, '0')}';

  /// Records a sale and reduces stock. Blocks the sale if any product does not
  /// have enough stock. Returns the saved sale, or null with [errorMessage] set.
  Future<SaleModel?> createSale({
    required CustomerModel customer,
    required List<StockLineItem> items,
    required DateTime saleDate,
    String? note,
    AdminModel? admin,
    String? orderId,
    String? orderNumber,
  }) async {
    final lines = SalesHelper.mergeLines(items.where((i) => i.quantity > 0).toList());
    if (lines.isEmpty) {
      _errorMessage = 'Add at least one product.';
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Same ID style as orders/products: prefix + creation time in ms.
      final saleRef = _firestore
          .collection(salesCollection)
          .doc('SL${DateTime.now().millisecondsSinceEpoch}');
      final counterRef = _firestore.collection(countersCollection).doc(salesCollection);

      // Returns either the saved sale or an error message. Errors are returned
      // rather than thrown because the plugin may wrap thrown errors.
      final result = await _firestore.runTransaction<Object>((tx) async {
        if ((await tx.get(saleRef)).exists) return 'Please try saving again.';
        final orderRef = orderId == null ? null : _firestore.collection(ordersCollection).doc(orderId);
        if (orderRef != null) {
          final orderSnap = await tx.get(orderRef);
          if (!orderSnap.exists) return 'This order no longer exists.';
          final existingSale = orderSnap.data()?['SALE_NUMBER'];
          if (existingSale != null) return 'This order is already converted to sale $existingSale.';
        }
        final counterSnap = await tx.get(counterRef);
        final stock = <String, int?>{};
        for (final line in lines) {
          final snap = await tx.get(_firestore.collection(productsCollection).doc(line.productId));
          if (!snap.exists) return '${line.productName} no longer exists in the catalog.';
          stock[line.productId] = ProductModel.fromFirestore(snap).stockQuantity;
        }

        final shortages = SalesHelper.stockShortages(lines, stock);
        if (shortages.isNotEmpty) return 'Not enough stock:\n${shortages.join('\n')}';

        final next = ((counterSnap.data()?['LAST_NUMBER'] as num?)?.toInt() ?? 0) + 1;
        final sale = SaleModel.fromItems(
          id: saleRef.id,
          saleNumber: _formatNumber('SAL', next),
          customerId: customer.id,
          customerName: customer.name,
          customerPhone: customer.phoneNumber,
          items: lines,
          saleDate: saleDate,
          note: (note?.trim().isEmpty ?? true) ? null : note!.trim(),
          createdById: admin?.id,
          createdByName: admin?.name,
          orderId: orderId,
          orderNumber: orderNumber,
        );

        tx.set(counterRef, {'LAST_NUMBER': next}, SetOptions(merge: true));
        if (orderRef != null) {
          tx.update(orderRef, {
            'SALE_ID': sale.id,
            'SALE_NUMBER': sale.saleNumber,
            'SOLD_AT': FieldValue.serverTimestamp(),
            'UPDATED_AT': FieldValue.serverTimestamp(),
          });
        }
        for (final line in lines) {
          tx.update(_firestore.collection(productsCollection).doc(line.productId), {
            'STOCK_QUANTITY': (stock[line.productId] ?? 0) - line.quantity,
            'UPDATED_AT': FieldValue.serverTimestamp(),
          });
        }
        tx.set(saleRef, sale.toMap());
        for (final line in lines) {
          tx.set(
            saleRef.collection(SaleModel.itemsSubcollection).doc(line.productId),
            sale.itemToMap(line),
          );
        }
        return sale;
      }).timeout(const Duration(seconds: 15));

      _isSaving = false;
      if (result is SaleModel) {
        _sales.insert(0, result);
        notifyListeners();
        return result;
      }
      _errorMessage = result.toString();
      notifyListeners();
      return null;
    } on TimeoutException {
      return _fail('Connection timed out. The sale was not saved. Please try again.');
    } catch (e) {
      debugPrint('SalesProvider.createSale error: $e');
      return _fail('Failed to save sale: $e');
    }
  }

  /// Marks a sale as cancelled and puts its stock back. The sale is kept so
  /// the history stays complete, but it no longer counts in totals.
  Future<bool> cancelSale(SaleModel sale, {AdminModel? admin}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final saleRef = _firestore.collection(salesCollection).doc(sale.id);
      final error = await _firestore.runTransaction<String?>((tx) async {
        final saleSnap = await tx.get(saleRef);
        if (!saleSnap.exists) return 'This sale no longer exists.';
        final current = SaleModel.fromFirestore(saleSnap);
        if (current.isCancelled) return 'This sale is already cancelled.';

        // Quantities come from the per-product summary on the sale document,
        // so the ITEMS subcollection does not need to be read here.
        // A cancelled sale frees its order so it can be converted again.
        final orderRef = current.orderId == null
            ? null
            : _firestore.collection(ordersCollection).doc(current.orderId);
        final orderExists = orderRef != null && (await tx.get(orderRef)).exists;

        final existing = <String>{};
        for (final productId in current.products.keys) {
          final ref = _firestore.collection(productsCollection).doc(productId);
          if ((await tx.get(ref)).exists) existing.add(productId);
        }

        for (final productId in existing) {
          tx.update(_firestore.collection(productsCollection).doc(productId), {
            'STOCK_QUANTITY': FieldValue.increment(current.products[productId]!.quantity),
            'UPDATED_AT': FieldValue.serverTimestamp(),
          });
        }
        if (orderExists) {
          tx.update(orderRef, {
            'SALE_ID': FieldValue.delete(),
            'SALE_NUMBER': FieldValue.delete(),
            'SOLD_AT': FieldValue.delete(),
            'UPDATED_AT': FieldValue.serverTimestamp(),
          });
        }
        tx.update(saleRef, {
          'STATUS': SaleModel.statusCancelled,
          'CANCELLED_AT': FieldValue.serverTimestamp(),
          'CANCELLED_BY_ID': admin?.id,
          'CANCELLED_BY_NAME': admin?.name,
        });
        return null;
      }).timeout(const Duration(seconds: 15));

      _isSaving = false;
      if (error != null) {
        _errorMessage = error;
        notifyListeners();
        return false;
      }
      final index = _sales.indexWhere((s) => s.id == sale.id);
      if (index != -1) {
        _sales[index] = _sales[index].copyWith(status: SaleModel.statusCancelled);
      }
      notifyListeners();
      return true;
    } on TimeoutException {
      _fail('Connection timed out. Please check whether the sale was cancelled before retrying.');
      return false;
    } catch (e) {
      debugPrint('SalesProvider.cancelSale error: $e');
      _fail('Failed to cancel sale: $e');
      return false;
    }
  }

  /// Records a purchase from a supplier and increases stock.
  Future<PurchaseModel?> createPurchase({
    required String supplierName,
    String? supplierBillNo,
    required List<StockLineItem> items,
    required DateTime purchaseDate,
    String? note,
    AdminModel? admin,
  }) async {
    final lines = SalesHelper.mergeLines(items.where((i) => i.quantity > 0).toList());
    if (supplierName.trim().isEmpty) {
      _errorMessage = 'Supplier name is required.';
      notifyListeners();
      return null;
    }
    if (lines.isEmpty) {
      _errorMessage = 'Add at least one product.';
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final purchaseRef = _firestore
          .collection(purchasesCollection)
          .doc('PU${DateTime.now().millisecondsSinceEpoch}');
      final counterRef = _firestore.collection(countersCollection).doc(purchasesCollection);

      final result = await _firestore.runTransaction<Object>((tx) async {
        if ((await tx.get(purchaseRef)).exists) return 'Please try saving again.';
        final counterSnap = await tx.get(counterRef);
        for (final line in lines) {
          final snap = await tx.get(_firestore.collection(productsCollection).doc(line.productId));
          if (!snap.exists) return '${line.productName} no longer exists in the catalog.';
        }

        final next = ((counterSnap.data()?['LAST_NUMBER'] as num?)?.toInt() ?? 0) + 1;
        final purchase = PurchaseModel(
          id: purchaseRef.id,
          purchaseNumber: _formatNumber('PUR', next),
          supplierName: supplierName.trim(),
          supplierBillNo: (supplierBillNo?.trim().isEmpty ?? true) ? null : supplierBillNo!.trim(),
          items: lines,
          purchaseDate: purchaseDate,
          note: (note?.trim().isEmpty ?? true) ? null : note!.trim(),
          createdById: admin?.id,
          createdByName: admin?.name,
        );

        tx.set(counterRef, {'LAST_NUMBER': next}, SetOptions(merge: true));
        for (final line in lines) {
          // increment() also works when the product had no stock recorded.
          tx.update(_firestore.collection(productsCollection).doc(line.productId), {
            'STOCK_QUANTITY': FieldValue.increment(line.quantity),
            'UPDATED_AT': FieldValue.serverTimestamp(),
          });
        }
        tx.set(purchaseRef, purchase.toMap());
        return purchase;
      }).timeout(const Duration(seconds: 15));

      _isSaving = false;
      if (result is PurchaseModel) {
        notifyListeners();
        return result;
      }
      _errorMessage = result.toString();
      notifyListeners();
      return null;
    } on TimeoutException {
      return _fail('Connection timed out. The purchase was not saved. Please try again.');
    } catch (e) {
      debugPrint('SalesProvider.createPurchase error: $e');
      return _fail('Failed to save purchase: $e');
    }
  }

  /// Loads the full lines of a sale from its ITEMS subcollection (one read per
  /// line). Sales that already carry their lines are returned as-is.
  Future<List<StockLineItem>> fetchSaleItems(SaleModel sale) async {
    if (sale.items.isNotEmpty) return sale.items;
    final snapshot = await _firestore
        .collection(salesCollection)
        .doc(sale.id)
        .collection(SaleModel.itemsSubcollection)
        .get()
        .timeout(const Duration(seconds: 10));
    final items = snapshot.docs.map((d) => StockLineItem.fromMap(d.data())).toList();
    final index = _sales.indexWhere((s) => s.id == sale.id);
    if (index != -1) _sales[index] = _sales[index].copyWith(items: items);
    return items;
  }

  /// Loads sales whose sale date falls within [from]..[to] (both inclusive days).
  Future<void> fetchSales({required DateTime from, required DateTime to}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final start = SalesHelper.dayOnly(from);
      final endExclusive = SalesHelper.dayOnly(to).add(const Duration(days: 1));
      final snapshot = await _firestore
          .collection(salesCollection)
          .where('SALE_DATE', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('SALE_DATE', isLessThan: Timestamp.fromDate(endExclusive))
          .orderBy('SALE_DATE', descending: true)
          .get()
          .timeout(const Duration(seconds: 12));
      _sales = snapshot.docs.map(SaleModel.fromFirestore).toList();
    } on TimeoutException {
      _errorMessage = 'Connection timed out while loading sales.';
    } catch (e) {
      debugPrint('SalesProvider.fetchSales error: $e');
      _errorMessage = 'Failed to load sales: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Null _fail(String message) {
    _isSaving = false;
    _errorMessage = message;
    notifyListeners();
    return null;
  }
}
