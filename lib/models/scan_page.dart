import 'ocr_result.dart';
import 'page_annotation.dart';

class ScanPage {
  final String id;
  final String path;
  final String filter;
  final OcrResult? ocr;
  final List<PageAnnotation> annotations;

  const ScanPage({
    required this.id,
    required this.path,
    this.filter = 'Original',
    this.ocr,
    this.annotations = const [],
  });

  ScanPage copyWith({
    String? path,
    String? filter,
    OcrResult? ocr,
    List<PageAnnotation>? annotations,
    bool geometryChanged = true,
  }) => ScanPage(
    id: id,
    path: path ?? this.path,
    filter: filter ?? this.filter,
    ocr: path != null ? null : (ocr ?? this.ocr),
    annotations:
        annotations ??
        (path != null && geometryChanged ? const [] : this.annotations),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'filter': filter,
    'ocr': ocr?.toJson(),
    'annotations': annotations.map((a) => a.toJson()).toList(),
  };
  factory ScanPage.fromJson(Map<String, dynamic> json) => ScanPage(
    id: json['id'] as String,
    path: json['path'] as String,
    filter: json['filter'] as String,
    ocr: json['ocr'] == null
        ? null
        : OcrResult.fromJson(json['ocr'] as Map<String, dynamic>),
    annotations: [
      for (final a in json['annotations'] as List? ?? [])
        PageAnnotation.fromJson(a as Map<String, dynamic>),
    ],
  );
}
