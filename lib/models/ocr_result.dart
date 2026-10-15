import 'dart:ui';

class OcrWord {
  final String text;
  final Rect bounds;
  const OcrWord(this.text, this.bounds);
}

class OcrResult {
  final String text;
  final int width;
  final int height;
  final List<OcrWord> words;
  const OcrResult({
    required this.text,
    required this.width,
    required this.height,
    required this.words,
  });
}
