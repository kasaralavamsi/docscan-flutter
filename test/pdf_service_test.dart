import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:docscan_clone/models/ocr_result.dart';
import 'package:docscan_clone/models/scan_page.dart';
import 'package:docscan_clone/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ocr = OcrResult(
    text: 'Invoice café',
    width: 200,
    height: 300,
    words: [
      OcrWord('Invoice', Rect.fromLTWH(20, 30, 60, 15)),
      OcrWord('café', Rect.fromLTWH(90, 30, 30, 15)),
    ],
  );

  test('image edits invalidate OCR while metadata edits retain it', () {
    const page = ScanPage(id: 'one', path: 'old.jpg', ocr: ocr);
    expect(page.copyWith(filter: 'Auto').ocr, same(ocr));
    expect(page.copyWith(path: 'cropped.jpg').ocr, isNull);
    expect(page.copyWith(path: 'old.jpg').ocr, isNull);
  });

  test('searchable export requires OCR and at least one page', () async {
    final service = PdfService();
    await expectLater(service.buildPdf([]), throwsArgumentError);
    await expectLater(
      service.buildPdf([const ScanPage(id: '1', path: 'missing')]),
      throwsStateError,
    );
  });

  test(
    'generates searchable and image-only PDFs including blank OCR',
    () async {
      final dir = Directory('build/test_outputs')..createSync(recursive: true);
      final portrait = File('${dir.path}/portrait.png');
      final landscape = File('${dir.path}/landscape.png');
      await portrait.writeAsBytes(
        img.encodePng(img.Image(width: 200, height: 300)),
      );
      await landscape.writeAsBytes(
        img.encodePng(img.Image(width: 300, height: 200)),
      );
      final pages = [
        ScanPage(id: '1', path: portrait.path, ocr: ocr),
        ScanPage(
          id: '2',
          path: landscape.path,
          ocr: const OcrResult(text: '', width: 300, height: 200, words: []),
        ),
      ];
      final service = PdfService();
      for (final searchable in [true, false]) {
        final bytes = await service.buildPdf(pages, searchable: searchable);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(500));
        await File(
          '${dir.path}/${searchable ? 'searchable' : 'image_only'}.pdf',
        ).writeAsBytes(bytes);
      }
      // An explicit image-only export must not require OCR.
      await service.buildPdf([
        ScanPage(id: '3', path: portrait.path),
      ], searchable: false);
    },
  );
}
