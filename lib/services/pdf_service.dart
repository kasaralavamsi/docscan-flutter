import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/scan_page.dart';

class PdfService {
  Future<Uint8List> buildPdf(
    List<ScanPage> pages, {
    bool searchable = true,
  }) async {
    if (pages.isEmpty) throw ArgumentError('At least one page is required.');
    if (searchable && pages.any((page) => page.ocr == null)) {
      throw StateError('Recognize every page before searchable export.');
    }
    final pdf = pw.Document();
    final font = searchable
        ? pw.Font.ttf(
            await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
          )
        : null;
    for (final page in pages) {
      final bytes = await File(page.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw StateError('Could not decode PDF page.');
      final scale =
          842 /
          (decoded.width > decoded.height ? decoded.width : decoded.height);
      final width = decoded.width * scale;
      final height = decoded.height * scale;
      final ocr = page.ocr;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(width, height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
              ),
              if (searchable && ocr != null)
                for (final word in ocr.words)
                  if (word.bounds.width > 0 && word.bounds.height > 0)
                    pw.Positioned(
                      left: word.bounds.left * width / ocr.width,
                      top: word.bounds.top * height / ocr.height,
                      child: pw.SizedBox(
                        width: word.bounds.width * width / ocr.width,
                        height: word.bounds.height * height / ocr.height,
                        child: pw.FittedBox(
                          fit: pw.BoxFit.fill,
                          child: pw.Text(
                            word.text,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 12,
                              renderingMode: PdfTextRenderingMode.invisible,
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      );
    }
    return pdf.save();
  }

  Future<String> createPdf(
    String name,
    List<ScanPage> pages, {
    bool searchable = true,
  }) async {
    final bytes = await buildPdf(pages, searchable: searchable);
    final dir = await getApplicationDocumentsDirectory();
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File(
      '${dir.path}/${safeName}_${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
