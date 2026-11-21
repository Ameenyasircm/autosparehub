import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'app_check_setup.dart';
import '../utils/phone_helper.dart';

/// Thrown by [AuthService] with a message that is safe to show to the user.
class AuthServiceException implements Exception {
  final String code;
  final String message;
  const AuthServiceException(this.code, this.message);
  @override
  String toString() => message;
}

/// Wraps Firebase Authentication for both apps.
///
/// Accounts use Firebase email/password sign-in, with an internal e-mail
/// built from the phone number (users never see it):
///   customer: `c{10 digits}[_{n}]@autosparehub.app`
///   admin:    `a{admin doc id}[_{n}]@autosparehub.app`
/// The optional `_{n}` suffix is added when an admin resets a password: a new
/// sign-in account is created and the old one stops working, because the
/// Firestore rules only accept the account whose uid is stored on the record
/// (USERS.AUTH_UID / ROLES/{uid}).
///
/// `LOGIN_INDEX/{key}` maps a login key (phone) to the sign-in e-mail. It
/// holds no personal data besides the phone, and the rules allow reading a
/// single key but never listing them.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _customAuth = auth,
        _customFirestore = firestore;

  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String emailDomain = 'autosparehub.app';
  static const String loginIndexCollection = 'LOGIN_INDEX';
  static const String rolesCollection = 'ROLES';
  static const int minPasswordLength = 6;

  // ---------------------------------------------------------------- keys

  /// LOGIN_INDEX key for a customer phone (any format).
  static String customerLoginKey(String phone) =>
      'C${PhoneHelper.normalizeTo91(phone)}';

  /// LOGIN_INDEX key for an admin phone / username.
  static String adminLoginKey(String phone) =>
      'A${phone.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase()}';

  /// Default sign-in e-mail of a self-registered customer.
  static String customerEmail(String phone, {String suffix = ''}) =>
      'c${PhoneHelper.extract10Digits(phone)}$suffix@$emailDomain';

  /// Sign-in e-mail of an admin account.
  static String adminEmail(String adminDocId, {String suffix = ''}) =>
      'a${adminDocId.toLowerCase()}$suffix@$emailDomain';

  /// Suffix used for a replacement account after a password reset.
  static String resetSuffix() => '_${DateTime.now().millisecondsSinceEpoch}';

  // ---------------------------------------------------------------- session

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null; // Firebase not initialised (tests)
    }
  }

  String? get currentUid => currentUser?.uid;

  /// Waits for Firebase Auth to restore a saved sign-in at app start.
  /// Returns null when nobody is signed in (or Firebase is unavailable).
  Future<User?> waitForUser() async {
    try {
      return await _auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => _auth.currentUser);
    } catch (_) {
      return null;
    }
  }

  /// Whether a Firebase sign-in exists (restored or fresh).
  Future<bool> hasSignedInUser() async => await waitForUser() != null;

  /// Deletes the signed-in account if it is [uid] (undoes a registration
  /// whose profile could not be created), then signs out.
  Future<void> deleteCurrentUserIfOwns(String uid) async {
    try {
      final user = currentUser;
      if (user != null && user.uid == uid) await user.delete();
    } catch (e) {
      debugPrint('AuthService.deleteCurrentUserIfOwns: $e');
    }
    await signOut();
  }

  /// Customer self-registration: records phone -> own sign-in e-mail.
  /// Failures are only logged (login falls back to the default e-mail).
  Future<void> writeOwnCustomerLoginIndex(String phone, String email) async {
    try {
      await _firestore
          .collection(loginIndexCollection)
          .doc(customerLoginKey(phone))
          .set({'EMAIL': email, 'UPDATED_AT': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('AuthService.writeOwnCustomerLoginIndex: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> loginIndexRef(String loginKey) =>
      _firestore.collection(loginIndexCollection).doc(loginKey);

  static Map<String, dynamic> loginIndexData(String email) =>
      {'EMAIL': email, 'UPDATED_AT': FieldValue.serverTimestamp()};

  /// Looks up the sign-in e-mail stored for [loginKey], or null.
  Future<String?> lookupEmail(String loginKey) async {
    final doc = await _firestore
        .collection(loginIndexCollection)
        .doc(loginKey)
        .get()
        .timeout(const Duration(seconds: 10));
    final email = doc.data()?['EMAIL']?.toString().trim();
    return (email == null || email.isEmpty) ? null : email;
  }

  /// Signs in and returns the uid. Throws [AuthServiceException].
  Future<String> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      final uid = cred.user?.uid;
      if (uid == null) {
        throw const AuthServiceException('unknown', 'Sign-in failed. Please try again.');
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  /// Creates an account and signs in with it (customer self-registration).
  /// Returns the uid. Throws [AuthServiceException] (code `email-already-in-use`
  /// when an account exists).
  Future<String> register({required String email, required String password}) async {
    try {
      final cred = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut: $e');
    }
  }

  /// Changes the signed-in user's password after confirming the current one.
  Future<void> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthServiceException('no-user', 'You must be signed in to change your password.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthServiceException('wrong-password', 'Current password is incorrect.');
      }
      throw _map(e);
    }
  }

  // ---------------------------------------------------------------- admin tools

  static const String _secondaryAppName = 'account-provisioning';

  /// Creates a sign-in account for someone else (admin creating a customer or
  /// another admin, or resetting a password) WITHOUT signing the current
  /// admin out. Uses a separate Firebase app instance for the new account.
  /// Returns the new uid.
  Future<String> createAccountForOther({
    required String email,
    required String password,
  }) async {
    final app = Firebase.apps.any((a) => a.name == _secondaryAppName)
        ? Firebase.app(_secondaryAppName)
        : await _initSecondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: app);
    try {
      final cred = await secondaryAuth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    } finally {
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
    }
  }

  static Future<FirebaseApp> _initSecondaryApp() async {
    final app = await Firebase.initializeApp(
      name: _secondaryAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await activateAppCheck(app); // needed once App Check is enforced for Auth
    return app;
  }

  /// Creates an account for someone else, adding a reset suffix to the e-mail
  /// if the plain one is already taken. Returns (uid, email).
  Future<({String uid, String email})> createAccountWithFallback({
    required String Function(String suffix) emailFor,
    required String password,
  }) async {
    try {
      final email = emailFor('');
      return (uid: await createAccountForOther(email: email, password: password), email: email);
    } on AuthServiceException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      final email = emailFor(resetSuffix());
      return (uid: await createAccountForOther(email: email, password: password), email: email);
    }
  }

  // ---------------------------------------------------------------- errors

  static AuthServiceException _map(FirebaseAuthException e) {
    debugPrint('AuthService FirebaseAuthException [${e.code}]');
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return AuthServiceException(e.code, 'Incorrect phone number or password.');
      case 'user-disabled':
        return AuthServiceException(e.code, 'This account has been disabled. Please contact the store.');
      case 'too-many-requests':
        return AuthServiceException(e.code, 'Too many attempts. Please wait a few minutes and try again.');
      case 'email-already-in-use':
        return AuthServiceException(e.code, 'An account already exists for this number.');
      case 'weak-password':
        return AuthServiceException(e.code, 'Password must be at least $minPasswordLength characters.');
      case 'network-request-failed':
        return AuthServiceException(e.code, 'No internet connection. Please try again.');
      case 'operation-not-allowed':
        return AuthServiceException(
            e.code, 'Login is not enabled on the server (enable Email/Password in Firebase Authentication).');
      default:
        return AuthServiceException(e.code, 'Sign-in failed (${e.code}). Please try again.');
    }
  }
}
