import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../services/cloudinary_service.dart';

/// Provider managing spare parts categories and their catalog images
class CategoryProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinaryService;

  CategoryProvider({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinaryService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinaryService = cloudinaryService ?? CloudinaryService();

  static const String collectionName = 'CATEGORIES';

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String _searchQuery = '';

  // Getters
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  List<CategoryModel> get filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories.where((c) {
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Fetches categories from Firestore sorted by name
  Future<void> fetchCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .get()
          .timeout(const Duration(seconds: 10));

      _categories = snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();

      // Sort alphabetically by name
      _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _isLoading = false;
      notifyListeners();
    } on TimeoutException {
      debugPrint('CategoryProvider.fetchCategories: Timeout');
      _errorMessage = 'Connection timed out while loading categories.';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('CategoryProvider.fetchCategories Error: $e');
      _errorMessage = 'Failed to load spare parts categories. Please try again.';
      _isLoading = false;
      notifyListeners();
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Adds a new spare parts category with Cloudinary image upload
  Future<bool> addCategory({
    required String name,
    required File imageFile,
    String? description,
    bool isActive = true,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _errorMessage = 'Category name is required.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check for duplicate category name (case-insensitive)
      final isDuplicate = _categories.any(
        (c) => c.name.toLowerCase() == cleanName.toLowerCase(),
      );
      if (isDuplicate) {
        _errorMessage = 'A category with the name "$cleanName" already exists.';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      // 2. Upload image to Cloudinary under autospare/categories
      final uploadedUrl = await _cloudinaryService.uploadImage(
        imageFile: imageFile,
        folder: CloudinaryService.categoriesFolder,
      );

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        _errorMessage = 'Failed to upload category image to Cloudinary. Please check your connection.';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      // 3. Save to Firestore
      final docRef = _firestore.collection(collectionName).doc();
      final data = {
        'NAME': cleanName,
        'IMAGE_URL': uploadedUrl,
        'DESCRIPTION': description?.trim() ?? '',
        'IS_ACTIVE': isActive,
        'CREATED_AT': FieldValue.serverTimestamp(),
        'UPDATED_AT': FieldValue.serverTimestamp(),
      };

      await docRef.set(data).timeout(const Duration(seconds: 10));

      try {
        await fetchCategories().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('CategoryProvider.addCategory: refresh notice: $e');
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      debugPrint('CategoryProvider.addCategory: Timeout');
      _errorMessage = 'Connection timed out while saving category. Please check your network.';
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('CategoryProvider.addCategory Error: $e');
      _errorMessage = 'Failed to save category: $e';
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

  /// Edits an existing category, uploading a new image to Cloudinary if selected
  Future<bool> editCategory({
    required String id,
    required String name,
    File? newImageFile,
    required String currentImageUrl,
    String? description,
    required bool isActive,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _errorMessage = 'Category name is required.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check duplicate name excluding self
      final isDuplicate = _categories.any(
        (c) => c.id != id && c.name.toLowerCase() == cleanName.toLowerCase(),
      );
      if (isDuplicate) {
        _errorMessage = 'Another category with the name "$cleanName" already exists.';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      String finalImageUrl = currentImageUrl;

      // If a new image was picked, upload to Cloudinary first
      if (newImageFile != null) {
        final uploadedUrl = await _cloudinaryService.uploadImage(
          imageFile: newImageFile,
          folder: CloudinaryService.categoriesFolder,
        );

        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          _errorMessage = 'Failed to upload new category image. Update aborted.';
          _isSaving = false;
          notifyListeners();
          return false;
        }
        finalImageUrl = uploadedUrl;
      }

      // Update Firestore
      await _firestore.collection(collectionName).doc(id).update({
        'NAME': cleanName,
        'IMAGE_URL': finalImageUrl,
        'DESCRIPTION': description?.trim() ?? '',
        'IS_ACTIVE': isActive,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      try {
        await fetchCategories().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('CategoryProvider.editCategory: refresh notice: $e');
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      debugPrint('CategoryProvider.editCategory: Timeout');
      _errorMessage = 'Connection timed out while updating category.';
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('CategoryProvider.editCategory Error: $e');
      _errorMessage = 'Failed to update category: $e';
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
  Future<bool> toggleCategoryActive(String id, bool newStatus) async {
    try {
      await _firestore.collection(collectionName).doc(id).update({
        'IS_ACTIVE': newStatus,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      final index = _categories.indexWhere((c) => c.id == id);
      if (index != -1) {
        _categories[index] = _categories[index].copyWith(isActive: newStatus);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('CategoryProvider.toggleCategoryActive Error: $e');
      _errorMessage = 'Failed to update active status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Deletes a category record
  Future<bool> deleteCategory(String id) async {
    try {
      await _firestore.collection(collectionName).doc(id).delete().timeout(const Duration(seconds: 10));
      _categories.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CategoryProvider.deleteCategory Error: $e');
      _errorMessage = 'Failed to delete category: $e';
      notifyListeners();
      return false;
    }
  }
}
