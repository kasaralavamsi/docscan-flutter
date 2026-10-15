import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:docscan_clone/services/import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('docscan_import'),
  );
  tearDown(() async => root.delete(recursive: true));
  PdfRaster raster() =>
      PdfRaster(2, 2, Uint8List.fromList(List.filled(16, 255)));
  test(
    'imports every rendered page in order into independent image files',
    () async {
      final service = ImportService(
        directory: root,
        rasterize: (_) => Stream.fromIterable([raster(), raster()]),
      );
      final result = await service.importPdf(Uint8List(1), 'Contract.PDF');
      expect(result.name, 'Contract');
      expect(result.pages.length, 2);
      expect(result.pages[0].path, isNot(result.pages[1].path));
      expect(await File(result.pages[0].path).exists(), isTrue);
    },
  );
  test('native rendering error removes partial imports', () async {
    Stream<PdfRaster> broken(Uint8List bytes) async* {
      yield raster();
      throw StateError('Encrypted or invalid PDF');
    }

    final service = ImportService(directory: root, rasterize: broken);
    await expectLater(
      service.importPdf(Uint8List(1), 'broken.pdf'),
      throwsStateError,
    );
    expect(await root.list().toList(), isEmpty);
  });
  test(
    'rejects over-limit PDFs without keeping a truncated document',
    () async {
      final service = ImportService(
        directory: root,
        rasterize: (_) =>
            Stream.fromIterable(List.generate(101, (_) => raster())),
      );
      await expectLater(
        service.importPdf(Uint8List(1), 'large.pdf'),
        throwsStateError,
      );
      expect(await root.list().toList(), isEmpty);
      await expectLater(
        service.importPdf(Uint8List(50 * 1024 * 1024 + 1), 'large.pdf'),
        throwsStateError,
      );
    },
  );
}
