import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a spare parts category in the CATEGORIES Firestore collection.
class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to safely parse Firestore document snapshot
  factory CategoryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CategoryModel.fromMap(data, doc.id);
  }

  /// Factory constructor to safely parse Map representations
  factory CategoryModel.fromMap(Map<String, dynamic> data, String id) {
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

    return CategoryModel(
      id: id,
      name: (data['NAME'] ?? data['name'] ?? '').toString().trim(),
      imageUrl: (data['IMAGE_URL'] ?? data['imageUrl'] ?? data['image'] ?? '').toString().trim(),
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
      'IMAGE_URL': imageUrl,
      'DESCRIPTION': description ?? '',
      'IS_ACTIVE': isActive,
      'CREATED_AT': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'UPDATED_AT': FieldValue.serverTimestamp(),
    };
  }

  /// Helper copyWith for immutable state updates
  CategoryModel copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'CategoryModel(id: $id, name: $name, imageUrl: $imageUrl, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel &&
        other.id == id &&
        other.name == name &&
        other.imageUrl == imageUrl &&
        other.description == description &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(id, name, imageUrl, description, isActive);
}
