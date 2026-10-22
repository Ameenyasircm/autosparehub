import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Provider fetching real-time aggregate counts for the Admin Dashboard.
class AdminDashboardProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  AdminDashboardProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  int _adminCount = 0;
  int _companyCount = 0;
  int _categoryCount = 0;
  int _productCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  int get adminCount => _adminCount;
  int get companyCount => _companyCount;
  int get categoryCount => _categoryCount;
  int get productCount => _productCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Resilient count helper that uses server aggregation with timeout and falls back to query
  Future<int> _fetchCountSafely(String collectionName) async {
    try {
      final agg = await _firestore
          .collection(collectionName)
          .count()
          .get()
          .timeout(const Duration(seconds: 6));
      return agg.count ?? 0;
    } catch (e) {
      debugPrint('Aggregate count for $collectionName failed ($e), attempting fallback query');
      try {
        final snap = await _firestore
            .collection(collectionName)
            .limit(200)
            .get()
            .timeout(const Duration(seconds: 6));
        return snap.docs.length;
      } catch (inner) {
        debugPrint('Fallback query for $collectionName failed: $inner');
        return 0;
      }
    }
  }

  /// Fetches actual counts from Firestore collections using resilient count queries
  Future<void> fetchDashboardCounts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final counts = await Future.wait([
        _fetchCountSafely('ADMINS'),
        _fetchCountSafely('COMPANIES'),
        _fetchCountSafely('CATEGORIES'),
        _fetchCountSafely('PRODUCTS'),
      ]);

      _adminCount = counts[0];
      _companyCount = counts[1];
      _categoryCount = counts[2];
      _productCount = counts[3];

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AdminDashboardProvider.fetchDashboardCounts Error: $e');
      _errorMessage = 'Could not load summary counts.';
      _isLoading = false;
      notifyListeners();
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
