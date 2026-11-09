import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/customer_model.dart';
import '../../../models/product_model.dart';
import '../../../models/sales_models.dart';
import '../../../providers/admin_login_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/sales_provider.dart';
import '../../../services/sales_report_pdf.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/phone_helper.dart';
import '../../../utils/sales_helper.dart';
import 'sales_report_pdf_screen.dart';
import 'sales_widgets.dart';

/// Day-wise sales with a date-range (calendar), product and customer filter.
class DayWiseSalesScreen extends StatefulWidget {
  const DayWiseSalesScreen({super.key});

  @override
  State<DayWiseSalesScreen> createState() => _DayWiseSalesScreenState();
}

class _DayWiseSalesScreenState extends State<DayWiseSalesScreen> {
  late DateTimeRange _range;
  ProductModel? _product;
  CustomerModel? _customer;

  @override
  void initState() {
    super.initState();
    final today = SalesHelper.dayOnly(DateTime.now());
    _range = DateTimeRange(start: DateTime(today.year, today.month, 1), end: today);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      context.read<SalesProvider>().fetchSales(from: _range.start, to: _range.end);

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  /// Exports exactly what is listed: same dates, filters and days.
  void _openPdf(List<DaySales> days) {
    String ymd(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final from = _range.start;
    final to = _range.end;
    final productId = _product?.id;
    final productName = _product?.name;
    final customerName = _customer?.name;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SalesReportPdfScreen(
        fileName: 'sales_report_${ymd(from)}_${ymd(to)}.pdf',
        buildPdf: () => SalesReportPdf.build(
          days: days,
          from: from,
          to: to,
          productId: productId,
          productName: productName,
          customerName: customerName,
        ),
      ),
    ));
  }

  String get _rangeLabel {
    final s = SalesHelper.formatDate(_range.start);
    final e = SalesHelper.formatDate(_range.end);
    return s == e ? s : '$s  –  $e';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesProvider>();
    final filtered = SalesHelper.filterSales(
      provider.sales,
      productId: _product?.id,
      customerId: _customer?.id,
      includeCancelled: true,
    );
    final days = SalesHelper.groupByDay(filtered, productId: _product?.id);
    final grandTotal = days.fold(0.0, (acc, d) => acc + d.totalAmount);
    final saleCount = days.fold(0, (acc, d) => acc + d.saleCount);
    final qty = days.fold(0, (acc, d) => acc + d.totalQuantity);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Day-wise Sales',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: provider.isLoading ? null : () => _openPdf(days),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.warmGold,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SelectorTile(
              icon: Icons.date_range_rounded,
              label: 'Dates',
              value: _rangeLabel,
              placeholder: '',
              onTap: _pickRange,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SelectorTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Product',
                    value: _product?.name,
                    placeholder: 'All products',
                    onTap: () async {
                      final p = await showProductPicker(context, forSale: false);
                      if (p != null) setState(() => _product = p);
                    },
                    onClear: () => setState(() => _product = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectorTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Customer',
                    value: _customer?.name,
                    placeholder: 'All customers',
                    onTap: () async {
                      final c = await showCustomerPicker(context);
                      if (c != null) setState(() => _customer = c);
                    },
                    onClear: () => setState(() => _customer = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSummary(grandTotal, saleCount, qty),
            const SizedBox(height: 14),
            if (provider.errorMessage != null && !provider.isSaving)
              SalesErrorBanner(provider.errorMessage!),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.warmGold)),
              )
            else if (days.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text('No sales for the selected filters.',
                      style: TextStyle(color: AppColors.secondaryText)),
                ),
              )
            else
              ...days.map(_buildDay),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(double total, int count, int qty) {
    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        color: AppColors.primaryGold, fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.darkHeader, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          stat('Total Sales', SalesHelper.formatAmount(total)),
          stat('Bills', '$count'),
          stat(_product == null ? 'Items Sold' : 'Qty Sold', '$qty'),
        ],
      ),
    );
  }

  Widget _buildDay(DaySales day) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(SalesHelper.formatDay(day.day),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.darkHeader)),
                ),
                Text('${day.saleCount} bill${day.saleCount == 1 ? '' : 's'} • ',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12.5)),
                Text(SalesHelper.formatAmount(day.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
          ...day.sales.map(_buildSaleTile),
        ],
      ),
    );
  }

  Widget _buildSaleTile(SaleModel sale) {
    final amount = SalesHelper.saleAmount(sale, productId: _product?.id);
    final faded = sale.isCancelled;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      color: Colors.white,
      child: ListTile(
        onTap: () => _showSaleDetail(sale),
        title: Row(
          children: [
            Flexible(
              child: Text(sale.customerName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    decoration: faded ? TextDecoration.lineThrough : null,
                  )),
            ),
            if (faded) ...[
              const SizedBox(width: 6),
              const Text('CANCELLED',
                  style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w800)),
            ],
          ],
        ),
        subtitle: Text('${sale.saleNumber} • ${sale.itemSummary}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        trailing: Text(
          SalesHelper.formatAmount(amount),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: faded ? AppColors.secondaryText : AppColors.primaryText,
            decoration: faded ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  void _showSaleDetail(SaleModel sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(sale.saleNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  if (sale.isCancelled) ...[
                    const SizedBox(width: 8),
                    const Text('CANCELLED',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 11)),
                  ],
                  const Spacer(),
                  Text(SalesHelper.formatDay(sale.saleDate),
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 6),
              Text('${sale.customerName} • ${PhoneHelper.formatForDisplay(sale.customerPhone)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (sale.createdByName != null)
                Text('Entered by ${sale.createdByName}',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              const Divider(height: 22),
              FutureBuilder<List<StockLineItem>>(
                future: context.read<SalesProvider>().fetchSaleItems(sale),
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator(color: AppColors.warmGold)),
                    );
                  }
                  if (snap.hasError || (snap.data ?? []).isEmpty) {
                    // Offline or failed: fall back to the summary on the sale document.
                    return Column(
                      children: sale.products.values
                          .map((p) => _itemRow(p.name, '${p.quantity} pcs', p.amount))
                          .toList(),
                    );
                  }
                  return Column(
                    children: snap.data!
                        .map((i) => _itemRow(
                              i.productName,
                              '${i.quantity} × ${SalesHelper.formatAmount(i.unitPrice)}',
                              i.total,
                            ))
                        .toList(),
                  );
                },
              ),
              const Divider(height: 18),
              Row(
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const Spacer(),
                  Text(SalesHelper.formatAmount(sale.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ],
              ),
              if ((sale.note ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Note: ${sale.note}', style: const TextStyle(color: AppColors.secondaryText)),
              ],
              if (!sale.isCancelled) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Sale & Return Stock'),
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    await _confirmCancel(sale);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemRow(String name, String detail, double amount) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text('$name\n$detail', style: const TextStyle(fontSize: 13.5, height: 1.35)),
            ),
            Text(SalesHelper.formatAmount(amount), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Future<void> _confirmCancel(SaleModel sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel ${sale.saleNumber}?'),
        content: const Text(
            'The sold quantity will be added back to stock. The sale stays in the list as cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Sale', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final sales = context.read<SalesProvider>();
    final products = context.read<ProductProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await sales.cancelSale(sale, admin: context.read<AdminLoginProvider>().currentAdmin);
    if (ok) products.fetchProducts();
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? '${sale.saleNumber} cancelled. Stock returned.' : (sales.errorMessage ?? 'Failed')),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }
}
