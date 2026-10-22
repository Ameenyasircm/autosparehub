/// Utility that generates searchable lowercase keyword tokens for products
/// to enable fast, flexible keyword search across product name, OEM ref, brand, and vehicle application.
class KeywordGenerator {
  /// Generate a unique list of searchable lowercase keywords
  static List<String> generateKeywords({
    required String name,
    String? companyName,
    String? categoryName,
    String? application,
    String? refNo,
  }) {
    final Set<String> keywords = {};

    void addTokens(String? text) {
      if (text == null || text.trim().isEmpty) return;
      final clean = text.toLowerCase().trim();

      // Add full trimmed text
      if (clean.length >= 2) keywords.add(clean);

      // Add alphanumeric stripped version (e.g. 443100k040 for 44310-0K040)
      final alphanumeric = clean.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (alphanumeric.length >= 2 && alphanumeric != clean) {
        keywords.add(alphanumeric);
        final maxLen = alphanumeric.length > 15 ? 15 : alphanumeric.length;
        for (int i = 2; i <= maxLen; i++) {
          keywords.add(alphanumeric.substring(0, i));
        }
      }

      // Split by spaces, hyphens, slashes, and punctuation
      final words = clean.split(RegExp(r'[\s\-\/\,\.]+')).where((w) => w.length >= 2);
      for (final word in words) {
        keywords.add(word);

        // Generate prefixes for autocomplete (e.g. 'pum', 'pump')
        final maxLen = word.length > 15 ? 15 : word.length;
        for (int i = 2; i <= maxLen; i++) {
          keywords.add(word.substring(0, i));
        }
      }
    }

    addTokens(name);
    addTokens(refNo);
    addTokens(companyName);
    addTokens(categoryName);
    addTokens(application);

    // Limit to 100 keywords to optimize document size
    return keywords.take(100).toList();
  }
}
