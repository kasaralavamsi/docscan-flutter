import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_page.dart';

class ScannerService {
  Future<List<ScanPage>> scan() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Document scanning requires Android or iOS.');
    }
    final paths = await CunningDocumentScanner.getPictures(
      noOfPages: 100,
      scannerSource: ScannerSource.camera,
    );
    if (paths == null || paths.isEmpty) return [];
    // Plugin-owned files can be reclaimed. Keep a private session copy.
    final dir = await getApplicationSupportDirectory();
    final pages = <ScanPage>[];
    for (final path in paths) {
      final id = const Uuid().v4();
      final extension = path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final copy = await File(path).copy('${dir.path}/$id.$extension');
      pages.add(ScanPage(id: id, path: copy.path));
    }
    return pages;
  }
}
