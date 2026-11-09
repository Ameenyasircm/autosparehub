import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/sales_helper.dart';

/// Builds the Day-wise Sales PDF from exactly what the screen is showing.
///
/// Uses the built-in PDF font (no download needed). It has no ₹ glyph, so
/// amounts are written as 'Rs.', and characters it cannot draw are replaced.
class SalesReportPdf {
  static const String logoAsset = 'assets/AutoSpareLogo.jpg';
  static const String shopName = 'SN AutoSpare';
  static const String title = 'Day-wise Sales Report';

  static const PdfColor _dark = PdfColor.fromInt(0xFF1E222B);
  static const PdfColor _gold = PdfColor.fromInt(0xFFE5A93C);
  static const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _border = PdfColor.fromInt(0xFFDDE1E6);
  static const PdfColor _red = PdfColor.fromInt(0xFFD32F2F);

  static String _rs(double v) => SalesHelper.formatAmount(v, symbol: 'Rs. ');

  /// The standard PDF font only covers Western characters; anything else
  /// (e.g. a name typed in Malayalam) becomes '?' instead of breaking the file.
  static String safe(String text) =>
      String.fromCharCodes(text.runes.map((r) => r <= 0xFF ? r : 0x3F));

  static Future<Uint8List> build({
    required List<DaySales> days,
    required DateTime from,
    required DateTime to,
    String? productId,
    String? productName,
    String? customerName,
    DateTime? generatedAt,
    Uint8List? logoBytes,
  }) async {
    Uint8List? logo = logoBytes;
    if (logo == null) {
      try {
        logo = (await rootBundle.load(logoAsset)).buffer.asUint8List();
      } catch (_) {
        logo = null; // report still works without the logo
      }
    }

    final total = days.fold(0.0, (acc, d) => acc + d.totalAmount);
    final bills = days.fold(0, (acc, d) => acc + d.saleCount);
    final qty = days.fold(0, (acc, d) => acc + d.totalQuantity);
    final now = generatedAt ?? DateTime.now();
    final period = SalesHelper.formatDate(from) == SalesHelper.formatDate(to)
        ? SalesHelper.formatDate(from)
        : '${SalesHelper.formatDate(from)} to ${SalesHelper.formatDate(to)}';

    final doc = pw.Document(title: '$shopName - $title', author: shopName);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (ctx) => ctx.pageNumber == 1
            ? _header(logo, now)
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('$shopName - $title ($period)',
                    style: const pw.TextStyle(fontSize: 8, color: _grey)),
              ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ),
        build: (ctx) => [
          _filters(period, productName, customerName),
          pw.SizedBox(height: 10),
          _summary(total, bills, qty, productId != null),
          pw.SizedBox(height: 14),
          if (days.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 30),
              child: pw.Center(
                child: pw.Text('No sales for the selected filters.',
                    style: const pw.TextStyle(color: _grey)),
              ),
            )
          else
            for (final day in days) ...[
              _dayHeader(day),
              _dayTable(day, productId),
              pw.SizedBox(height: 12),
            ],
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _header(Uint8List? logo, DateTime now) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.ClipOval(
              child: pw.Image(pw.MemoryImage(logo), width: 52, height: 52, fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shopName,
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _dark)),
                pw.SizedBox(height: 2),
                pw.Text(title, style: const pw.TextStyle(fontSize: 12, color: _grey)),
              ],
            ),
          ),
          pw.Text(
            'Generated\n${SalesHelper.formatDate(now)} '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 8.5, color: _grey),
          ),
        ],
      ),
    );
  }

  static pw.Widget _filters(String period, String? product, String? customer) {
    pw.Widget item(String label, String value) => pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: '$label: ', style: const pw.TextStyle(fontSize: 9.5, color: _grey)),
            pw.TextSpan(text: safe(value), style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          ]),
        );
    return pw.Wrap(
      spacing: 18,
      runSpacing: 4,
      children: [
        item('Period', period),
        item('Product', product ?? 'All products'),
        item('Customer', customer ?? 'All customers'),
      ],
    );
  }

  static pw.Widget _summary(double total, int bills, int qty, bool productFiltered) {
    pw.Widget stat(String label, String value) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey300)),
              pw.SizedBox(height: 3),
              pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _gold)),
            ],
          ),
        );
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _dark, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(children: [
        stat('Total Sales', _rs(total)),
        stat('Bills', '$bills'),
        stat(productFiltered ? 'Qty Sold' : 'Items Sold', '$qty'),
      ]),
    );
  }

  static pw.Widget _dayHeader(DaySales day) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: const PdfColor.fromInt(0xFFFFF9EE),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Text(SalesHelper.formatDay(day.day),
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _dark)),
        ),
        pw.Text('${day.saleCount} bill${day.saleCount == 1 ? '' : 's'}   ',
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.Text(_rs(day.totalAmount), style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  static pw.Widget _dayTable(DaySales day, String? productId) {
    const headStyle = pw.TextStyle(fontSize: 8.5, color: _grey);
    pw.Widget cell(String text, {bool bold = false, bool right = false, bool cancelled = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            safe(text),
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: cancelled ? _grey : _dark,
              decoration: cancelled ? pw.TextDecoration.lineThrough : null,
            ),
          ),
        );

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.5),
        bottom: pw.BorderSide(color: _border, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(58),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(3.4),
        3: pw.FixedColumnWidth(72),
      },
      children: [
        pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Bill No', style: headStyle)),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Customer', style: headStyle)),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Items', style: headStyle)),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('Amount', style: headStyle, textAlign: pw.TextAlign.right),
          ),
        ]),
        for (final sale in day.sales)
          pw.TableRow(children: [
            cell(sale.saleNumber, cancelled: sale.isCancelled),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                cell(sale.customerName, bold: true, cancelled: sale.isCancelled),
                if (sale.isCancelled)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 6, bottom: 3),
                    child: pw.Text('CANCELLED',
                        style: pw.TextStyle(fontSize: 7, color: _red, fontWeight: pw.FontWeight.bold)),
                  ),
              ],
            ),
            cell(sale.itemSummary, cancelled: sale.isCancelled),
            cell(_rs(SalesHelper.saleAmount(sale, productId: productId)),
                bold: true, right: true, cancelled: sale.isCancelled),
          ]),
      ],
    );
  }
}
