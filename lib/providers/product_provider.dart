import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/cloudinary_service.dart';

enum ProductSortOption {
  newest,
  priceLowToHigh,
  priceHighToLow,
  nameAZ,
  stockHighToLow,
}

/// Provider managing spare parts products catalog, technical specifications, and queries.
class ProductProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinaryService;

  ProductProvider({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinaryService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinaryService = cloudinaryService ?? CloudinaryService();

  static const String collectionName = 'PRODUCTS';

  List<ProductModel> _products = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedCompanyId = 'ALL';
  String _selectedCategoryId = 'ALL';
  ProductSortOption _sortOption = ProductSortOption.newest;

  // Getters
  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCompanyId => _selectedCompanyId;
  String get selectedCategoryId => _selectedCategoryId;
  ProductSortOption get sortOption => _sortOption;

  /// Returns products matching active search query, company filter, category filter, and sort order
  List<ProductModel> get filteredProducts {
    final list = _products.where((product) {
      // Company Filter
      final matchesCompany = _selectedCompanyId == 'ALL' ||
          product.companyId == _selectedCompanyId;

      // Category Filter
      final matchesCategory = _selectedCategoryId == 'ALL' ||
          product.categoryId == _selectedCategoryId;

      // Search Query Filter (Matches Name, Ref No, or Application)
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          (product.refNo?.toLowerCase().contains(query) ?? false) ||
          product.application.toLowerCase().contains(query) ||
          (product.description?.toLowerCase().contains(query) ?? false) ||
          product.companyName.toLowerCase().contains(query) ||
          product.categoryName.toLowerCase().contains(query);

      return matchesCompany && matchesCategory && matchesSearch;
    }).toList();

    // Apply sorting
    switch (_sortOption) {
      case ProductSortOption.newest:
        list.sort((a, b) {
          if (a.createdAt != null && b.createdAt != null) {
            return b.createdAt!.compareTo(a.createdAt!);
          }
          return b.id.compareTo(a.id);
        });
        break;
      case ProductSortOption.priceLowToHigh:
        list.sort((a, b) => (a.price ?? double.infinity).compareTo(b.price ?? double.infinity));
        break;
      case ProductSortOption.priceHighToLow:
        list.sort((a, b) => (b.price ?? -1.0).compareTo(a.price ?? -1.0));
        break;
      case ProductSortOption.nameAZ:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ProductSortOption.stockHighToLow:
        list.sort((a, b) => (b.stockQuantity ?? -1).compareTo(a.stockQuantity ?? -1));
        break;
    }

    return list;
  }

  void setSortOption(ProductSortOption option) {
    if (_sortOption != option) {
      _sortOption = option;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setSelectedCompanyId(String companyId) {
    _selectedCompanyId = companyId;
    notifyListeners();
  }

  void setSelectedCategoryId(String categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCompanyId = 'ALL';
    _selectedCategoryId = 'ALL';
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Fetches all products from Firestore, sorted newest first
  Future<void> fetchProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .get()
          .timeout(const Duration(seconds: 10));

      _products = snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

      // Sort newest first
      _products.sort((a, b) {
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return b.id.compareTo(a.id);
      });

      _isLoading = false;
      notifyListeners();
    } on TimeoutException {
      debugPrint('ProductProvider.fetchProducts Timeout');
      _errorMessage = 'Connection timed out while loading products. Please check your internet connection.';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('ProductProvider.fetchProducts Error: $e');
      _errorMessage = 'Failed to load products: $e';
      _isLoading = false;
      notifyListeners();
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Adds a new product with Cloudinary image upload and flat document storage
  Future<bool> addProduct({
    required String name,
    required File imageFile,
    required String companyId,
    required String companyName,
    required String categoryId,
    required String categoryName,
    required String application,
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
    bool isActive = true,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _errorMessage = 'Product name is required.';
      notifyListeners();
      return false;
    }
    if (companyId.isEmpty) {
      _errorMessage = 'Please select a company/manufacturer.';
      notifyListeners();
      return false;
    }
    if (categoryId.isEmpty) {
      _errorMessage = 'Please select a product category.';
      notifyListeners();
      return false;
    }
    if (application.trim().isEmpty) {
      _errorMessage = 'Vehicle application details are required.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Upload Product Photo to Cloudinary
      final uploadedUrl = await _cloudinaryService.uploadImage(
        imageFile: imageFile,
        folder: CloudinaryService.productsFolder,
      );

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        _errorMessage = 'Failed to upload product image to Cloudinary. Please check your network and retry.';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      // 2. Generate unique document ID: "PRD" + timestamp in milliseconds
      final productDocId = 'PRD${DateTime.now().millisecondsSinceEpoch}';
      final docRef = _firestore.collection(collectionName).doc(productDocId);

      // 3. Save flat Firestore document
      final data = {
        'ID': productDocId,
        'NAME': cleanName,
        'IMAGE_URL': uploadedUrl,
        'COMPANY_ID': companyId,
        'COMPANY_NAME': companyName.trim(),
        'CATEGORY_ID': categoryId,
        'CATEGORY_NAME': categoryName.trim(),
        'APPLICATION': application.trim(),
        'DESCRIPTION': description?.trim().isEmpty ?? true ? null : description!.trim(),
        'REF_NO': refNo?.trim().isEmpty ?? true ? null : refNo!.trim(),
        'DISPLACEMENT': displacement?.trim().isEmpty ?? true ? null : displacement!.trim(),
        'MAX_PRESSURE': maxPressure?.trim().isEmpty ?? true ? null : maxPressure!.trim(),
        'CONTROLLED_FLOW': controlledFlow?.trim().isEmpty ?? true ? null : controlledFlow!.trim(),
        'SPEED_RANGE': speedRange?.trim().isEmpty ?? true ? null : speedRange!.trim(),
        'ROTATION': rotation?.trim().isEmpty ?? true ? null : rotation!.trim(),
        'FUEL_FEED_HOLE': fuelFeedHole?.trim().isEmpty ?? true ? null : fuelFeedHole!.trim(),
        'PRICE': price,
        'STOCK_QUANTITY': stockQuantity,
        'IS_ACTIVE': isActive,
        'CREATED_AT': FieldValue.serverTimestamp(),
        'UPDATED_AT': FieldValue.serverTimestamp(),
      };

      await docRef.set(data).timeout(const Duration(seconds: 10));

      try {
        await fetchProducts().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('ProductProvider.addProduct refresh warning: $e');
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      debugPrint('ProductProvider.addProduct Timeout');
      _errorMessage = 'Operation timed out while saving product. Please check your network.';
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('ProductProvider.addProduct Error: $e');
      _errorMessage = 'Failed to save product: $e';
      _isSaving = false;
      notifyListeners();
      return false;
    } finally {
      if (_isSaving) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Edits an existing product, uploading a new image to Cloudinary if provided
  Future<bool> editProduct({
    required String id,
    required String name,
    required String currentImageUrl,
    File? newImageFile,
    required String companyId,
    required String companyName,
    required String categoryId,
    required String categoryName,
    required String application,
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
    required bool isActive,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _errorMessage = 'Product name is required.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String finalImageUrl = currentImageUrl;

      // Upload new image if chosen
      if (newImageFile != null) {
        final uploadedUrl = await _cloudinaryService.uploadImage(
          imageFile: newImageFile,
          folder: CloudinaryService.productsFolder,
        );

        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          _errorMessage = 'Failed to upload new product image. Update aborted.';
          _isSaving = false;
          notifyListeners();
          return false;
        }
        finalImageUrl = uploadedUrl;
      }

      // Update Firestore document
      await _firestore.collection(collectionName).doc(id).update({
        'NAME': cleanName,
        'IMAGE_URL': finalImageUrl,
        'COMPANY_ID': companyId,
        'COMPANY_NAME': companyName.trim(),
        'CATEGORY_ID': categoryId,
        'CATEGORY_NAME': categoryName.trim(),
        'APPLICATION': application.trim(),
        'DESCRIPTION': description?.trim().isEmpty ?? true ? null : description!.trim(),
        'REF_NO': refNo?.trim().isEmpty ?? true ? null : refNo!.trim(),
        'DISPLACEMENT': displacement?.trim().isEmpty ?? true ? null : displacement!.trim(),
        'MAX_PRESSURE': maxPressure?.trim().isEmpty ?? true ? null : maxPressure!.trim(),
        'CONTROLLED_FLOW': controlledFlow?.trim().isEmpty ?? true ? null : controlledFlow!.trim(),
        'SPEED_RANGE': speedRange?.trim().isEmpty ?? true ? null : speedRange!.trim(),
        'ROTATION': rotation?.trim().isEmpty ?? true ? null : rotation!.trim(),
        'FUEL_FEED_HOLE': fuelFeedHole?.trim().isEmpty ?? true ? null : fuelFeedHole!.trim(),
        'PRICE': price,
        'STOCK_QUANTITY': stockQuantity,
        'IS_ACTIVE': isActive,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      try {
        await fetchProducts().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('ProductProvider.editProduct refresh warning: $e');
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      debugPrint('ProductProvider.editProduct Timeout');
      _errorMessage = 'Operation timed out while updating product.';
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('ProductProvider.editProduct Error: $e');
      _errorMessage = 'Failed to update product: $e';
      _isSaving = false;
      notifyListeners();
      return false;
    } finally {
      if (_isSaving) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Toggles active status
  Future<bool> toggleProductActive(String id, bool newStatus) async {
    try {
      await _firestore.collection(collectionName).doc(id).update({
        'IS_ACTIVE': newStatus,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      final index = _products.indexWhere((p) => p.id == id);
      if (index != -1) {
        _products[index] = _products[index].copyWith(isActive: newStatus);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('ProductProvider.toggleProductActive Error: $e');
      _errorMessage = 'Failed to update active status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Deletes a product record
  Future<bool> deleteProduct(String id) async {
    try {
      await _firestore.collection(collectionName).doc(id).delete().timeout(const Duration(seconds: 10));
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ProductProvider.deleteProduct Error: $e');
      _errorMessage = 'Failed to delete product: $e';
      notifyListeners();
      return false;
    }
  }
}
