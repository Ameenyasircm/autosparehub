import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

/// Provider managing customer shopping cart state, subtotal calculations,
/// item quantities, and local SharedPreferences persistence.
class CartProvider extends ChangeNotifier {
  static const String _storageKey = 'autospare_cart_v1';

  final Map<String, CartItemModel> _items = {};
  bool _isLoaded = false;

  CartProvider() {
    loadCart();
  }

  // Getters
  List<CartItemModel> get items => _items.values.toList();
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isLoaded => _isLoaded;

  /// Total number of distinct parts in the cart
  int get distinctItemCount => _items.length;

  /// Total count of physical units across all cart items
  int get totalItemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  /// Total monetary value of all items currently in cart
  double get subtotalAmount => _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  bool isInCart(String productId) => _items.containsKey(productId);

  int getQuantity(String productId) => _items[productId]?.quantity ?? 0;

  /// Add a product to the cart or increment its quantity if already present
  Future<void> addToCart(ProductModel product, {int quantity = 1}) async {
    if (quantity <= 0) return;

    if (_items.containsKey(product.id)) {
      final existing = _items[product.id]!;
      _items[product.id] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      _items[product.id] = CartItemModel(
        product: product,
        quantity: quantity,
      );
    }

    notifyListeners();
    await _saveCart();
  }

  /// Update the quantity of a specific product in the cart
  Future<void> setQuantity(String productId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(productId);
      return;
    }

    if (_items.containsKey(productId)) {
      final existing = _items[productId]!;
      _items[productId] = existing.copyWith(quantity: quantity);
      notifyListeners();
      await _saveCart();
    }
  }

  /// Increment item quantity by 1
  Future<void> incrementQuantity(String productId) async {
    if (_items.containsKey(productId)) {
      final existing = _items[productId]!;
      _items[productId] = existing.copyWith(quantity: existing.quantity + 1);
      notifyListeners();
      await _saveCart();
    }
  }

  /// Decrement item quantity by 1. If it reaches 0, the item is removed.
  Future<void> decrementQuantity(String productId) async {
    if (!_items.containsKey(productId)) return;

    final existing = _items[productId]!;
    if (existing.quantity > 1) {
      _items[productId] = existing.copyWith(quantity: existing.quantity - 1);
      notifyListeners();
      await _saveCart();
    } else {
      await removeFromCart(productId);
    }
  }

  /// Remove a specific product completely from the cart
  Future<void> removeFromCart(String productId) async {
    if (_items.containsKey(productId)) {
      _items.remove(productId);
      notifyListeners();
      await _saveCart();
    }
  }

  /// Clear all items from the cart (e.g. upon order placement or logout)
  Future<void> clearCart() async {
    if (_items.isNotEmpty) {
      _items.clear();
      notifyListeners();
      await _saveCart();
    }
  }

  /// Persist cart items to local device storage
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.values.map((item) => item.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      debugPrint('CartProvider._saveCart error: $e');
    }
  }

  /// Load cached cart items from local device storage
  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items.clear();
          for (final itemMap in decoded) {
            if (itemMap is Map) {
              final cartItem = CartItemModel.fromMap(Map<String, dynamic>.from(itemMap));
              if (cartItem.product.id.isNotEmpty) {
                _items[cartItem.product.id] = cartItem;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('CartProvider.loadCart error: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }
}
