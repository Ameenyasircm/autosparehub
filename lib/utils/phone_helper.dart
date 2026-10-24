/// Utility for validating and formatting Indian mobile phone numbers (10 digits).
class PhoneHelper {
  /// Check if the input is a valid 10-digit Indian mobile number.
  /// Must be exactly 10 numeric digits starting with 6, 7, 8, or 9.
  static bool isValidIndianNumber(String? raw) {
    if (raw == null) return false;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits);
  }

  /// Extracts the clean 10-digit mobile number from input.
  static String extract10Digits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return digits;
    if (digits.startsWith('91') && digits.length == 12) return digits.substring(2);
    if (digits.startsWith('0') && digits.length == 11) return digits.substring(1);
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  /// Normalizes to standard 12-digit Indian format (e.g. '919876543210').
  static String normalizeTo91(String raw) {
    final ten = extract10Digits(raw);
    return '91$ten';
  }

  /// Firestore document ID format for customer profiles (e.g. 'USR_919876543210').
  /// Ensures database-level uniqueness for each mobile number.
  static String toDocId(String raw) {
    return 'USR_${normalizeTo91(raw)}';
  }

  /// Formats a 10-digit number for display: '+91 98765 43210'.
  static String formatForDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final ten = extract10Digits(raw);
    if (ten.length == 10) {
      return '+91 ${ten.substring(0, 5)} ${ten.substring(5)}';
    }
    return raw;
  }
}
