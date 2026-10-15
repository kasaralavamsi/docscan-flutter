import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_page.dart';

class ImportedDocument {
  final String name;
  final List<ScanPage> pages;
  const ImportedDocument(this.name, this.pages);
}

class ImportService {
  final Directory? directory;
  final Stream<PdfRaster> Function(Uint8List) rasterize;
  ImportService({this.directory, this.rasterize = _rasterize});
  static Stream<PdfRaster> _rasterize(Uint8List bytes) =>
      Printing.raster(bytes, dpi: 144);
  Future<ImportedDocument?> pickPdf() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return null;
    final size = await file.length();
    if (size != null && size > 50 * 1024 * 1024) {
      throw StateError('Choose a PDF smaller than 50 MB.');
    }
    final bytes = await file.readAsBytes();
    return importPdf(bytes, file.name);
  }

  Future<ImportedDocument> importPdf(Uint8List bytes, String name) async {
    if (bytes.length > 50 * 1024 * 1024) throw StateError('PDF exceeds 50 MB.');
    final dir = await Directory(
      '${(directory ?? await getTemporaryDirectory()).path}/${const Uuid().v4()}',
    ).create(recursive: true);
    final pages = <ScanPage>[];
    try {
      // Request one page at a time to avoid retaining a whole rendered PDF.
      await for (final raster in rasterize(bytes)) {
        if (pages.length >= 100) {
          throw StateError('Import supports up to 100 pages.');
        }
        final id = const Uuid().v4();
        final out = File('${dir.path}/$id.png');
        await out.writeAsBytes(await raster.toPng());
        pages.add(ScanPage(id: id, path: out.path));
      }
      if (pages.isEmpty) throw StateError('This PDF has no readable pages.');
      return ImportedDocument(
        name.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), ''),
        pages,
      );
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    }
  }
}
