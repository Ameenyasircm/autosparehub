import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../services/cloudinary_service.dart';

/// Provider managing spare parts categories and their catalog images
class CategoryProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;
  final CloudinaryService _cloudinaryService;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  CategoryProvider({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinaryService,
  })  : _customFirestore = firestore,
        _cloudinaryService = cloudinaryService ?? CloudinaryService();

  static const String collectionName = 'CATEGORIES';
  static const String unassignedCompanyFilter = '_UNASSIGNED';

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCompanyId = 'ALL';

  // Getters
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCompanyId => _selectedCompanyId;

  @visibleForTesting
  void setCategoriesForTesting(List<CategoryModel> list) {
    _categories = List.from(list);
    _isLoading = false;
    notifyListeners();
  }

  List<CategoryModel> categoriesForCompany(String companyId) {
    return _categories.where((c) => c.companyId == companyId).toList();
  }

  List<CategoryModel> get unassignedCategories {
    return _categories.where((c) => c.companyId.isEmpty).toList();
  }

  bool hasDuplicateNameInCompany({
    required String name,
    required String companyId,
    String? excludeId,
  }) {
    final cleanName = name.trim().toLowerCase();
    final cleanCompanyId = companyId.trim();
    return _categories.any(
      (c) =>
          c.id != excludeId &&
          c.companyId == cleanCompanyId &&
          c.name.toLowerCase() == cleanName,
    );
  }

  List<CategoryModel> get filteredCategories {
    return _categories.where((c) {
      final matchesCompany = _selectedCompanyId == 'ALL'
          ? true
          : (_selectedCompanyId == unassignedCompanyFilter
              ? c.companyId.isEmpty
              : c.companyId == _selectedCompanyId);
      if (!matchesCompany) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.companyName.toLowerCase().contains(q) ||
          (c.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setSelectedCompanyId(String companyId) {
    _selectedCompanyId = companyId;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _liveSubscription;

  /// Keeps the categories list in sync with Firestore in real time (used by the
  /// customer app), so hiding/editing in the admin app shows up immediately
  /// without a refresh. Safe to call more than once. The returned future
  /// completes when the first data has arrived.
  Future<void> startListening() {
    if (_liveSubscription != null) return Future.value();
    final firstData = Completer<void>();
    if (_categories.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _liveSubscription = _firestore.collection(collectionName).snapshots().listen(
        (snapshot) {
          _categories = snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
          _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
          if (!firstData.isCompleted) firstData.complete();
        },
        onError: (e) {
          debugPrint('CategoryModel live listener error: $e');
          _isLoading = false;
          _liveSubscription = null; // allow a later retry
          notifyListeners();
          if (!firstData.isCompleted) firstData.complete();
        },
      );
    } catch (e) {
      debugPrint('CategoryProvider.startListening error: $e');
      _isLoading = false;
      _liveSubscription = null;
      notifyListeners();
      if (!firstData.isCompleted) firstData.complete();
    }
    return firstData.future;
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
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

  /// Adds a new spare parts category under a company with Cloudinary image upload
  Future<bool> addCategory({
    required String name,
    required String companyId,
    required String companyName,
    required File imageFile,
    String? description,
    bool isActive = true,
  }) async {
    final cleanName = name.trim();
    final cleanCompanyId = companyId.trim();
    final cleanCompanyName = companyName.trim();
    if (cleanCompanyId.isEmpty) {
      _errorMessage = 'Please select a brand for this category.';
      notifyListeners();
      return false;
    }
    if (cleanName.isEmpty) {
      _errorMessage = 'Category name is required.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check for duplicate category name under the same company (case-insensitive)
      final isDuplicate = hasDuplicateNameInCompany(
        name: cleanName,
        companyId: cleanCompanyId,
      );
      if (isDuplicate) {
        final companyLabel = cleanCompanyName.isNotEmpty ? cleanCompanyName : 'this brand';
        _errorMessage = 'A category named "$cleanName" already exists under $companyLabel.';
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

      // 3. Save to Firestore with custom doc ID: "CAT" + timestamp in milliseconds
      final categoryDocId = 'CAT${DateTime.now().millisecondsSinceEpoch}';
      final docRef = _firestore.collection(collectionName).doc(categoryDocId);
      final data = {
        'ID': categoryDocId,
        'NAME': cleanName,
        'IMAGE_URL': uploadedUrl,
        'COMPANY_ID': cleanCompanyId,
        'COMPANY_NAME': cleanCompanyName,
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
    required String companyId,
    required String companyName,
    File? newImageFile,
    required String currentImageUrl,
    String? description,
    required bool isActive,
  }) async {
    final cleanName = name.trim();
    final cleanCompanyId = companyId.trim();
    final cleanCompanyName = companyName.trim();
    if (cleanCompanyId.isEmpty) {
      _errorMessage = 'Please select a brand for this category.';
      notifyListeners();
      return false;
    }
    if (cleanName.isEmpty) {
      _errorMessage = 'Category name is required.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check duplicate name under the same company excluding self
      final isDuplicate = hasDuplicateNameInCompany(
        name: cleanName,
        companyId: cleanCompanyId,
        excludeId: id,
      );
      if (isDuplicate) {
        final companyLabel = cleanCompanyName.isNotEmpty ? cleanCompanyName : 'this brand';
        _errorMessage = 'Another category named "$cleanName" already exists under $companyLabel.';
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
        'COMPANY_ID': cleanCompanyId,
        'COMPANY_NAME': cleanCompanyName,
        'DESCRIPTION': description?.trim() ?? '',
        'IS_ACTIVE': isActive,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      // Best-effort sync of CATEGORY_NAME on products linked to this category
      try {
        final linkedProducts = await _firestore
            .collection('PRODUCTS')
            .where('CATEGORY_ID', isEqualTo: id)
            .get()
            .timeout(const Duration(seconds: 6));
        if (linkedProducts.docs.isNotEmpty) {
          for (var i = 0; i < linkedProducts.docs.length; i += 450) {
            final end = (i + 450 < linkedProducts.docs.length)
                ? i + 450
                : linkedProducts.docs.length;
            final batch = _firestore.batch();
            for (var j = i; j < end; j++) {
              batch.update(linkedProducts.docs[j].reference, {
                'CATEGORY_NAME': cleanName,
                'UPDATED_AT': FieldValue.serverTimestamp(),
              });
            }
            await batch.commit().timeout(const Duration(seconds: 6));
          }
        }
      } catch (e) {
        debugPrint('CategoryProvider.editCategory: product name sync notice: $e');
      }

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
