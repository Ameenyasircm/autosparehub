import '../models/sales_models.dart';

/// Pure helpers for sales, purchases and the day-wise sales view.
/// Kept free of Firebase so they can be unit tested.
class SalesHelper {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// '09 Nov 2026'
  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  /// 'Mon, 09 Nov 2026'
  static String formatDay(DateTime d) => '${_weekdays[d.weekday - 1]}, ${formatDate(d)}';

  /// '₹1,23,456.50' (Indian digit grouping, decimals only when needed).
  /// [symbol] can be changed, e.g. 'Rs. ' for PDFs whose font has no ₹ glyph.
  static String formatAmount(double amount, {String symbol = '₹'}) {
    final negative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    String whole = parts[0];
    if (whole.length > 3) {
      final last3 = whole.substring(whole.length - 3);
      String rest = whole.substring(0, whole.length - 3);
      final groups = <String>[];
      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) groups.insert(0, rest);
      whole = '${groups.join(',')},$last3';
    }
    final decimals = parts[1] == '00' ? '' : '.${parts[1]}';
    return '${negative ? '-' : ''}$symbol$whole$decimals';
  }

  /// Combines lines for the same product so stock is checked and changed once
  /// per product. The first line's price is kept.
  static List<StockLineItem> mergeLines(List<StockLineItem> items) {
    final merged = <String, StockLineItem>{};
    for (final item in items) {
      final existing = merged[item.productId];
      merged[item.productId] = existing == null
          ? item
          : StockLineItem(
              productId: existing.productId,
              productName: existing.productName,
              refNo: existing.refNo,
              quantity: existing.quantity + item.quantity,
              unitPrice: existing.unitPrice,
            );
    }
    return merged.values.toList();
  }

  /// Returns a readable error for every product whose stock is lower than the
  /// quantity being sold, or an empty list when everything is available.
  /// A product with no stock recorded counts as 0.
  static List<String> stockShortages(
    List<StockLineItem> items,
    Map<String, int?> availableStock,
  ) {
    final errors = <String>[];
    for (final item in mergeLines(items)) {
      final available = availableStock[item.productId] ?? 0;
      if (item.quantity > available) {
        errors.add('${item.productName}: only $available in stock, '
            'tried to sell ${item.quantity}.');
      }
    }
    return errors;
  }

  /// Applies the product and customer filters and drops cancelled sales.
  static List<SaleModel> filterSales(
    List<SaleModel> sales, {
    String? productId,
    String? customerId,
    bool includeCancelled = false,
  }) {
    return sales.where((s) {
      if (!includeCancelled && s.isCancelled) return false;
      if (customerId != null && s.customerId != customerId) return false;
      if (productId != null && !s.products.containsKey(productId)) return false;
      return true;
    }).toList();
  }

  /// Amount of a sale that counts towards totals. With a product filter only
  /// that product's lines are counted.
  static double saleAmount(SaleModel sale, {String? productId}) {
    if (productId == null) return sale.totalAmount;
    return sale.products[productId]?.amount ?? 0;
  }

  static int saleQuantity(SaleModel sale, {String? productId}) {
    if (productId == null) return sale.totalQuantity;
    return sale.products[productId]?.quantity ?? 0;
  }

  /// Groups sales by calendar day, newest day first. Cancelled sales are kept
  /// in the list (so they stay visible) but never added to the totals.
  static List<DaySales> groupByDay(List<SaleModel> sales, {String? productId}) {
    final byDay = <DateTime, List<SaleModel>>{};
    for (final sale in sales) {
      byDay.putIfAbsent(dayOnly(sale.saleDate), () => []).add(sale);
    }
    final days = byDay.entries.map((e) {
      final list = e.value..sort((a, b) => b.saleDate.compareTo(a.saleDate));
      final counted = list.where((s) => !s.isCancelled);
      return DaySales(
        day: e.key,
        sales: list,
        totalAmount: counted.fold(0.0, (acc, s) => acc + saleAmount(s, productId: productId)),
        totalQuantity: counted.fold(0, (acc, s) => acc + saleQuantity(s, productId: productId)),
      );
    }).toList();
    days.sort((a, b) => b.day.compareTo(a.day));
    return days;
  }
}

class DaySales {
  final DateTime day;
  final List<SaleModel> sales;
  final double totalAmount;
  final int totalQuantity;

  const DaySales({
    required this.day,
    required this.sales,
    required this.totalAmount,
    required this.totalQuantity,
  });

  int get saleCount => sales.where((s) => !s.isCancelled).length;
}
