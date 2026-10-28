import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_model.dart';

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

/// Service handling Admin authentication and Firestore queries on the ADMINS collection.
class AdminAuthService {
  final FirebaseFirestore? _customFirestore;

  AdminAuthService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String adminsCollection = 'ADMINS';

  /// Authenticate an administrator by phone number / username and password.
  /// Queries the `ADMINS` collection dynamically.
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
      debugPrint('AdminAuthService: Querying $adminsCollection for PHONE_NUMBER: $cleanPhone');
      
      final querySnapshot = await _firestore
          .collection(adminsCollection)
          .where('PHONE_NUMBER', isEqualTo: cleanPhone)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (querySnapshot.docs.isEmpty) {
        debugPrint('AdminAuthService: No matching record found for $cleanPhone');
        return const AdminAuthResult.failure('Invalid username or password.');
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      // Check IS_ACTIVE status
      final dynamic rawActive = data['IS_ACTIVE'] ?? data['isActive'];
      final bool isActive = rawActive is bool
          ? rawActive
          : (rawActive?.toString().toLowerCase() == 'true' || rawActive == 1);

      if (!isActive) {
        debugPrint('AdminAuthService: Admin account is inactive (${doc.id})');
        return const AdminAuthResult.failure(
          'This admin account has been deactivated. Please contact your system administrator.',
        );
      }

      // Password comparison (Development phase Firestore authentication)
      // Note: In production, migration to Firebase Auth or hashed tokens is recommended.
      final String storedPassword = (data['PASSWORD'] ?? data['password'] ?? '').toString();

      if (storedPassword != password) {
        debugPrint('AdminAuthService: Password mismatch for ${doc.id}');
        return const AdminAuthResult.failure('Invalid username or password.');
      }

      // Successful verification - construct AdminModel without password
      final admin = AdminModel.fromFirestore(doc);
      debugPrint('AdminAuthService: Admin authenticated successfully: ${admin.name} (${admin.type})');
      return AdminAuthResult.success(admin);

    } on TimeoutException {
      debugPrint('AdminAuthService: Authentication request timed out');
      return const AdminAuthResult.failure(
        'Connection timed out. Please check your internet connection.',
      );
    } on FirebaseException catch (e) {
      debugPrint('AdminAuthService FirebaseException [${e.code}]: ${e.message}');
      if (e.code == 'permission-denied') {
        return const AdminAuthResult.failure(
          'Firestore permission denied. Please verify Cloud Firestore security rules.',
        );
      } else if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        return const AdminAuthResult.failure(
          'Network connection unavailable. Please check your internet connection.',
        );
      }
      return AdminAuthResult.failure('Firebase error: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('AdminAuthService unexpected error: $e');
      return AdminAuthResult.failure('An unexpected error occurred during login. Please try again.');
    }
  }
}
