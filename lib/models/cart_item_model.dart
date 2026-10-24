import 'product_model.dart';

/// Model representing an item in the customer's shopping cart.
class CartItemModel {
  final ProductModel product;
  final int quantity;

  const CartItemModel({
    required this.product,
    required this.quantity,
  });

  /// Computed total price for this cart line item
  double get totalPrice => (product.price ?? 0.0) * quantity;

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  /// JSON-safe serialization for SharedPreferences cache
  Map<String, dynamic> toMap() {
    return {
      'product': {
        'ID': product.id,
        'NAME': product.name,
        'IMAGE_URL': product.imageUrl,
        'COMPANY_ID': product.companyId,
        'COMPANY_NAME': product.companyName,
        'CATEGORY_ID': product.categoryId,
        'CATEGORY_NAME': product.categoryName,
        'APPLICATION': product.application,
        'DESCRIPTION': product.description,
        'REF_NO': product.refNo,
        'PRICE': product.price,
        'STOCK_QUANTITY': product.stockQuantity,
        'IS_ACTIVE': product.isActive,
      },
      'quantity': quantity,
    };
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    final productMap = Map<String, dynamic>.from(map['product'] as Map? ?? {});
    return CartItemModel(
      product: ProductModel.fromMap(productMap, productMap['ID']?.toString() ?? ''),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}
