import 'package:cloud_firestore/cloud_firestore.dart';

/// Strongly-typed model representing an automotive spare part / product in AutoSpare Hub.
class ProductModel {
  final String id;
  final String name;
  final String imageUrl;
  final String companyId;
  final String companyName;
  final String categoryId;
  final String categoryName;
  final String application;
  final String? description;

  // Non-mandatory technical specifications
  final String? refNo;
  final String? displacement;
  final String? maxPressure;
  final String? controlledFlow;
  final String? speedRange;
  final String? rotation;
  final String? fuelFeedHole;

  // Commercial fields
  final double? price;
  final int? stockQuantity;

  // Search keywords for fast prefix and substring matching
  final List<String> searchKeywords;

  // Audit and status
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.companyId,
    required this.companyName,
    required this.categoryId,
    required this.categoryName,
    required this.application,
    this.description,
    this.refNo,
    this.displacement,
    this.maxPressure,
    this.controlledFlow,
    this.speedRange,
    this.rotation,
    this.fuelFeedHole,
    this.price,
    this.stockQuantity,
    this.searchKeywords = const [],
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to parse Firestore document snapshots
  factory ProductModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ProductModel.fromMap(data, doc.id);
  }

  /// Factory constructor to safely parse Map representations
  factory ProductModel.fromMap(Map<String, dynamic> data, String id) {
    bool parseIsActive(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      if (value is num) return value == 1;
      return true;
    }

    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    double? parsePrice(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim());
      return null;
    }

    int? parseStock(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
      return null;
    }

    String? parseOptionalString(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      return str.isEmpty ? null : str;
    }

    List<String> parseKeywords(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString().toLowerCase().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return ProductModel(
      id: id,
      name: (data['NAME'] ?? data['name'] ?? '').toString().trim(),
      imageUrl: (data['IMAGE_URL'] ?? data['imageUrl'] ?? data['image'] ?? '').toString().trim(),
      companyId: (data['COMPANY_ID'] ?? data['companyId'] ?? '').toString().trim(),
      companyName: (data['COMPANY_NAME'] ?? data['companyName'] ?? '').toString().trim(),
      categoryId: (data['CATEGORY_ID'] ?? data['categoryId'] ?? '').toString().trim(),
      categoryName: (data['CATEGORY_NAME'] ?? data['categoryName'] ?? '').toString().trim(),
      application: (data['APPLICATION'] ?? data['application'] ?? '').toString().trim(),
      description: parseOptionalString(data['DESCRIPTION'] ?? data['description']),
      refNo: parseOptionalString(data['REF_NO'] ?? data['refNo']),
      displacement: parseOptionalString(data['DISPLACEMENT'] ?? data['displacement']),
      maxPressure: parseOptionalString(data['MAX_PRESSURE'] ?? data['maxPressure']),
      controlledFlow: parseOptionalString(data['CONTROLLED_FLOW'] ?? data['controlledFlow']),
      speedRange: parseOptionalString(data['SPEED_RANGE'] ?? data['speedRange']),
      rotation: parseOptionalString(data['ROTATION'] ?? data['rotation']),
      fuelFeedHole: parseOptionalString(data['FUEL_FEED_HOLE'] ?? data['fuelFeedHole']),
      price: parsePrice(data['PRICE'] ?? data['price']),
      stockQuantity: parseStock(data['STOCK_QUANTITY'] ?? data['stockQuantity']),
      searchKeywords: parseKeywords(data['SEARCH_KEYWORDS'] ?? data['searchKeywords']),
      isActive: parseIsActive(data['IS_ACTIVE'] ?? data['isActive']),
      createdAt: parseTimestamp(data['CREATED_AT'] ?? data['createdAt']),
      updatedAt: parseTimestamp(data['UPDATED_AT'] ?? data['updatedAt']),
    );
  }

  /// Serializes the model into a Map for Firestore persistence
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'NAME': name,
      'IMAGE_URL': imageUrl,
      'COMPANY_ID': companyId,
      'COMPANY_NAME': companyName,
      'CATEGORY_ID': categoryId,
      'CATEGORY_NAME': categoryName,
      'APPLICATION': application,
      'DESCRIPTION': description,
      'REF_NO': refNo,
      'DISPLACEMENT': displacement,
      'MAX_PRESSURE': maxPressure,
      'CONTROLLED_FLOW': controlledFlow,
      'SPEED_RANGE': speedRange,
      'ROTATION': rotation,
      'FUEL_FEED_HOLE': fuelFeedHole,
      'PRICE': price,
      'STOCK_QUANTITY': stockQuantity,
      'SEARCH_KEYWORDS': searchKeywords,
      'IS_ACTIVE': isActive,
      'CREATED_AT': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'UPDATED_AT': FieldValue.serverTimestamp(),
    };
  }

  /// Creates a copy of this model with updated values
  ProductModel copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? companyId,
    String? companyName,
    String? categoryId,
    String? categoryName,
    String? application,
    String? description,
    String? refNo,
    String? displacement,
    String? maxPressure,
    String? controlledFlow,
    String? speedRange,
    String? rotation,
    String? fuelFeedHole,
    double? price,
    int? stockQuantity,
    List<String>? searchKeywords,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      application: application ?? this.application,
      description: description ?? this.description,
      refNo: refNo ?? this.refNo,
      displacement: displacement ?? this.displacement,
      maxPressure: maxPressure ?? this.maxPressure,
      controlledFlow: controlledFlow ?? this.controlledFlow,
      speedRange: speedRange ?? this.speedRange,
      rotation: rotation ?? this.rotation,
      fuelFeedHole: fuelFeedHole ?? this.fuelFeedHole,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
