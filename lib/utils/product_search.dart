import '../models/product_model.dart';

/// Shared product search used by the customer catalog and the product provider.
///
/// Matching is case-insensitive, and part numbers also match when the user
/// leaves out spaces, hyphens, dots or slashes (e.g. "443100k040" finds
/// "44310-0K040").
class ProductSearch {
  ProductSearch._();

  static final RegExp _separators = RegExp(r'[\s\-./_]+');

  /// Lowercases and strips separator characters.
  static String normalize(String value) =>
      value.toLowerCase().replaceAll(_separators, '');

  /// Whether [product] matches [query]. An empty query matches everything.
  static bool matches(ProductModel product, String query) =>
      score(product, query) > 0;

  /// Relevance of [product] for [query]; 0 means no match.
  /// Part number and name matches rank above brand/category/description.
  static int score(ProductModel product, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return 1;
    final nq = normalize(q);

    final partNo = (product.partNumber ?? '').toLowerCase();
    final nPartNo = normalize(partNo);
    final ref = (product.refNo ?? '').toLowerCase();
    final nRef = normalize(ref);
    final name = product.name.toLowerCase();

    if (nq.isNotEmpty && (nPartNo == nq || nRef == nq)) return 100;
    if (nq.isNotEmpty &&
        ((nPartNo.isNotEmpty && nPartNo.startsWith(nq)) ||
            (nRef.isNotEmpty && nRef.startsWith(nq)))) {
      return 90;
    }
    if (name == q) return 85;
    if (name.startsWith(q)) return 80;
    if (nq.isNotEmpty && (nPartNo.contains(nq) || nRef.contains(nq))) return 70;
    if (name.contains(q) || normalize(name).contains(nq)) return 60;
    if (product.companyName.toLowerCase().contains(q)) return 40;
    if (product.categoryName.toLowerCase().contains(q)) return 35;
    if (product.searchKeywords.any((k) => k.toLowerCase().contains(q))) return 30;
    if (product.description?.toLowerCase().contains(q) ?? false) return 20;
    return 0;
  }

  /// Filters [products] to matches for [query], best matches first.
  /// The original order is kept between products with equal relevance.
  static List<ProductModel> search(Iterable<ProductModel> products, String query) {
    final scored = <MapEntry<ProductModel, int>>[];
    for (final p in products) {
      final s = score(p, query);
      if (s > 0) scored.add(MapEntry(p, s));
    }
    final indexed = scored.asMap().entries.toList()
      ..sort((a, b) {
        final byScore = b.value.value.compareTo(a.value.value);
        return byScore != 0 ? byScore : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value.key).toList();
  }
}
