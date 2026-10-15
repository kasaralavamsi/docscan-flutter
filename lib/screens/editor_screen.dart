import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/scanner_service.dart';
import '../models/ocr_result.dart';
import '../models/page_annotation.dart';
import '../widgets/page_canvas.dart';
import 'annotation_screen.dart';
import 'ocr_editor_screen.dart';
import '../services/ocr_service.dart';
import '../models/scan_page.dart';
import '../services/image_service.dart';
import '../services/pdf_service.dart';

class EditorScreen extends StatefulWidget {
  final List<ScanPage> initialPages;
  final Future<void> Function(List<ScanPage>)? onSave;
  const EditorScreen({super.key, required this.initialPages, this.onSave});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late List<ScanPage> pages;
  int selected = 0;
  bool busy = false;
  final scanner = ScannerService();
  final ocrService = OcrService();
  bool searchable = true;
  final imageService = ImageService();
  final pdfService = PdfService();

  @override
  void initState() {
    super.initState();
    pages = List.of(widget.initialPages);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete action: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _crop() => _run(() async {
    final page = pages[selected];
    final source = page.annotations.isEmpty
        ? page.path
        : await pdfService.flattenPage(page);
    final out = await imageService.crop(source);
    if (out != null && mounted) {
      setState(() => pages[selected] = pages[selected].copyWith(path: out));
    }
  });

  Future<void> _filter(String filter) => _run(() async {
    final out = await imageService.applyFilter(pages[selected].path, filter);
    if (mounted) {
      setState(
        () => pages[selected] = pages[selected].copyWith(
          path: out,
          filter: filter,
          geometryChanged: false,
        ),
      );
    }
  });

  Future<void> _addPage() => _run(() async {
    final added = await scanner.scan();
    if (mounted && added.isNotEmpty) {
      setState(() {
        pages.addAll(added);
        selected = pages.length - 1;
      });
    }
  });

  Future<void> _recognize(int index) async {
    if (pages[index].ocr != null) return;
    final result = await ocrService.recognize(pages[index].path);
    if (mounted) {
      setState(() => pages[index] = pages[index].copyWith(ocr: result));
    }
  }

  Future<void> _saveAndClose() => _run(() async {
    await widget.onSave?.call(List.of(pages));
    if (mounted) Navigator.pop(context, pages);
  });

  Future<void> _rotate() => _run(() async {
    final page = pages[selected];
    final source = page.annotations.isEmpty
        ? page.path
        : await pdfService.flattenPage(page);
    final out = await imageService.rotate(source);
    if (mounted) setState(() => pages[selected] = page.copyWith(path: out));
  });

  Future<void> _annotate() => _run(() async {
    final result = await Navigator.push<List<PageAnnotation>>(
      context,
      MaterialPageRoute(
        builder: (_) => AnnotationScreen(page: pages[selected]),
      ),
    );
    if (mounted && result != null) {
      setState(
        () => pages[selected] = pages[selected].copyWith(annotations: result),
      );
    }
  });

  Future<void> _showText() => _run(() async {
    await _recognize(selected);
    if (!mounted) return;
    final result = await Navigator.push<OcrResult>(
      context,
      MaterialPageRoute(
        builder: (_) => OcrEditorScreen(result: pages[selected].ocr!),
      ),
    );
    if (mounted && result != null) {
      setState(() => pages[selected] = pages[selected].copyWith(ocr: result));
    }
  });

  Future<void> _export() => _run(() async {
    if (searchable) {
      for (var i = 0; i < pages.length; i++) {
        await _recognize(i);
        if (!mounted) return;
      }
    }
    final name = 'DocScan_${DateTime.now().toIso8601String().substring(0, 10)}';
    final path = await pdfService.createPdf(
      name,
      pages,
      searchable: searchable,
    );
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: '$name.pdf',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final page = pages[selected];
    return PopScope<List<ScanPage>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy) _saveAndClose();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111318),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111318),
          foregroundColor: Colors.white,
          title: Text('${selected + 1} / ${pages.length}'),
          actions: [
            IconButton(
              tooltip: 'Save and close',
              onPressed: busy ? null : _saveAndClose,
              icon: const Icon(Icons.save_outlined),
            ),
            TextButton(
              onPressed: busy ? null : _export,
              child: const Text('PDF & Share'),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: busy,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  'Searchable PDF (Latin text)',
                  style: TextStyle(color: Colors.white),
                ),
                value: searchable,
                onChanged: (value) => setState(() => searchable = value),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: PageCanvas(page: page),
                      ),
                    ),
                    if (busy) const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFF1B1E24),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  children: [
                    SizedBox(
                      height: 72,
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: pages.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final item = pages.removeAt(oldIndex);
                            pages.insert(newIndex, item);
                            selected = newIndex;
                          });
                        },
                        itemBuilder: (_, i) => GestureDetector(
                          key: ValueKey(pages[i].id),
                          onTap: () => setState(() => selected = i),
                          child: Container(
                            width: 58,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: i == selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(File(pages[i].path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _Action(
                            icon: Icons.text_snippet_outlined,
                            label: 'OCR',
                            onTap: _showText,
                          ),
                          _Action(
                            icon: Icons.edit_note,
                            label: 'Annotate',
                            onTap: _annotate,
                          ),
                          _Action(
                            icon: Icons.rotate_right,
                            label: 'Rotate',
                            onTap: _rotate,
                          ),
                          _Action(
                            icon: Icons.crop_rounded,
                            label: 'Crop',
                            onTap: _crop,
                          ),
                          _Action(
                            icon: Icons.auto_fix_high_rounded,
                            label: 'Auto',
                            onTap: () => _filter('Auto'),
                          ),
                          _Action(
                            icon: Icons.tonality_rounded,
                            label: 'Gray',
                            onTap: () => _filter('Grayscale'),
                          ),
                          _Action(
                            icon: Icons.contrast_rounded,
                            label: 'B&W',
                            onTap: () => _filter('B&W'),
                          ),
                          _Action(
                            icon: Icons.add_a_photo_rounded,
                            label: 'Add',
                            onTap: _addPage,
                          ),
                          _Action(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete',
                            onTap: pages.length == 1
                                ? null
                                : () => setState(() {
                                    pages.removeAt(selected);
                                    selected = selected.clamp(
                                      0,
                                      pages.length - 1,
                                    );
                                  }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: onTap == null ? Colors.white24 : Colors.white),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: onTap == null ? Colors.white24 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
