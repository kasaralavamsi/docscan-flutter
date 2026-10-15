import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/page_annotation.dart';
import '../models/scan_page.dart';

/// Fits both the image and overlays to the exact same page rectangle.
class PageCanvas extends StatefulWidget {
  final ScanPage page;
  final Widget Function(Size size)? overlay;
  const PageCanvas({super.key, required this.page, this.overlay});
  @override
  State<PageCanvas> createState() => _PageCanvasState();
}

class _PageCanvasState extends State<PageCanvas> {
  late Future<Size> dimensions;
  @override
  void initState() {
    super.initState();
    dimensions = _dimensions();
  }

  @override
  void didUpdateWidget(PageCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.path != widget.page.path) dimensions = _dimensions();
  }

  Future<Size> _dimensions() async {
    final codec = await ui.instantiateImageCodec(
      await File(widget.page.path).readAsBytes(),
    );
    try {
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } finally {
      codec.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Size>(
    future: dimensions,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Could not open page image.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = applyBoxFit(
            BoxFit.contain,
            snapshot.data!,
            constraints.biggest,
          ).destination;
          return Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(widget.page.path), fit: BoxFit.fill),
                  CustomPaint(
                    painter: AnnotationPainter(widget.page.annotations),
                  ),
                  if (widget.overlay != null) widget.overlay!(size),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class AnnotationPainter extends CustomPainter {
  final List<PageAnnotation> annotations;
  AnnotationPainter(this.annotations);
  @override
  void paint(Canvas canvas, Size size) {
    for (final a in annotations) {
      final rect = Rect.fromLTWH(
        a.bounds.left * size.width,
        a.bounds.top * size.height,
        a.bounds.width * size.width,
        a.bounds.height * size.height,
      );
      switch (a.kind) {
        case AnnotationKind.highlight:
          canvas.drawRect(rect, Paint()..color = const Color(0x66FFEB3B));
        case AnnotationKind.signature:
          if (a.points.isEmpty) continue;
          final path = Path()
            ..moveTo(
              a.points.first.dx * size.width,
              a.points.first.dy * size.height,
            );
          for (final p in a.points.skip(1)) {
            path.lineTo(p.dx * size.width, p.dy * size.height);
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.blue.shade900
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = size.width * .003,
          );
        case AnnotationKind.text:
          if (a.text.isEmpty || rect.isEmpty) continue;
          final painter = TextPainter(
            text: TextSpan(
              text: a.text,
              style: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 20,
                color: Colors.black,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          canvas.save();
          final scale = math.min(
            rect.width / painter.width,
            rect.height / painter.height,
          );
          canvas.translate(
            rect.left + (rect.width - painter.width * scale) / 2,
            rect.top + (rect.height - painter.height * scale) / 2,
          );
          canvas.scale(scale);
          painter.paint(canvas, Offset.zero);
          canvas.restore();
          painter.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) => true;
}
