import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:docscan_clone/models/ocr_result.dart';
import 'package:docscan_clone/models/scan_page.dart';
import 'package:docscan_clone/models/page_annotation.dart';
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
        img.encodePng(
          img.fill(
            img.Image(width: 200, height: 300),
            color: img.ColorRgb8(255, 255, 255),
          ),
        ),
      );
      await landscape.writeAsBytes(
        img.encodePng(
          img.fill(
            img.Image(width: 300, height: 200),
            color: img.ColorRgb8(255, 255, 255),
          ),
        ),
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
      final corrected = pages.first.copyWith(
        ocr: ocr.correctWords(['Receipt', '']),
      );
      await File('${dir.path}/corrected.pdf')
          .writeAsBytes(await service.buildPdf([corrected]));
      final annotated = pages.first.copyWith(
        annotations: const [
          PageAnnotation(
            kind: AnnotationKind.text,
            bounds: Rect.fromLTWH(.1, .25, .5, .08),
            text: 'Approved café',
          ),
          PageAnnotation(
            kind: AnnotationKind.highlight,
            bounds: Rect.fromLTWH(.1, .45, .5, .1),
          ),
          PageAnnotation(
            kind: AnnotationKind.signature,
            bounds: Rect.zero,
            points: [Offset(.1, .7), Offset(.25, .8), Offset(.4, .7)],
          ),
        ],
      );
      await File('${dir.path}/annotated.pdf')
          .writeAsBytes(await service.buildPdf([annotated]));
      await File('${dir.path}/annotated_without_ocr.pdf')
          .writeAsBytes(await service.buildPdf([annotated], searchable: false));
      // An explicit image-only export must not require OCR.
      await service.buildPdf([
        ScanPage(id: '3', path: portrait.path),
      ], searchable: false);
    },
  );
}
