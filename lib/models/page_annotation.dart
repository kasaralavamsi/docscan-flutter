import 'dart:ui';

enum AnnotationKind { text, highlight, signature }

class PageAnnotation {
  final AnnotationKind kind;
  final Rect bounds;
  final String text;
  final List<Offset> points;
  const PageAnnotation({
    required this.kind,
    required this.bounds,
    this.text = '',
    this.points = const [],
  });

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'bounds': [bounds.left, bounds.top, bounds.width, bounds.height],
    'text': text,
    'points': [
      for (final point in points) [point.dx, point.dy],
    ],
  };
  factory PageAnnotation.fromJson(Map<String, dynamic> json) {
    final b = (json['bounds'] as List).cast<num>();
    return PageAnnotation(
      kind: AnnotationKind.values.byName(json['kind'] as String),
      bounds: Rect.fromLTWH(
        b[0].toDouble(),
        b[1].toDouble(),
        b[2].toDouble(),
        b[3].toDouble(),
      ),
      text: json['text'] as String,
      points: [
        for (final p in json['points'] as List)
          Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
    );
  }
}
