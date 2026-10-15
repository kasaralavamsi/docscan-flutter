import 'ocr_result.dart';

class ScanPage {
  final String id;
  final String path;
  final String filter;
  final OcrResult? ocr;

  const ScanPage({
    required this.id,
    required this.path,
    this.filter = 'Original',
    this.ocr,
  });

  ScanPage copyWith({String? path, String? filter, OcrResult? ocr}) => ScanPage(
    id: id,
    path: path ?? this.path,
    filter: filter ?? this.filter,
    ocr: path != null ? null : (ocr ?? this.ocr),
  );
}
