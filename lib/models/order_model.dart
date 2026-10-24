import 'package:cloud_firestore/cloud_firestore.dart';

/// Sub-item model representing an individual spare part line item inside an order.
class OrderItemModel {
  final String productId;
  final String productName;
  final String productImage;
  final String companyName;
  final String categoryName;
  final String? refNo;
  final double unitPrice;
  final int quantity;
  final double totalPrice;

  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.companyName,
    required this.categoryName,
    this.refNo,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> data) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim()) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 1;
      return 1;
    }

    return OrderItemModel(
      productId: (data['PRODUCT_ID'] ?? data['productId'] ?? '').toString(),
      productName: (data['PRODUCT_NAME'] ?? data['productName'] ?? 'Spare Part').toString(),
      productImage: (data['PRODUCT_IMAGE'] ?? data['productImage'] ?? '').toString(),
      companyName: (data['COMPANY_NAME'] ?? data['companyName'] ?? '').toString(),
      categoryName: (data['CATEGORY_NAME'] ?? data['categoryName'] ?? '').toString(),
      refNo: data['REF_NO']?.toString() ?? data['refNo']?.toString(),
      unitPrice: parseDouble(data['UNIT_PRICE'] ?? data['unitPrice']),
      quantity: parseInt(data['QUANTITY'] ?? data['quantity']),
      totalPrice: parseDouble(data['TOTAL_PRICE'] ?? data['totalPrice'] ??
          (parseDouble(data['UNIT_PRICE'] ?? data['unitPrice']) * parseInt(data['QUANTITY'] ?? data['quantity']))),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'PRODUCT_ID': productId,
      'PRODUCT_NAME': productName,
      'PRODUCT_IMAGE': productImage,
      'COMPANY_NAME': companyName,
      'CATEGORY_NAME': categoryName,
      'REF_NO': refNo,
      'UNIT_PRICE': unitPrice,
      'QUANTITY': quantity,
      'TOTAL_PRICE': totalPrice,
    };
  }
}

/// Strongly typed model representing a customer vehicle spare parts order,
/// supporting both single-product orders and multi-item shopping cart orders.
class OrderModel {
  final String id;
  final String orderNumber;
  final String userId;
  final String userName;
  final String userPhone;
  final String productId;
  final String productName;
  final String productImage;
  final String companyName;
  final String categoryName;
  final double unitPrice;
  final int quantity;
  final double totalAmount;
  final String? shippingAddress;
  final String? customerNote;
  final String status; // 'PENDING' | 'CONFIRMED' | 'DISPATCHED' | 'DELIVERED' | 'CANCELLED'
  final List<OrderItemModel> items;
  final List<String> categoryNames;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.userName,
    required this.userPhone,
    String? productId,
    String? productName,
    String? productImage,
    String? companyName,
    String? categoryName,
    double? unitPrice,
    int? quantity,
    required this.totalAmount,
    this.shippingAddress,
    this.customerNote,
    this.status = 'PENDING',
    List<OrderItemModel>? items,
    List<String>? categoryNames,
    this.createdAt,
    this.updatedAt,
  })  : items = (items != null && items.isNotEmpty)
            ? items
            : [
                OrderItemModel(
                  productId: productId ?? '',
                  productName: productName ?? 'Spare Part',
                  productImage: productImage ?? '',
                  companyName: companyName ?? '',
                  categoryName: categoryName ?? '',
                  unitPrice: unitPrice ?? totalAmount,
                  quantity: quantity ?? 1,
                  totalPrice: totalAmount,
                ),
              ],
        productId = productId ?? (items != null && items.isNotEmpty ? items.first.productId : ''),
        productName = productName ?? (items != null && items.isNotEmpty ? items.first.productName : 'Spare Part'),
        productImage = productImage ?? (items != null && items.isNotEmpty ? items.first.productImage : ''),
        companyName = companyName ?? (items != null && items.isNotEmpty ? items.first.companyName : ''),
        categoryName = categoryName ?? (items != null && items.isNotEmpty ? items.first.categoryName : ''),
        unitPrice = unitPrice ?? (items != null && items.isNotEmpty ? items.first.unitPrice : totalAmount),
        quantity = quantity ?? (items != null && items.isNotEmpty ? items.fold<int>(0, (total, i) => total + i.quantity) : 1),
        categoryNames = (categoryNames != null && categoryNames.isNotEmpty)
            ? categoryNames
            : (items != null && items.isNotEmpty
                ? items.map((i) => i.categoryName).where((c) => c.isNotEmpty).toSet().toList()
                : (categoryName != null && categoryName.isNotEmpty ? [categoryName] : []));

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';
  bool get isDispatched => status.toUpperCase() == 'DISPATCHED';
  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  /// Total count of all items across cart line items
  int get totalItemUnits => items.fold<int>(0, (total, i) => total + i.quantity);

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return OrderModel.fromMap(data, doc.id);
  }

  factory OrderModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim()) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 1;
      return 1;
    }

    // Parse multi-item list if present
    List<OrderItemModel>? parsedItems;
    if (data['ITEMS'] is List) {
      parsedItems = (data['ITEMS'] as List)
          .whereType<Map>()
          .map((item) => OrderItemModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } else if (data['items'] is List) {
      parsedItems = (data['items'] as List)
          .whereType<Map>()
          .map((item) => OrderItemModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Parse category names list
    List<String>? parsedCategoryNames;
    if (data['CATEGORY_NAMES'] is List) {
      parsedCategoryNames = (data['CATEGORY_NAMES'] as List).map((e) => e.toString()).toList();
    } else if (data['categoryNames'] is List) {
      parsedCategoryNames = (data['categoryNames'] as List).map((e) => e.toString()).toList();
    }

    return OrderModel(
      id: id,
      orderNumber: (data['ORDER_NUMBER'] ?? data['orderNumber'] ?? '#ORD-${id.substring(id.length > 5 ? id.length - 5 : 0)}').toString(),
      userId: (data['USER_ID'] ?? data['userId'] ?? '').toString(),
      userName: (data['USER_NAME'] ?? data['userName'] ?? 'Customer').toString(),
      userPhone: (data['USER_PHONE'] ?? data['userPhone'] ?? '').toString(),
      productId: (data['PRODUCT_ID'] ?? data['productId'] ?? '').toString(),
      productName: (data['PRODUCT_NAME'] ?? data['productName'] ?? 'Spare Part').toString(),
      productImage: (data['PRODUCT_IMAGE'] ?? data['productImage'] ?? '').toString(),
      companyName: (data['COMPANY_NAME'] ?? data['companyName'] ?? '').toString(),
      categoryName: (data['CATEGORY_NAME'] ?? data['categoryName'] ?? '').toString(),
      unitPrice: parseDouble(data['UNIT_PRICE'] ?? data['unitPrice']),
      quantity: parseInt(data['QUANTITY'] ?? data['quantity']),
      totalAmount: parseDouble(data['TOTAL_AMOUNT'] ?? data['totalAmount']),
      shippingAddress: data['SHIPPING_ADDRESS']?.toString(),
      customerNote: data['CUSTOMER_NOTE']?.toString(),
      status: (data['STATUS'] ?? data['status'] ?? 'PENDING').toString().trim().toUpperCase(),
      items: parsedItems,
      categoryNames: parsedCategoryNames,
      createdAt: parseTimestamp(data['CREATED_AT'] ?? data['createdAt']),
      updatedAt: parseTimestamp(data['UPDATED_AT'] ?? data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'ORDER_NUMBER': orderNumber,
      'USER_ID': userId,
      'USER_NAME': userName,
      'USER_PHONE': userPhone,
      'PRODUCT_ID': productId,
      'PRODUCT_NAME': productName,
      'PRODUCT_IMAGE': productImage,
      'COMPANY_NAME': companyName,
      'CATEGORY_NAME': categoryName,
      'UNIT_PRICE': unitPrice,
      'QUANTITY': quantity,
      'TOTAL_AMOUNT': totalAmount,
      'SHIPPING_ADDRESS': shippingAddress,
      'CUSTOMER_NOTE': customerNote,
      'STATUS': status,
      'ITEMS': items.map((item) => item.toMap()).toList(),
      'CATEGORY_NAMES': categoryNames,
      'CREATED_AT': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'UPDATED_AT': FieldValue.serverTimestamp(),
    };
  }

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? userId,
    String? userName,
    String? userPhone,
    String? productId,
    String? productName,
    String? productImage,
    String? companyName,
    String? categoryName,
    double? unitPrice,
    int? quantity,
    double? totalAmount,
    String? shippingAddress,
    String? customerNote,
    String? status,
    List<OrderItemModel>? items,
    List<String>? categoryNames,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      companyName: companyName ?? this.companyName,
      categoryName: categoryName ?? this.categoryName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      totalAmount: totalAmount ?? this.totalAmount,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      customerNote: customerNote ?? this.customerNote,
      status: status ?? this.status,
      items: items ?? this.items,
      categoryNames: categoryNames ?? this.categoryNames,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
