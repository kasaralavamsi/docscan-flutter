import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_page.dart';
import '../models/scanned_document.dart';
import '../services/document_store.dart';
import '../services/import_service.dart';
import '../services/scanner_service.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scanner = ScannerService();
  final _store = DocumentStore();
  final _importer = ImportService();
  List<ScannedDocument> _documents = [];
  bool _busy = true;
  String? _loadError;
  String query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final documents = await _store.load();
      if (mounted) {
        setState(() {
          _documents = documents;
          _loadError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = 'Could not open saved scans: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(ScannedDocument document) async {
    await Navigator.push<List<ScanPage>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          initialPages: List.of(document.pages),
          onSave: (pages) async {
            final saved = await _store.save(
              ScannedDocument(
                id: document.id,
                name: document.name,
                createdAt: document.createdAt,
                pages: pages,
              ),
            );
            if (mounted) {
              setState(() {
                _documents.removeWhere((d) => d.id == saved.id);
                _documents.insert(0, saved);
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> _capture() => _run(() async {
    final pages = await _scanner.scan();
    if (!mounted || pages.isEmpty) return;
    await _edit(
      ScannedDocument(
        id: const Uuid().v4(),
        name:
            'Scan ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}',
        createdAt: DateTime.now(),
        pages: pages,
      ),
    );
  });
  Future<void> _import() => _run(() async {
    final result = await _importer.pickPdf();
    if (!mounted || result == null) return;
    await _edit(
      ScannedDocument(
        id: const Uuid().v4(),
        name: result.name,
        createdAt: DateTime.now(),
        pages: result.pages,
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final visible = _documents
        .where(
          (d) =>
              d.name.toLowerCase().contains(query) ||
              d.pages.any(
                (p) =>
                    (p.ocr?.text.toLowerCase().contains(query) ?? false) ||
                    p.annotations.any(
                      (a) => a.text.toLowerCase().contains(query),
                    ),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DocScan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Import PDF',
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_open_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan, edit and sign',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open a saved scan or import a PDF to crop, annotate and correct text.',
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search saved names and recognized text',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setState(() => query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(),
              if (_loadError != null) ...[
                Text(
                  _loadError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _load,
                  child: const Text('Retry opening saved scans'),
                ),
              ],
              Expanded(
                child: visible.isEmpty
                    ? const Center(
                        child: Text(
                          'No matching scans. Scan a page or import a PDF.',
                        ),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final document = visible[index];
                          return Card(
                            child: ListTile(
                              leading: Image.file(
                                File(document.pages.first.path),
                                width: 50,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image),
                              ),
                              title: Text(document.name),
                              subtitle: Text(
                                '${document.pages.length} pages • Saved on device',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _busy
                                  ? null
                                  : () => _run(() => _edit(document)),
                            ),
                          );
                        },
                      ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Import PDF'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _capture,
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Scan'),
      ),
    );
  }
}
