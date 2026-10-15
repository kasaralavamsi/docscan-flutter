import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/scan_page.dart';

class PdfService {
  Future<String> createPdf(String name, List<ScanPage> pages) async {
    final pdf = pw.Document();
    for (final page in pages) {
      final bytes = await File(page.path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    final dir = await getApplicationDocumentsDirectory();
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${dir.path}/$safeName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}
