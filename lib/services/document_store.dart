import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_page.dart';
import '../models/scanned_document.dart';

class DocumentStore {
  final Directory? directory;
  DocumentStore({this.directory});
  Future<Directory> _root() async {
    final root =
        directory ??
        Directory('${(await getApplicationSupportDirectory()).path}/library');
    return root.create(recursive: true);
  }

  Future<List<ScannedDocument>> load() async {
    final root = await _root();
    final documents = <ScannedDocument>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final metadata = File('${entry.path}/document.json');
      if (!await metadata.exists()) continue;
      // Surface corruption instead of silently overwriting an unreadable library.
      final json =
          jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
      final document = ScannedDocument.fromJson(json);
      // Store relative filenames: iOS container paths may change after updates.
      documents.add(
        ScannedDocument(
          id: document.id,
          name: document.name,
          createdAt: document.createdAt,
          pages: [
            for (final page in document.pages)
              ScanPage(
                id: page.id,
                path: '${entry.path}/${page.path}',
                filter: page.filter,
                ocr: page.ocr,
                annotations: page.annotations,
              ),
          ],
        ),
      );
    }
    documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return documents;
  }

  Future<ScannedDocument> save(ScannedDocument document) async {
    final root = await _root();
    final dir = await Directory('${root.path}/${document.id}')
        .create(recursive: true);
    final stored = <ScanPage>[];
    for (final page in document.pages) {
      // Versioned copies keep the previous saved document valid if writing fails.
      final extension = page.path.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpg';
      final filename = '${const Uuid().v4()}.$extension';
      await File(page.path).copy('${dir.path}/$filename');
      stored.add(
        ScanPage(
          id: page.id,
          path: filename,
          filter: page.filter,
          ocr: page.ocr,
          annotations: page.annotations,
        ),
      );
    }
    final saved = ScannedDocument(
      id: document.id,
      name: document.name,
      createdAt: document.createdAt,
      pages: stored,
    );
    final temporary = File('${dir.path}/document.json.tmp');
    await temporary.writeAsString(jsonEncode(saved.toJson()), flush: true);
    await temporary.rename('${dir.path}/document.json');
    final keep = stored.map((p) => p.path).toSet()..add('document.json');
    // Cleanup cannot turn a successful save into an apparent failure.
    await for (final entry in dir.list()) {
      if (entry is File && !keep.contains(entry.uri.pathSegments.last)) {
        try {
          await entry.delete();
        } on FileSystemException {
          /* Retry next save. */
        }
      }
    }
    return ScannedDocument(
      id: saved.id,
      name: saved.name,
      createdAt: saved.createdAt,
      pages: [
        for (final page in saved.pages)
          ScanPage(
            id: page.id,
            path: '${dir.path}/${page.path}',
            filter: page.filter,
            ocr: page.ocr,
            annotations: page.annotations,
          ),
      ],
    );
  }
}
