import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/scan_page.dart';
import '../services/image_service.dart';
import '../services/pdf_service.dart';

class EditorScreen extends StatefulWidget {
  final List<ScanPage> initialPages;
  const EditorScreen({super.key, required this.initialPages});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late List<ScanPage> pages;
  int selected = 0;
  bool busy = false;
  final picker = ImagePicker();
  final imageService = ImageService();
  final pdfService = PdfService();
  final uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    pages = List.of(widget.initialPages);
  }

  Future<void> _crop() async {
    final out = await imageService.crop(pages[selected].path);
    if (out != null) setState(() => pages[selected] = pages[selected].copyWith(path: out));
  }

  Future<void> _filter(String filter) async {
    setState(() => busy = true);
    try {
      final out = await imageService.applyFilter(pages[selected].path, filter);
      if (mounted) setState(() => pages[selected] = pages[selected].copyWith(path: out, filter: filter));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addPage() async {
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 96);
    if (x != null) setState(() { pages.add(ScanPage(id: uuid.v4(), path: x.path)); selected = pages.length - 1; });
  }

  Future<void> _export() async {
    setState(() => busy = true);
    try {
      final name = 'DocScan_${DateTime.now().toIso8601String().substring(0, 10)}';
      final path = await pdfService.createPdf(name, pages);
      if (!mounted) return;
      await Share.shareXFiles([XFile(path)], text: '$name.pdf');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = pages[selected];
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111318),
        foregroundColor: Colors.white,
        title: Text('${selected + 1} / ${pages.length}'),
        actions: [TextButton(onPressed: busy ? null : _export, child: const Text('PDF & Share'))],
      ),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            Center(child: Padding(padding: const EdgeInsets.all(16), child: Image.file(File(page.path), fit: BoxFit.contain))),
            if (busy) const Center(child: CircularProgressIndicator()),
          ]),
        ),
        Container(
          color: const Color(0xFF1B1E24),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(children: [
            SizedBox(
              height: 72,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pages.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
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
                      border: Border.all(color: i == selected ? Colors.white : Colors.transparent, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(image: FileImage(File(pages[i].path)), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _Action(icon: Icons.crop_rounded, label: 'Crop', onTap: _crop),
                _Action(icon: Icons.auto_fix_high_rounded, label: 'Auto', onTap: () => _filter('Auto')),
                _Action(icon: Icons.tonality_rounded, label: 'Gray', onTap: () => _filter('Grayscale')),
                _Action(icon: Icons.contrast_rounded, label: 'B&W', onTap: () => _filter('B&W')),
                _Action(icon: Icons.add_a_photo_rounded, label: 'Add', onTap: _addPage),
                _Action(icon: Icons.delete_outline_rounded, label: 'Delete', onTap: pages.length == 1 ? null : () => setState(() { pages.removeAt(selected); selected = selected.clamp(0, pages.length - 1); })),
              ]),
            ),
          ]),
        ),
      ]),
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
        child: Column(children: [Icon(icon, color: onTap == null ? Colors.white24 : Colors.white), const SizedBox(height: 5), Text(label, style: TextStyle(fontSize: 11, color: onTap == null ? Colors.white24 : Colors.white))]),
      ),
    ),
  );
}
