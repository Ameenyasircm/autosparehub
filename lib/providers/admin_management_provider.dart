import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_model.dart';
import '../services/auth_service.dart';

/// Provider managing administration accounts, roles, access status, and queries.
class AdminManagementProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;
  final AuthService _authService;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  AdminManagementProvider({FirebaseFirestore? firestore, AuthService? authService})
      : _customFirestore = firestore,
        _authService = authService ?? AuthService(firestore: firestore);

  DocumentReference<Map<String, dynamic>> _roleRef(String uid) =>
      _firestore.collection(AuthService.rolesCollection).doc(uid);

  static const String collectionName = 'ADMINS';

  List<AdminModel> _admins = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _roleFilter = 'ALL';

  // Getters
  List<AdminModel> get admins => _admins;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get roleFilter => _roleFilter;

  @visibleForTesting
  void setAdminsForTesting(List<AdminModel> list) {
    _admins = List.from(list);
    _isLoading = false;
    notifyListeners();
  }

  /// Filtered admins based on search query and role filter
  List<AdminModel> get filteredAdmins {
    return _admins.where((admin) {
      final matchesSearch = _searchQuery.isEmpty ||
          admin.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          admin.phoneNumber.contains(_searchQuery);

      final matchesRole = _roleFilter == 'ALL' ||
          admin.type.toUpperCase() == _roleFilter.toUpperCase();

      return matchesSearch && matchesRole;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setRoleFilter(String role) {
    _roleFilter = role;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Fetches all admin accounts from Firestore
  Future<void> fetchAdmins() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .get()
          .timeout(const Duration(seconds: 10));

      _admins = snapshot.docs.map((doc) => AdminModel.fromFirestore(doc)).toList();
      
      // Sort: Managers first, then alphabetically by name
      _admins.sort((a, b) {
        if (a.isManager && !b.isManager) return -1;
        if (!a.isManager && b.isManager) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      _isLoading = false;
      notifyListeners();
    } on TimeoutException {
      debugPrint('AdminManagementProvider.fetchAdmins Timeout');
      _errorMessage = 'Connection timed out while loading administrators. Please check your internet connection.';
      _isLoading = false;
      notifyListeners();
    } on FirebaseException catch (e) {
      debugPrint('AdminManagementProvider.fetchAdmins FirebaseException [${e.code}]: ${e.message}');
      _errorMessage = 'Database error (${e.code}): ${e.message ?? 'Please check permissions.'}';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AdminManagementProvider.fetchAdmins Error: $e');
      _errorMessage = 'Failed to load administrator accounts. Please try again.';
      _isLoading = false;
      notifyListeners();
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Adds a new administrator with duplicate phone number verification
  Future<bool> addAdmin({
    required String name,
    required String phoneNumber,
    required String type,
    required String password,
    bool isActive = true,
  }) async {
    final cleanPhone = phoneNumber.trim();
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      _errorMessage = 'Admin name cannot be empty.';
      notifyListeners();
      return false;
    }
    if (cleanPhone.isEmpty) {
      _errorMessage = 'Phone number cannot be empty.';
      notifyListeners();
      return false;
    }
    if (password.trim().length < AuthService.minPasswordLength) {
      _errorMessage = 'Password must be at least ${AuthService.minPasswordLength} characters.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check for duplicate phone number
      final existing = await _firestore
          .collection(collectionName)
          .where('PHONE_NUMBER', isEqualTo: cleanPhone)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (existing.docs.isNotEmpty) {
        _errorMessage = 'An administrator with phone number $cleanPhone already exists.';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      // 2. Generate unique document ID: "AD" + timestamp in milliseconds
      final adminDocId = 'AD${DateTime.now().millisecondsSinceEpoch}';
      final docRef = _firestore.collection(collectionName).doc(adminDocId);

      final role = type.trim().toUpperCase();

      // Sign-in account (the current admin stays signed in). The password
      // is held by Firebase Auth only, never written to Firestore.
      final account = await _authService.createAccountWithFallback(
        emailFor: (suffix) => AuthService.adminEmail(adminDocId, suffix: suffix),
        password: password.trim(),
      );

      final batch = _firestore.batch();
      batch.set(docRef, {
        'ID': adminDocId,
        'NAME': cleanName,
        'PHONE_NUMBER': cleanPhone,
        'TYPE': role,
        'IS_ACTIVE': isActive,
        'AUTH_UID': account.uid,
        'AUTH_EMAIL': account.email,
        'CREATED_AT': FieldValue.serverTimestamp(),
      });
      batch.set(_roleRef(account.uid), {
        'ADMIN_ID': adminDocId,
        'ROLE': role,
        'IS_ACTIVE': isActive,
        'UPDATED_AT': FieldValue.serverTimestamp(),
      });
      batch.set(
        _authService.loginIndexRef(AuthService.adminLoginKey(cleanPhone)),
        AuthService.loginIndexData(account.email),
      );
      await batch.commit().timeout(const Duration(seconds: 10));

      // Refresh list safely
      try {
        await fetchAdmins().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('AdminManagementProvider.addAdmin: list refresh notice: $e');
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      debugPrint('AdminManagementProvider.addAdmin Timeout');
      _errorMessage = 'Operation timed out. Please check your internet connection and Firestore rules.';
      _isSaving = false;
      notifyListeners();
      return false;
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      _isSaving = false;
      notifyListeners();
      return false;
    } on FirebaseException catch (e) {
      debugPrint('AdminManagementProvider.addAdmin FirebaseException [${e.code}]: ${e.message}');
      if (e.code == 'permission-denied') {
        _errorMessage = 'Firestore permission denied. Please verify your Cloud Firestore security rules.';
      } else if (e.code == 'cancelled' || e.code == 'unavailable') {
        _errorMessage = 'Firestore connection interrupted (${e.code}). Please check network and retry.';
      } else {
        _errorMessage = 'Firebase error (${e.code}): ${e.message ?? 'Unknown error'}';
      }
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AdminManagementProvider.addAdmin Error: $e');
      _errorMessage = 'Failed to create administrator account: $e';
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

  /// Edits an existing administrator's details without overwriting authentication credentials
  Future<bool> editAdmin({
    required String id,
    required String name,
    required String phoneNumber,
    required String type,
    required bool currentIsActive,
    required String originalPhoneNumber,
    String? newPassword,
  }) async {
    final cleanPassword = newPassword?.trim() ?? '';
    if (cleanPassword.isNotEmpty && cleanPassword.length < AuthService.minPasswordLength) {
      _errorMessage = 'Password must be at least ${AuthService.minPasswordLength} characters.';
      notifyListeners();
      return false;
    }
    final cleanPhone = phoneNumber.trim();
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      _errorMessage = 'Admin name cannot be empty.';
      notifyListeners();
      return false;
    }
    if (cleanPhone.isEmpty) {
      _errorMessage = 'Phone number cannot be empty.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // If phone number changed, verify no other admin has this new number
      if (cleanPhone != originalPhoneNumber.trim()) {
        final existing = await _firestore
            .collection(collectionName)
            .where('PHONE_NUMBER', isEqualTo: cleanPhone)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));

        if (existing.docs.isNotEmpty && existing.docs.first.id != id) {
          _errorMessage = 'Another administrator is already registered with phone $cleanPhone.';
          _isSaving = false;
          notifyListeners();
          return false;
        }
      }

      final docRef = _firestore.collection(collectionName).doc(id);
      final current = AdminModel.fromFirestore(
          await docRef.get().timeout(const Duration(seconds: 10)));
      final role = type.trim().toUpperCase();

      String? uid = current.authUid;
      String? email = current.authEmail;
      final oldUid = uid;

      // Password reset: Firebase Auth cannot change another user's password
      // from the app, so a new sign-in account replaces the old one. The old
      // one stops working because its ROLES record is removed.
      if (cleanPassword.isNotEmpty) {
        email = AuthService.adminEmail(id, suffix: AuthService.resetSuffix());
        uid = await _authService.createAccountForOther(email: email, password: cleanPassword);
      }

      final batch = _firestore.batch();
      batch.update(docRef, {
        'NAME': cleanName,
        'PHONE_NUMBER': cleanPhone,
        'TYPE': role,
        if (uid != null) 'AUTH_UID': uid,
        if (email != null) 'AUTH_EMAIL': email,
        'PASSWORD': FieldValue.delete(), // remove any legacy plain-text value
      });
      if (uid != null) {
        if (oldUid != null && oldUid != uid) batch.delete(_roleRef(oldUid));
        batch.set(_roleRef(uid), {
          'ADMIN_ID': id,
          'ROLE': role,
          'IS_ACTIVE': current.isActive,
          'UPDATED_AT': FieldValue.serverTimestamp(),
        });
      }
      if (email != null) {
        if (cleanPhone != originalPhoneNumber.trim()) {
          batch.delete(_authService.loginIndexRef(AuthService.adminLoginKey(originalPhoneNumber)));
        }
        batch.set(
          _authService.loginIndexRef(AuthService.adminLoginKey(cleanPhone)),
          AuthService.loginIndexData(email),
        );
      }
      await batch.commit().timeout(const Duration(seconds: 10));

      try {
        await fetchAdmins().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('AdminManagementProvider.editAdmin: list refresh notice: $e');
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      debugPrint('AdminManagementProvider.editAdmin Timeout');
      _errorMessage = 'Operation timed out. Please check your internet connection.';
      _isSaving = false;
      notifyListeners();
      return false;
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      _isSaving = false;
      notifyListeners();
      return false;
    } on FirebaseException catch (e) {
      debugPrint('AdminManagementProvider.editAdmin FirebaseException [${e.code}]: ${e.message}');
      _errorMessage = 'Failed to update administrator: ${e.message ?? e.code}';
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AdminManagementProvider.editAdmin Error: $e');
      _errorMessage = 'Failed to update administrator: $e';
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

  /// Toggles an admin's IS_ACTIVE status (Activate / Deactivate)
  Future<bool> toggleAdminActive(String id, bool newStatus) async {
    try {
      final docRef = _firestore.collection(collectionName).doc(id);
      final current = AdminModel.fromFirestore(
          await docRef.get().timeout(const Duration(seconds: 10)));
      final batch = _firestore.batch();
      batch.update(docRef, {'IS_ACTIVE': newStatus});
      if (current.authUid != null) {
        // The rules read ROLES, so deactivation takes effect immediately.
        batch.set(_roleRef(current.authUid!), {
          'IS_ACTIVE': newStatus,
          'UPDATED_AT': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 10));

      final index = _admins.indexWhere((a) => a.id == id);
      if (index != -1) {
        _admins[index] = _admins[index].copyWith(isActive: newStatus);
        notifyListeners();
      }
      return true;
    } on TimeoutException {
      debugPrint('AdminManagementProvider.toggleAdminActive Timeout');
      _errorMessage = 'Request timed out updating status.';
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AdminManagementProvider.toggleAdminActive Error: $e');
      _errorMessage = 'Failed to update active status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Permanently removes an administrator record
  Future<bool> deleteAdmin(String id, String currentLoggedInAdminId) async {
    if (id == currentLoggedInAdminId) {
      _errorMessage = 'Security policy prevents deleting your currently active administrator session.';
      notifyListeners();
      return false;
    }

    try {
      final docRef = _firestore.collection(collectionName).doc(id);
      final current = AdminModel.fromFirestore(
          await docRef.get().timeout(const Duration(seconds: 10)));
      final batch = _firestore.batch();
      batch.delete(docRef);
      // Removing the role revokes all access; the leftover sign-in account
      // can no longer read or change anything.
      if (current.authUid != null) batch.delete(_roleRef(current.authUid!));
      if (current.phoneNumber.isNotEmpty) {
        batch.delete(_authService.loginIndexRef(AuthService.adminLoginKey(current.phoneNumber)));
      }
      await batch.commit().timeout(const Duration(seconds: 10));
      _admins.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } on TimeoutException {
      debugPrint('AdminManagementProvider.deleteAdmin Timeout');
      _errorMessage = 'Request timed out deleting administrator.';
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AdminManagementProvider.deleteAdmin Error: $e');
      _errorMessage = 'Failed to delete administrator: $e';
      notifyListeners();
      return false;
    }
  }
}
