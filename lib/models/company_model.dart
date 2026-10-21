import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a vehicle manufacturer/brand/company.
class CompanyModel {
  final String id;
  final String name;
  final String logoUrl;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CompanyModel({
    required this.id,
    required this.name,
    required this.logoUrl,
    this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to safely parse Firestore document snapshot
  factory CompanyModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CompanyModel.fromMap(data, doc.id);
  }

  /// Factory constructor to safely parse Map representations
  factory CompanyModel.fromMap(Map<String, dynamic> data, String id) {
    bool parseIsActive(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      if (value is num) return value == 1;
      return true; // Default to true if not specified
    }

    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return CompanyModel(
      id: id,
      name: (data['NAME'] ?? data['name'] ?? '').toString().trim(),
      logoUrl: (data['LOGO_URL'] ?? data['logoUrl'] ?? data['logo'] ?? '').toString().trim(),
      description: data['DESCRIPTION']?.toString().trim() ?? data['description']?.toString().trim(),
      isActive: parseIsActive(data['IS_ACTIVE'] ?? data['isActive']),
      createdAt: parseTimestamp(data['CREATED_AT'] ?? data['createdAt']),
      updatedAt: parseTimestamp(data['UPDATED_AT'] ?? data['updatedAt']),
    );
  }

  /// Serializes the model into a Map for Firestore persistence
  Map<String, dynamic> toMap() {
    return {
      'NAME': name,
      'LOGO_URL': logoUrl,
      'DESCRIPTION': description ?? '',
      'IS_ACTIVE': isActive,
      'CREATED_AT': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'UPDATED_AT': FieldValue.serverTimestamp(),
    };
  }

  /// Helper copyWith for immutable state updates
  CompanyModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'CompanyModel(id: $id, name: $name, logoUrl: $logoUrl, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompanyModel &&
        other.id == id &&
        other.name == name &&
        other.logoUrl == logoUrl &&
        other.description == description &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(id, name, logoUrl, description, isActive);
}
