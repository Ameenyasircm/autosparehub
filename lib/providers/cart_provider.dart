import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

/// Provider managing customer shopping cart state, subtotal calculations,
/// item quantities, and synchronized persistence across local storage & Firestore DB.
class CartProvider extends ChangeNotifier {
  static const String _storageKey = 'autospare_cart_v1';
  static const String cartsCollection = 'CARTS';

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  final Map<String, CartItemModel> _items = {};
  bool _isLoaded = false;
  String? _currentUserId;

  CartProvider({FirebaseFirestore? firestore})
      : _customFirestore = firestore {
    loadCart();
  }

  // Getters
  List<CartItemModel> get items => _items.values.toList();
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isLoaded => _isLoaded;
  String? get currentUserId => _currentUserId;

  /// Total number of distinct parts in the cart
  int get distinctItemCount => _items.length;

  /// Total count of physical units across all cart items
  int get totalItemCount => _items.values.fold(0, (total, item) => total + item.quantity);

  /// Total monetary value of all items currently in cart
  double get subtotalAmount => _items.values.fold(0.0, (total, item) => total + item.totalPrice);

  bool isInCart(String productId) => _items.containsKey(productId);

  int getQuantity(String productId) => _items[productId]?.quantity ?? 0;

  /// Set the active user ID and fetch their cloud cart from Firestore.
  void setUserId(String? userId) {
    if (userId == _currentUserId) return;
    _currentUserId = userId;
    if (userId != null && userId.isNotEmpty) {
      loadCartForUser(userId);
    }
  }

  /// Load and sync customer's cart from Firestore DB according to userId.
  Future<void> loadCartForUser(String userId) async {
    _currentUserId = userId;
    try {
      final doc = await _firestore.collection(cartsCollection).doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        final rawItems = data?['ITEMS'] ?? data?['items'];
        if (rawItems is List) {
          final Map<String, CartItemModel> cloudItems = {};
          for (final raw in rawItems) {
            if (raw is Map) {
              final item = CartItemModel.fromMap(Map<String, dynamic>.from(raw));
              if (item.product.id.isNotEmpty) {
                cloudItems[item.product.id] = item;
              }
            }
          }

          // Merge any uncommitted local guest items into the cloud items
          for (final entry in _items.entries) {
            if (!cloudItems.containsKey(entry.key)) {
              cloudItems[entry.key] = entry.value;
            }
          }

          _items.clear();
          _items.addAll(cloudItems);
          notifyListeners();
          await _saveCart();
          await _syncToFirestore();
          return;
        }
      } else {
        // If no cloud cart yet, push existing local items if present
        if (_items.isNotEmpty) {
          await _syncToFirestore();
        }
      }
    } catch (e) {
      debugPrint('CartProvider.loadCartForUser error: $e');
    }
  }

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
    await _syncToFirestore();
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
      await _syncToFirestore();
    }
  }

  /// Increment item quantity by 1
  Future<void> incrementQuantity(String productId) async {
    if (_items.containsKey(productId)) {
      final existing = _items[productId]!;
      _items[productId] = existing.copyWith(quantity: existing.quantity + 1);
      notifyListeners();
      await _saveCart();
      await _syncToFirestore();
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
      await _syncToFirestore();
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
      await _syncToFirestore();
    }
  }

  /// Clear all items from the cart.
  /// If [isOrderPlaced] is true, also clears the remote cart in Firestore.
  Future<void> clearCart({bool isOrderPlaced = false}) async {
    if (_items.isNotEmpty) {
      _items.clear();
      notifyListeners();
      await _saveCart();
      if (isOrderPlaced && _currentUserId != null) {
        await _syncToFirestore();
      }
    }
  }

  /// Clears local session on user logout without wiping their cloud-saved cart
  Future<void> onUserLogout() async {
    _currentUserId = null;
    _items.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('CartProvider.onUserLogout error: $e');
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

  /// Synchronize cart items to Firestore under CARTS/{userId}
  Future<void> _syncToFirestore() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final list = _items.values.map((item) => item.toMap()).toList();
      await _firestore.collection(cartsCollection).doc(_currentUserId).set({
        'USER_ID': _currentUserId,
        'ITEMS': list,
        'ITEM_COUNT': totalItemCount,
        'SUBTOTAL': subtotalAmount,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('CartProvider._syncToFirestore error: $e');
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
