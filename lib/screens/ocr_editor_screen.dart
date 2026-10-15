import 'package:flutter/material.dart';

import '../models/ocr_result.dart';

class OcrEditorScreen extends StatefulWidget {
  final OcrResult result;
  const OcrEditorScreen({super.key, required this.result});
  @override
  State<OcrEditorScreen> createState() => _OcrEditorScreenState();
}

class _OcrEditorScreenState extends State<OcrEditorScreen> {
  late List<String> corrected;
  @override
  void initState() {
    super.initState();
    corrected = widget.result.words.map((w) => w.text).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Correct recognized text'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, widget.result.correctWords(corrected)),
          child: const Text('Apply'),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Corrections change searchable text in the PDF. The scanned image stays visible. Use Annotate to add visible text.',
          ),
        ),
        Expanded(
          child: corrected.isEmpty
              ? const Center(
                  child: Text(
                    'No words found. Try a clearer scan or add visible text with Annotate.',
                  ),
                )
              : ListView.builder(
                  itemCount: corrected.length,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: TextFormField(
                      initialValue: corrected[index],
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: 'Word ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => corrected[index] = value,
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}
