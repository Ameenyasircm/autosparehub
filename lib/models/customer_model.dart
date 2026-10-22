import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer profile model representing a registered buyer in AutoSpare Hub.
/// Ordering is gated until an administrator approves the account.
class CustomerModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String status; // 'PENDING' | 'APPROVED' | 'REJECTED'
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final String? rejectionReason;

  const CustomerModel({
    required this.id,
    required this.name,
    String? phoneNumber,
    String? phone,
    this.status = 'PENDING',
    this.requestedAt,
    this.approvedAt,
    this.rejectionReason,
  }) : phoneNumber = phoneNumber ?? phone ?? '';

  String get phone => phoneNumber;
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  factory CustomerModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CustomerModel.fromMap(data, doc.id);
  }

  factory CustomerModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return CustomerModel(
      id: id,
      name: (data['NAME'] ?? data['name'] ?? 'Customer').toString().trim(),
      phoneNumber: (data['PHONE_NUMBER'] ?? data['phoneNumber'] ?? data['phone'] ?? '').toString().trim(),
      status: (data['STATUS'] ?? data['status'] ?? 'PENDING').toString().trim().toUpperCase(),
      requestedAt: parseTimestamp(data['REQUESTED_AT'] ?? data['requestedAt'] ?? data['CREATED_AT']),
      approvedAt: parseTimestamp(data['APPROVED_AT'] ?? data['approvedAt']),
      rejectionReason: data['REJECTION_REASON']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'NAME': name,
      'PHONE_NUMBER': phoneNumber,
      'STATUS': status,
      'REQUESTED_AT': requestedAt != null ? Timestamp.fromDate(requestedAt!) : FieldValue.serverTimestamp(),
      'APPROVED_AT': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'REJECTION_REASON': rejectionReason,
      'UPDATED_AT': FieldValue.serverTimestamp(),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? status,
    DateTime? requestedAt,
    DateTime? approvedAt,
    String? rejectionReason,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  @override
  String toString() => 'CustomerModel(id: $id, name: $name, phone: $phoneNumber, status: $status)';
}
