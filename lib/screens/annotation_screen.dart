import 'package:flutter/material.dart';

import '../models/page_annotation.dart';
import '../models/scan_page.dart';
import '../widgets/page_canvas.dart';

class AnnotationScreen extends StatefulWidget {
  final ScanPage page;
  const AnnotationScreen({super.key, required this.page});
  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  late List<PageAnnotation> annotations;
  AnnotationKind tool = AnnotationKind.text;
  final history = <List<PageAnnotation>>[];
  Offset? start;
  List<Offset> stroke = [];
  PageAnnotation? draft;
  int? moving;
  Rect? movingBounds;

  @override
  void initState() {
    super.initState();
    annotations = List.of(widget.page.annotations);
  }

  Offset _point(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0, 1),
    (local.dy / size.height).clamp(0, 1),
  );
  void _remember() => history.add(List.of(annotations));

  Future<void> _text(Offset point) async {
    final index = annotations.lastIndexWhere(
      (a) => a.kind == AnnotationKind.text && a.bounds.contains(point),
    );
    final old = index < 0 ? null : annotations[index];
    final annotation = await showDialog<PageAnnotation>(
      context: context,
      builder: (_) => _TextDialog(original: old, origin: point),
    );
    if (!mounted || annotation == null) return;
    final text = annotation.text;
    setState(() {
      _remember();
      if (text.isEmpty) {
        if (index >= 0) annotations.removeAt(index);
        return;
      }
      if (index >= 0) {
        annotations[index] = annotation;
      } else {
        annotations.add(annotation);
      }
    });
  }

  void _removeAt(Offset point) {
    final index = annotations.lastIndexWhere((a) {
      if (a.kind != AnnotationKind.signature) return a.bounds.contains(point);
      if (a.points.isEmpty) return false;
      var bounds = Rect.fromPoints(a.points.first, a.points.first);
      for (final p in a.points) {
        bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
      }
      return bounds.inflate(.015).contains(point);
    });
    if (index >= 0) {
      setState(() {
        _remember();
        annotations.removeAt(index);
      });
    }
  }

  void _begin(Offset point) {
    start = point;
    if (tool == AnnotationKind.text) {
      final index = annotations.lastIndexWhere(
        (a) => a.kind == AnnotationKind.text && a.bounds.contains(point),
      );
      if (index >= 0) {
        _remember();
        moving = index;
        movingBounds = annotations[index].bounds;
      }
    } else if (tool == AnnotationKind.signature) {
      stroke = [point];
    }
  }

  void _update(Offset point) {
    if (start == null) return;
    setState(() {
      if (tool == AnnotationKind.text && moving != null) {
        final old = annotations[moving!];
        final rect = movingBounds!;
        annotations[moving!] = PageAnnotation(
          kind: old.kind,
          text: old.text,
          bounds: Rect.fromLTWH(
            (rect.left + point.dx - start!.dx).clamp(0, 1 - rect.width),
            (rect.top + point.dy - start!.dy).clamp(0, 1 - rect.height),
            rect.width,
            rect.height,
          ),
        );
      } else if (tool == AnnotationKind.highlight) {
        draft = PageAnnotation(
          kind: tool,
          bounds: Rect.fromPoints(start!, point),
        );
      } else if (tool == AnnotationKind.signature) {
        stroke.add(point);
        draft = PageAnnotation(
          kind: tool,
          bounds: Rect.zero,
          points: List.of(stroke),
        );
      }
    });
  }

  void _end() {
    setState(() {
      if (draft != null &&
          (tool == AnnotationKind.signature ||
              draft!.bounds.width > .005 && draft!.bounds.height > .005)) {
        _remember();
        annotations.add(draft!);
      }
      start = null;
      moving = null;
      draft = null;
      stroke = [];
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Annotate page'),
      actions: [
        IconButton(
          tooltip: 'Undo',
          onPressed: history.isEmpty
              ? null
              : () => setState(() => annotations = history.removeLast()),
          icon: const Icon(Icons.undo),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, annotations),
          child: const Text('Apply'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<AnnotationKind>(
              segments: const [
                ButtonSegment(
                  value: AnnotationKind.text,
                  label: Text('Text'),
                  icon: Icon(Icons.text_fields),
                ),
                ButtonSegment(
                  value: AnnotationKind.highlight,
                  label: Text('Highlight'),
                  icon: Icon(Icons.highlight),
                ),
                ButtonSegment(
                  value: AnnotationKind.signature,
                  label: Text('Sign'),
                  icon: Icon(Icons.draw),
                ),
              ],
              selected: {tool},
              onSelectionChanged: (value) =>
                  setState(() => tool = value.single),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              tool == AnnotationKind.text
                  ? 'Tap to add/edit text; drag it to move. Long-press any mark to delete.'
                  : tool == AnnotationKind.highlight
                  ? 'Drag to highlight. Long-press any mark to delete.'
                  : 'Draw your signature. Long-press a mark to delete.',
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PageCanvas(
                page: widget.page.copyWith(
                  annotations: [...annotations, ?draft],
                ),
                overlay: (size) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPressStart: (d) =>
                      _removeAt(_point(d.localPosition, size)),
                  onTapUp: tool == AnnotationKind.text
                      ? (d) => _text(_point(d.localPosition, size))
                      : null,
                  onPanStart: (d) => _begin(_point(d.localPosition, size)),
                  onPanUpdate: (d) => _update(_point(d.localPosition, size)),
                  onPanEnd: (_) => _end(),
                  onPanCancel: _end,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TextDialog extends StatefulWidget {
  final PageAnnotation? original;
  final Offset origin;
  const _TextDialog({this.original, required this.origin});
  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController controller;
  late double width;
  late double height;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.original?.text ?? '');
    width = widget.original?.bounds.width ?? .45;
    height = widget.original?.bounds.height ?? .06;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.original == null ? 'Add text' : 'Edit text'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Text'),
          ),
          const Text('Width'),
          Slider(
            value: width,
            min: .15,
            max: .85,
            onChanged: (value) => setState(() => width = value),
          ),
          const Text('Height'),
          Slider(
            value: height,
            min: .025,
            max: .2,
            onChanged: (value) => setState(() => height = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final origin = widget.original?.bounds.topLeft ?? widget.origin;
          Navigator.pop(
            context,
            PageAnnotation(
              kind: AnnotationKind.text,
              text: controller.text.trim(),
              bounds: Rect.fromLTWH(
                origin.dx.clamp(0, 1 - width),
                origin.dy.clamp(0, 1 - height),
                width,
                height,
              ),
            ),
          );
        },
        child: const Text('Apply'),
      ),
    ],
  );
}
