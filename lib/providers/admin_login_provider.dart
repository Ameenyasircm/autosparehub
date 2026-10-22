import 'package:flutter/foundation.dart';
import '../models/admin_model.dart';
import '../services/admin_auth_service.dart';
import '../services/session_service.dart';

/// Provider managing admin authentication state, session persistence, and error messages.
class AdminLoginProvider extends ChangeNotifier {
  final AdminAuthService _authService;
  final SessionService _sessionService;

  AdminLoginProvider({
    AdminAuthService? authService,
    SessionService? sessionService,
  })  : _authService = authService ?? AdminAuthService(),
        _sessionService = sessionService ?? SessionService();

  bool _isLoading = false;
  String? _errorMessage;
  AdminModel? _currentAdmin;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AdminModel? get currentAdmin => _currentAdmin;
  bool get isAuthenticated => _currentAdmin != null;

  /// Clear any active error message
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Check whether a persistent session exists in SharedPreferences and restore it
  Future<bool> checkSavedSession() async {
    try {
      final savedAdmin = await _sessionService.getAdminSession();
      if (savedAdmin != null && savedAdmin.isActive) {
        _currentAdmin = savedAdmin;
        _errorMessage = null;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('AdminLoginProvider.checkSavedSession error: $e');
    }
    return false;
  }

  /// Perform admin login with username/phone and password
  Future<bool> login({
    required String usernameOrPhone,
    required String password,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.authenticate(
        usernameOrPhone: usernameOrPhone,
        password: password,
      );

      if (result.isSuccess && result.admin != null) {
        _currentAdmin = result.admin;
        _errorMessage = null;
        _isLoading = false;
        // Persist session to local storage via SharedPreferences
        await _sessionService.saveAdminSession(result.admin!);
        notifyListeners();
        return true;
      } else {
        _currentAdmin = null;
        _errorMessage = result.errorMessage ?? 'Authentication failed.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _currentAdmin = null;
      _errorMessage = 'An unexpected error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout current admin and clear session state from local storage
  Future<void> logout() async {
    _currentAdmin = null;
    _errorMessage = null;
    _isLoading = false;
    await _sessionService.clearSession();
    notifyListeners();
  }
}
