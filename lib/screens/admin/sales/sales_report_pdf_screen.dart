import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../theme/app_theme.dart';

/// Shows the generated report with Share / Print buttons (via `printing`).
class SalesReportPdfScreen extends StatelessWidget {
  final Future<Uint8List> Function() buildPdf;
  final String fileName;

  const SalesReportPdfScreen({super.key, required this.buildPdf, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Sales Report PDF',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      // Pinch with two fingers to zoom (up to 5x); drag to move when zoomed.
      body: PdfPreview.builder(
        build: (_) => buildPdf(),
        // Rendered sharper than the default so text stays readable when zoomed.
        dpi: 200,
        pagesBuilder: (context, pages) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final page in pages)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: page.aspectRatio,
                    child: Image(image: page.image, fit: BoxFit.contain),
                  ),
                ),
            ],
          ),
        ),
        pdfFileName: fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        loadingWidget: const CircularProgressIndicator(color: AppColors.warmGold),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not create the PDF.\n$error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
