import 'package:cloud_firestore/cloud_firestore.dart';

/// Strongly-typed model representing an authenticated Administrator session.
/// Plaintext passwords are NEVER stored in this model for security.
class AdminModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String type;
  final bool isActive;

  const AdminModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.type,
    required this.isActive,
  });

  /// Check whether the administrator holds the MANAGER role
  bool get isManager => type.toUpperCase() == 'MANAGER';

  /// Factory constructor to safely parse Firestore document snapshots
  factory AdminModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminModel.fromMap(data, doc.id);
  }

  /// Factory constructor to safely parse Map representations
  factory AdminModel.fromMap(Map<String, dynamic> data, String id) {
    // Parse IS_ACTIVE safely whether boolean or string representation
    bool parseIsActive(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      if (value is num) return value == 1;
      return false;
    }

    return AdminModel(
      id: id,
      name: (data['NAME'] ?? data['name'] ?? 'Admin').toString().trim(),
      phoneNumber: (data['PHONE_NUMBER'] ?? data['phoneNumber'] ?? data['phone'] ?? '').toString().trim(),
      type: (data['TYPE'] ?? data['type'] ?? 'STAFF').toString().trim().toUpperCase(),
      isActive: parseIsActive(data['IS_ACTIVE'] ?? data['isActive']),
    );
  }

  /// Serializes the model into a Map (excluding passwords)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'NAME': name,
      'PHONE_NUMBER': phoneNumber,
      'TYPE': type,
      'IS_ACTIVE': isActive,
    };
  }

  /// Helper copyWith for state immutability
  AdminModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? type,
    bool? isActive,
  }) {
    return AdminModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'AdminModel(id: $id, name: $name, phone: $phoneNumber, type: $type, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminModel &&
        other.id == id &&
        other.name == name &&
        other.phoneNumber == phoneNumber &&
        other.type == type &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(id, name, phoneNumber, type, isActive);
}
