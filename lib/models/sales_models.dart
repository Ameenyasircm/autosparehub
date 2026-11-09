import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

int _parseInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

/// One product line in a sale or a purchase.
/// For a sale, [unitPrice] is the selling price; for a purchase, the cost price.
class StockLineItem {
  final String productId;
  final String productName;
  final String? refNo;
  final int quantity;
  final double unitPrice;

  const StockLineItem({
    required this.productId,
    required this.productName,
    this.refNo,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;

  factory StockLineItem.fromMap(Map<String, dynamic> data) {
    return StockLineItem(
      productId: (data['PRODUCT_ID'] ?? '').toString(),
      productName: (data['PRODUCT_NAME'] ?? '').toString(),
      refNo: data['REF_NO']?.toString(),
      quantity: _parseInt(data['QUANTITY']),
      unitPrice: _parseDouble(data['UNIT_PRICE']),
    );
  }

  Map<String, dynamic> toMap() => {
        'PRODUCT_ID': productId,
        'PRODUCT_NAME': productName,
        'REF_NO': refNo,
        'QUANTITY': quantity,
        'UNIT_PRICE': unitPrice,
        'TOTAL': total,
      };
}

List<StockLineItem> _parseItems(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => StockLineItem.fromMap(Map<String, dynamic>.from(m)))
      .toList();
}

double sumLineItems(List<StockLineItem> items) =>
    items.fold(0.0, (acc, item) => acc + item.total);

/// Per-product summary kept on the sale document, so lists, totals and the
/// product filter work without reading the ITEMS subcollection.
class SaleProductTotal {
  final String name;
  final int quantity;
  final double amount;

  const SaleProductTotal({required this.name, required this.quantity, required this.amount});

  factory SaleProductTotal.fromMap(Map<String, dynamic> data) => SaleProductTotal(
        name: (data['NAME'] ?? '').toString(),
        quantity: _parseInt(data['QTY']),
        amount: _parseDouble(data['AMOUNT']),
      );

  Map<String, dynamic> toMap() => {'NAME': name, 'QTY': quantity, 'AMOUNT': amount};
}

Map<String, SaleProductTotal> _totalsFromItems(List<StockLineItem> items) {
  final totals = <String, SaleProductTotal>{};
  for (final item in items) {
    final prev = totals[item.productId];
    totals[item.productId] = SaleProductTotal(
      name: item.productName,
      quantity: (prev?.quantity ?? 0) + item.quantity,
      amount: (prev?.amount ?? 0) + item.total,
    );
  }
  return totals;
}

/// A counter sale entered by an admin.
///
/// Firestore layout:
///   SALES/{SL + epochMillis}                header + per-product summary (PRODUCTS)
///   SALES/{SL + epochMillis}/ITEMS/{productId} full line (qty, unit price, ref no)
class SaleModel {
  static const String statusCompleted = 'COMPLETED';
  static const String statusCancelled = 'CANCELLED';
  static const String itemsSubcollection = 'ITEMS';

  final String id;
  final String saleNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;

  /// Per-product summary, keyed by product ID. Always available.
  final Map<String, SaleProductTotal> products;

  /// Full lines. Filled when the sale is created or after the ITEMS
  /// subcollection is loaded; empty for sales read from a list query.
  final List<StockLineItem> items;
  final DateTime saleDate;
  final String? note;
  final String status;
  final String? createdById;
  final String? createdByName;
  final DateTime? createdAt;

  /// Set when the sale was created from a customer app order.
  final String? orderId;
  final String? orderNumber;

  const SaleModel({
    required this.id,
    required this.saleNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.products,
    this.items = const [],
    required this.saleDate,
    this.note,
    this.status = statusCompleted,
    this.createdById,
    this.createdByName,
    this.createdAt,
    this.orderId,
    this.orderNumber,
  });

  /// Builds a sale from its lines, deriving the per-product summary.
  factory SaleModel.fromItems({
    required String id,
    required String saleNumber,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required List<StockLineItem> items,
    required DateTime saleDate,
    String? note,
    String status = statusCompleted,
    String? createdById,
    String? createdByName,
    String? orderId,
    String? orderNumber,
  }) =>
      SaleModel(
        id: id,
        saleNumber: saleNumber,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        products: _totalsFromItems(items),
        items: items,
        saleDate: saleDate,
        note: note,
        status: status,
        createdById: createdById,
        createdByName: createdByName,
        orderId: orderId,
        orderNumber: orderNumber,
      );

  bool get isCancelled => status == statusCancelled;
  double get totalAmount => products.values.fold(0.0, (acc, p) => acc + p.amount);
  int get totalQuantity => products.values.fold(0, (acc, p) => acc + p.quantity);

  /// 'Clutch × 1, Brake Pad × 2'
  String get itemSummary =>
      products.values.map((p) => '${p.name} × ${p.quantity}').join(', ');

  SaleModel copyWith({String? status, List<StockLineItem>? items}) => SaleModel(
        id: id,
        saleNumber: saleNumber,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        products: products,
        items: items ?? this.items,
        saleDate: saleDate,
        note: note,
        status: status ?? this.status,
        createdById: createdById,
        createdByName: createdByName,
        createdAt: createdAt,
        orderId: orderId,
        orderNumber: orderNumber,
      );

  factory SaleModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SaleModel.fromMap(doc.data() ?? {}, doc.id);

  factory SaleModel.fromMap(Map<String, dynamic> data, String id) {
    // Early test sales stored lines in an ITEMS array on the document itself.
    final legacyItems = _parseItems(data['ITEMS']);
    final rawProducts = data['PRODUCTS'];
    final products = rawProducts is Map
        ? rawProducts.map((k, v) => MapEntry(
              k.toString(),
              SaleProductTotal.fromMap(v is Map ? Map<String, dynamic>.from(v) : const {}),
            ))
        : _totalsFromItems(legacyItems);

    return SaleModel(
      id: id,
      saleNumber: (data['SALE_NUMBER'] ?? id).toString(),
      customerId: (data['CUSTOMER_ID'] ?? '').toString(),
      customerName: (data['CUSTOMER_NAME'] ?? '').toString(),
      customerPhone: (data['CUSTOMER_PHONE'] ?? '').toString(),
      products: products,
      items: legacyItems,
      saleDate: _parseDate(data['SALE_DATE']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      note: data['NOTE']?.toString(),
      status: (data['STATUS'] ?? statusCompleted).toString().toUpperCase(),
      createdById: data['CREATED_BY_ID']?.toString(),
      createdByName: data['CREATED_BY_NAME']?.toString(),
      createdAt: _parseDate(data['CREATED_AT']),
      orderId: data['ORDER_ID']?.toString(),
      orderNumber: data['ORDER_NUMBER']?.toString(),
    );
  }

  /// The sale document (lines are written separately to the ITEMS subcollection).
  Map<String, dynamic> toMap() => {
        'SALE_NUMBER': saleNumber,
        'CUSTOMER_ID': customerId,
        'CUSTOMER_NAME': customerName,
        'CUSTOMER_PHONE': customerPhone,
        'PRODUCTS': products.map((k, v) => MapEntry(k, v.toMap())),
        'PRODUCT_IDS': products.keys.toList(),
        'ITEM_COUNT': products.length,
        'TOTAL_AMOUNT': totalAmount,
        'TOTAL_QUANTITY': totalQuantity,
        'SALE_DATE': Timestamp.fromDate(saleDate),
        'NOTE': note,
        'STATUS': status,
        'CREATED_BY_ID': createdById,
        'CREATED_BY_NAME': createdByName,
        'CREATED_AT': FieldValue.serverTimestamp(),
        'ORDER_ID': orderId,
        'ORDER_NUMBER': orderNumber,
      };

  /// One document per line in SALES/{id}/ITEMS/{productId}. Sale fields are
  /// copied in so items can later be queried on their own (collection group).
  Map<String, dynamic> itemToMap(StockLineItem item) => {
        ...item.toMap(),
        'SALE_ID': id,
        'SALE_NUMBER': saleNumber,
        'CUSTOMER_ID': customerId,
        'SALE_DATE': Timestamp.fromDate(saleDate),
      };
}

/// Stock bought from a supplier. Stored in the `PURCHASES` collection.
class PurchaseModel {
  final String id;
  final String purchaseNumber;
  final String supplierName;
  final String? supplierBillNo;
  final List<StockLineItem> items;
  final DateTime purchaseDate;
  final String? note;
  final String? createdById;
  final String? createdByName;

  const PurchaseModel({
    required this.id,
    required this.purchaseNumber,
    required this.supplierName,
    this.supplierBillNo,
    required this.items,
    required this.purchaseDate,
    this.note,
    this.createdById,
    this.createdByName,
  });

  double get totalAmount => sumLineItems(items);

  factory PurchaseModel.fromMap(Map<String, dynamic> data, String id) {
    return PurchaseModel(
      id: id,
      purchaseNumber: (data['PURCHASE_NUMBER'] ?? id).toString(),
      supplierName: (data['SUPPLIER_NAME'] ?? '').toString(),
      supplierBillNo: data['SUPPLIER_BILL_NO']?.toString(),
      items: _parseItems(data['ITEMS']),
      purchaseDate:
          _parseDate(data['PURCHASE_DATE']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      note: data['NOTE']?.toString(),
      createdById: data['CREATED_BY_ID']?.toString(),
      createdByName: data['CREATED_BY_NAME']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'PURCHASE_NUMBER': purchaseNumber,
        'SUPPLIER_NAME': supplierName,
        'SUPPLIER_BILL_NO': supplierBillNo,
        'ITEMS': items.map((i) => i.toMap()).toList(),
        'TOTAL_AMOUNT': totalAmount,
        'PURCHASE_DATE': Timestamp.fromDate(purchaseDate),
        'NOTE': note,
        'CREATED_BY_ID': createdById,
        'CREATED_BY_NAME': createdByName,
        'CREATED_AT': FieldValue.serverTimestamp(),
      };
}
