import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:docscan_clone/models/ocr_result.dart';
import 'package:docscan_clone/models/page_annotation.dart';
import 'package:docscan_clone/models/scan_page.dart';
import 'package:docscan_clone/models/scanned_document.dart';
import 'package:docscan_clone/services/document_store.dart';

void main() {
  late Directory root;
  late File image;
  const marks = [
    PageAnnotation(
      kind: AnnotationKind.text,
      bounds: Rect.fromLTWH(.1, .2, .4, .08),
      text: 'Approved café',
    ),
    PageAnnotation(
      kind: AnnotationKind.highlight,
      bounds: Rect.fromLTWH(.1, .4, .5, .1),
    ),
    PageAnnotation(
      kind: AnnotationKind.signature,
      bounds: Rect.zero,
      points: [Offset(.1, .8), Offset(.2, .7)],
    ),
  ];
  const ocr = OcrResult(
    text: 'Inv0ice',
    width: 200,
    height: 300,
    words: [OcrWord('Inv0ice', Rect.fromLTWH(20, 30, 60, 15))],
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('docscan_store_test');
    image = await File('${root.path}/source.png').writeAsBytes([1, 2, 3, 4]);
  });
  tearDown(() async => root.delete(recursive: true));
  ScannedDocument document(List<ScanPage> pages) => ScannedDocument(
    id: 'document',
    name: 'Receipt',
    createdAt: DateTime(2026, 10, 15),
    pages: pages,
  );

  test('saved images, annotations and OCR corrections survive restart and container relocation', () async {
    final library = Directory('${root.path}/library');
    final store = DocumentStore(directory: library);
    await store.save(
      document([
        ScanPage(
          id: 'one',
          path: image.path,
          ocr: ocr.correctWords(['Invoice']),
          annotations: marks,
        ),
      ]),
    );
    await image.delete();
    final moved = await library.rename('${root.path}/relocated');
    final loaded = (await DocumentStore(directory: moved).load()).single;
    expect(loaded.name, 'Receipt');
    expect(await File(loaded.pages.single.path).readAsBytes(), [1, 2, 3, 4]);
    expect(loaded.pages.single.ocr!.text, 'Invoice');
    expect(
      loaded.pages.single.ocr!.words.single.bounds,
      ocr.words.single.bounds,
    );
    expect(
      loaded.pages.single.annotations.map((a) => a.toJson()).toList(),
      marks.map((a) => a.toJson()).toList(),
    );
  });

  test('failed save keeps previous version; next successful save cleans old images', () async {
    final library = Directory('${root.path}/library');
    final store = DocumentStore(directory: library);
    final saved = await store.save(
      document([ScanPage(id: 'one', path: image.path)]),
    );
    await expectLater(
      store.save(
        document([
          saved.pages.single,
          const ScanPage(id: 'missing', path: '/missing/docscan-test.png'),
        ]),
      ),
      throwsA(isA<FileSystemException>()),
    );
    final reopened = (await store.load()).single;
    expect(reopened.pages.length, 1);
    expect(await File(reopened.pages.single.path).exists(), isTrue);
    await store.save(
      document([reopened.pages.single.copyWith(annotations: marks)]),
    );
    final files = await Directory('${library.path}/document').list().toList();
    expect(
      files.length,
      2,
    ); // Only current image and committed metadata remain.
    expect((await store.load()).single.pages.single.annotations.length, 3);
  });

  test('filters retain marks; geometry changes invalidate OCR and clear old overlay coordinates', () {
    final page = ScanPage(
      id: 'one',
      path: image.path,
      ocr: ocr,
      annotations: marks,
    );
    final filtered = page.copyWith(
      path: 'filtered.png',
      geometryChanged: false,
    );
    expect(filtered.annotations, marks);
    expect(filtered.ocr, isNull);
    expect(page.copyWith(path: 'cropped.png').annotations, isEmpty);
    expect(() => ocr.correctWords([]), throwsArgumentError);
  });
}
