import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// Result object for admin authentication operations
class AdminAuthResult {
  final bool isSuccess;
  final AdminModel? admin;
  final String? errorMessage;

  const AdminAuthResult.success(this.admin)
      : isSuccess = true,
        errorMessage = null;

  const AdminAuthResult.failure(this.errorMessage)
      : isSuccess = false,
        admin = null;
}

/// Service handling Admin sign-in (Firebase Authentication) and the
/// ADMINS / ROLES records.
///
/// Passwords are verified by Firebase Auth only; they are never read from or
/// stored in Firestore. The admin's role comes from `ROLES/{uid}`, which the
/// Firestore rules also use to decide what an admin may do.
class AdminAuthService {
  final FirebaseFirestore? _customFirestore;
  final AuthService _authService;

  AdminAuthService({FirebaseFirestore? firestore, AuthService? authService})
      : _customFirestore = firestore,
        _authService = authService ?? AuthService(firestore: firestore);

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String adminsCollection = 'ADMINS';

  /// Authenticate an administrator by phone number / username and password.
  Future<AdminAuthResult> authenticate({
    required String usernameOrPhone,
    required String password,
  }) async {
    final cleanPhone = usernameOrPhone.trim();

    if (cleanPhone.isEmpty) {
      return const AdminAuthResult.failure('Username cannot be empty.');
    }

    if (password.isEmpty) {
      return const AdminAuthResult.failure('Password cannot be empty.');
    }

    try {
      final email = await _authService.lookupEmail(AuthService.adminLoginKey(cleanPhone));
      if (email == null) {
        return const AdminAuthResult.failure('Invalid username or password.');
      }

      try {
        await _authService.signIn(email: email, password: password);
      } on AuthServiceException catch (e) {
        final isCredentialError = e.code == 'invalid-credential' ||
            e.code == 'wrong-password' ||
            e.code == 'user-not-found';
        return AdminAuthResult.failure(
            isCredentialError ? 'Invalid username or password.' : e.message);
      }

      final admin = await loadSignedInAdmin(fromServer: true);
      if (admin == null) {
        await _authService.signOut();
        return const AdminAuthResult.failure('Invalid username or password.');
      }
      if (!admin.isActive) {
        await _authService.signOut();
        return const AdminAuthResult.failure(
          'This admin account has been deactivated. Please contact your system administrator.',
        );
      }
      debugPrint('AdminAuthService: Admin authenticated (${admin.type})');
      return AdminAuthResult.success(admin);
    } on TimeoutException {
      await _authService.signOut();
      return const AdminAuthResult.failure(
        'Connection timed out. Please check your internet connection.',
      );
    } on FirebaseException catch (e) {
      debugPrint('AdminAuthService FirebaseException [${e.code}]');
      await _authService.signOut();
      if (e.code == 'permission-denied') {
        return const AdminAuthResult.failure('Invalid username or password.');
      } else if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        return const AdminAuthResult.failure(
          'Network connection unavailable. Please check your internet connection.',
        );
      }
      return const AdminAuthResult.failure('Login failed. Please try again.');
    } catch (e) {
      debugPrint('AdminAuthService unexpected error: $e');
      await _authService.signOut();
      return const AdminAuthResult.failure('An unexpected error occurred during login. Please try again.');
    }
  }

  /// Loads the admin record of the signed-in Firebase user via ROLES/{uid}.
  /// Returns null when nobody is signed in or the user is not an admin.
  /// The admin is inactive if either the role or the admin record says so.
  Future<AdminModel?> loadSignedInAdmin({bool fromServer = false}) async {
    final uid = _authService.currentUid;
    if (uid == null) return null;
    final options = GetOptions(source: fromServer ? Source.server : Source.serverAndCache);

    final role = await _firestore
        .collection(AuthService.rolesCollection)
        .doc(uid)
        .get(options)
        .timeout(const Duration(seconds: 10));
    final adminId = role.data()?['ADMIN_ID']?.toString();
    if (!role.exists || adminId == null || adminId.isEmpty) return null;

    final doc = await _firestore
        .collection(adminsCollection)
        .doc(adminId)
        .get(options)
        .timeout(const Duration(seconds: 10));
    if (!doc.exists) return null;

    final admin = AdminModel.fromFirestore(doc);
    final roleActive = role.data()?['IS_ACTIVE'] == true;
    return roleActive ? admin : admin.copyWith(isActive: false);
  }

  Future<void> signOut() => _authService.signOut();

  /// Waits for a saved Firebase sign-in to be restored at app start.
  Future<bool> hasSignedInUser() async => await _authService.waitForUser() != null;

  /// Synchronize FCM Device Token to Firestore for Admin Push Notifications
  Future<void> syncAdminFcmToken(String adminDocId) async {
    try {
      final token = await NotificationService.instance.getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection(adminsCollection).doc(adminDocId).update({
          'FCM_TOKEN': token,
          'FCM_UPDATED_AT': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
        debugPrint('Admin FCM Token synced to Firestore for $adminDocId');
      }
    } catch (e) {
      debugPrint('AdminAuthService.syncAdminFcmToken error: $e');
    }
  }
}
