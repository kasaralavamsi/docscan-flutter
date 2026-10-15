import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_page.dart';
import '../services/scanner_service.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scanner = ScannerService();
  final List<List<ScanPage>> _recent = [];
  bool _capturing = false;

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      final pages = await _scanner.scan();
      if (!mounted || pages.isEmpty) return;
      final result = await Navigator.push<List<ScanPage>>(
        context,
        MaterialPageRoute(builder: (_) => EditorScreen(initialPages: pages)),
      );
      if (mounted && result != null && result.isNotEmpty) {
        setState(() => _recent.insert(0, result));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not scan: $error')));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DocScan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Turn paper into PDF',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Auto-capture, edit and export searchable PDFs.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.document_scanner_rounded,
                      size: 52,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Recent scans',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _recent.isEmpty
                    ? const Center(
                        child: Text(
                          'No scans yet. Tap Scan to create your first document.',
                        ),
                      )
                    : ListView.separated(
                        itemCount: _recent.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final pages = _recent[i];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(10),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(pages.first.path),
                                  width: 58,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(
                                'Scan ${_recent.length - i}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${pages.length} page${pages.length == 1 ? '' : 's'}',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                final result =
                                    await Navigator.push<List<ScanPage>>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditorScreen(
                                          initialPages: List.of(pages),
                                        ),
                                      ),
                                    );
                                if (mounted && result != null) {
                                  setState(() => _recent[i] = result);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _capturing ? null : _capture,
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Scan'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Scans',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: 'Files',
          ),
        ],
      ),
    );
  }
}
