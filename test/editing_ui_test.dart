import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:docscan_clone/models/ocr_result.dart';
import 'package:docscan_clone/models/page_annotation.dart';
import 'package:docscan_clone/models/scan_page.dart';
import 'package:docscan_clone/screens/annotation_screen.dart';
import 'package:docscan_clone/screens/ocr_editor_screen.dart';
import 'package:docscan_clone/screens/editor_screen.dart';
import 'package:docscan_clone/widgets/page_canvas.dart';

Future<void> settlePage(WidgetTester tester) async {
  // File reads and image codecs complete on real event-loop turns, not fake time.
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(find.byType(CircularProgressIndicator), findsNothing);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'OCR corrections return edited words with their original page bounds',
    (tester) async {
      const original = OcrResult(
        text: 'Inv0ice',
        width: 200,
        height: 300,
        words: [OcrWord('Inv0ice', Rect.fromLTWH(20, 30, 60, 15))],
      );
      OcrResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<OcrResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OcrEditorScreen(result: original),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Invoice');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.text, 'Invoice');
      expect(result!.words.single.bounds, original.words.single.bounds);
    },
  );

  testWidgets(
    'saved annotations can be removed and undone before applying edits',
    (tester) async {
      late Directory root;
      final file = (await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('docscan_widget');
        final file = File('${root.path}/page.png');
        return file.writeAsBytes(
          img.encodePng(img.Image(width: 200, height: 300)),
        );
      }))!;
      addTearDown(() => root.deleteSync(recursive: true));

      final page = ScanPage(
        id: 'one',
        path: file.path,
        annotations: const [
          PageAnnotation(
            kind: AnnotationKind.highlight,
            bounds: Rect.fromLTWH(.1, .1, .5, .1),
          ),
        ],
      );
      List<PageAnnotation>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<List<PageAnnotation>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnnotationScreen(page: page),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await settlePage(tester);
      final canvas = tester.getRect(find.byType(PageCanvas).first);
      // The preview is centered with the page's 2:3 aspect ratio.
      final pageHeight = canvas.height;
      final pageWidth = pageHeight * 2 / 3;
      final left = canvas.center.dx - pageWidth / 2;
      await tester.longPressAt(
        Offset(left + pageWidth * .3, canvas.top + pageHeight * .15),
      );
      await tester.pumpAndSettle();
      final undo = find.byTooltip('Undo');
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Undo',
              ),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(undo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.length, 1);
      expect(result!.single.kind, AnnotationKind.highlight);
    },
  );

  testWidgets(
    'text, highlight and signature tools return visible page annotations',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('docscan_marks_widget');
      addTearDown(() => root.deleteSync(recursive: true));
      final file = File('${root.path}/page.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 200, height: 300)));
      List<PageAnnotation>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<List<PageAnnotation>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnnotationScreen(
                      page: ScanPage(id: 'one', path: file.path),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await settlePage(tester);
      final gesture = find.descendant(
        of: find.byType(PageCanvas),
        matching: find.byType(GestureDetector),
      );
      Rect pageRect() => tester.getRect(gesture);
      Offset point(double x, double y) => Offset(
        pageRect().left + pageRect().width * x,
        pageRect().top + pageRect().height * y,
      );
      await tester.tapAt(point(.2, .2));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Approved');
      await tester.tap(find.text('Apply').last);
      await tester.pumpAndSettle();
      await tester.dragFrom(point(.3, .23), Offset(pageRect().width * .1, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Highlight'));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        point(.1, .45),
        Offset(pageRect().width * .5, pageRect().height * .1),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign'));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        point(.1, .7),
        Offset(pageRect().width * .4, pageRect().height * .1),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.map((a) => a.kind), [
        AnnotationKind.text,
        AnnotationKind.highlight,
        AnnotationKind.signature,
      ]);
      expect(result![0].text, 'Approved');
      expect(result![0].bounds.left, greaterThan(.2));
      expect(result![1].bounds.width, greaterThan(.1));
      expect(result![2].points.length, greaterThan(1));
    },
  );

  testWidgets('failed save stays in editor so edits can be retried', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('docscan_save_widget');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/page.png');
    file.writeAsBytesSync(img.encodePng(img.Image(width: 200, height: 300)));
    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          initialPages: [ScanPage(id: 'one', path: file.path)],
          onSave: (_) async => throw FileSystemException('Disk full'),
        ),
      ),
    );
    await tester.pump();
    await settlePage(tester);
    await tester.tap(find.byTooltip('Save and close'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.textContaining('Disk full'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Save and close',
            ),
          )
          .onPressed,
      isNotNull,
    );
  });
}
