import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/company_model.dart';
import '../services/cloudinary_service.dart';

/// Provider managing vehicle manufacturers and brands (Companies)
class CompanyProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinaryService;

  CompanyProvider({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinaryService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinaryService = cloudinaryService ?? CloudinaryService();

  static const String collectionName = 'COMPANIES';

  List<CompanyModel> _companies = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String _searchQuery = '';

  // Getters
  List<CompanyModel> get companies => _companies;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  List<CompanyModel> get filteredCompanies {
    if (_searchQuery.isEmpty) return _companies;
    return _companies.where((c) {
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

  /// Fetches companies from Firestore sorted by name
  Future<void> fetchCompanies() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .get()
          .timeout(const Duration(seconds: 10));

      _companies = snapshot.docs.map((doc) => CompanyModel.fromFirestore(doc)).toList();

      // Sort alphabetically by name
      _companies.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _isLoading = false;
      notifyListeners();
    } on TimeoutException {
      debugPrint('CompanyProvider.fetchCompanies: Timeout');
      _errorMessage = 'Connection timed out while loading companies.';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('CompanyProvider.fetchCompanies Error: $e');
      _errorMessage = 'Failed to load vehicle companies. Please try again.';
      _isLoading = false;
      notifyListeners();
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Adds a new company with Cloudinary logo upload
  Future<bool> addCompany({
    required String name,
    required File logoFile,
    String? description,
    bool isActive = true,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _errorMessage = 'Company name is required.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check for duplicate company name (case-insensitive)
      final isDuplicate = _companies.any(
        (c) => c.name.toLowerCase() == cleanName.toLowerCase(),
      );
      if (isDuplicate) {
        _errorMessage = 'A company with the name "$cleanName" already exists.';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      // 2. Upload logo to Cloudinary under autospare/companies
      final uploadedUrl = await _cloudinaryService.uploadImage(
        imageFile: logoFile,
        folder: CloudinaryService.companiesFolder,
      );

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        _errorMessage = 'Failed to upload company logo to Cloudinary. Please check your network and retry.';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      // 3. Save to Firestore with custom doc ID: "CO" + timestamp in milliseconds
      final companyDocId = 'CO${DateTime.now().millisecondsSinceEpoch}';
      final docRef = _firestore.collection(collectionName).doc(companyDocId);
      final data = {
        'ID': companyDocId,
        'NAME': cleanName,
        'LOGO_URL': uploadedUrl,
        'DESCRIPTION': description?.trim() ?? '',
        'IS_ACTIVE': isActive,
        'CREATED_AT': FieldValue.serverTimestamp(),
        'UPDATED_AT': FieldValue.serverTimestamp(),
      };

      await docRef.set(data).timeout(const Duration(seconds: 10));

      try {
        await fetchCompanies().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('CompanyProvider.addCompany: refresh notice: $e');
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      debugPrint('CompanyProvider.addCompany: Timeout');
      _errorMessage = 'Connection timed out while saving company. Please check your network.';
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('CompanyProvider.addCompany Error: $e');
      _errorMessage = 'Failed to save company: $e';
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

  /// Edits an existing company, updating Cloudinary logo if a new file is chosen
  Future<bool> editCompany({
    required String id,
    required String name,
    File? newLogoFile,
    required String currentLogoUrl,
    String? description,
    required bool isActive,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _errorMessage = 'Company name is required.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check duplicate name excluding self
      final isDuplicate = _companies.any(
        (c) => c.id != id && c.name.toLowerCase() == cleanName.toLowerCase(),
      );
      if (isDuplicate) {
        _errorMessage = 'Another company with the name "$cleanName" already exists.';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      String finalLogoUrl = currentLogoUrl;

      // If a new image was picked, upload to Cloudinary first
      if (newLogoFile != null) {
        final uploadedUrl = await _cloudinaryService.uploadImage(
          imageFile: newLogoFile,
          folder: CloudinaryService.companiesFolder,
        );

        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          _errorMessage = 'Failed to upload new logo image. Update aborted.';
          _isSaving = false;
          notifyListeners();
          return false;
        }
        finalLogoUrl = uploadedUrl;
      }

      // Update Firestore
      await _firestore.collection(collectionName).doc(id).update({
        'NAME': cleanName,
        'LOGO_URL': finalLogoUrl,
        'DESCRIPTION': description?.trim() ?? '',
        'IS_ACTIVE': isActive,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      try {
        await fetchCompanies().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('CompanyProvider.editCompany: refresh notice: $e');
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      debugPrint('CompanyProvider.editCompany: Timeout');
      _errorMessage = 'Connection timed out while updating company.';
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('CompanyProvider.editCompany Error: $e');
      _errorMessage = 'Failed to update company: $e';
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
  Future<bool> toggleCompanyActive(String id, bool newStatus) async {
    try {
      await _firestore.collection(collectionName).doc(id).update({
        'IS_ACTIVE': newStatus,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      final index = _companies.indexWhere((c) => c.id == id);
      if (index != -1) {
        _companies[index] = _companies[index].copyWith(isActive: newStatus);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('CompanyProvider.toggleCompanyActive Error: $e');
      _errorMessage = 'Failed to update active status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Deletes a company record
  Future<bool> deleteCompany(String id) async {
    try {
      await _firestore.collection(collectionName).doc(id).delete().timeout(const Duration(seconds: 10));
      _companies.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CompanyProvider.deleteCompany Error: $e');
      _errorMessage = 'Failed to delete company: $e';
      notifyListeners();
      return false;
    }
  }
}
