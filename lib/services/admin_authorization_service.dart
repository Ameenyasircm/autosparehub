import '../models/admin_model.dart';

/// Service enforcing role-based permissions and access control.
class AdminAuthorizationService {
  /// Allowed administrative roles
  static const String roleManager = 'MANAGER';
  static const String roleStaff = 'STAFF';

  /// Verifies if an admin holds the MANAGER privilege to manage other admins
  static bool canManageAdmins(AdminModel? admin) {
    if (admin == null || !admin.isActive) return false;
    return admin.type.toUpperCase() == roleManager;
  }

  /// Verifies if an admin can manage vehicle brands / companies
  static bool canManageCompanies(AdminModel? admin) {
    if (admin == null || !admin.isActive) return false;
    return true; // Both MANAGER and active administrative staff can manage catalog
  }

  /// Verifies if an admin can manage spare parts categories
  static bool canManageCategories(AdminModel? admin) {
    if (admin == null || !admin.isActive) return false;
    return true;
  }
}
