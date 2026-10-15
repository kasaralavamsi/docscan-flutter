import 'dart:ui';

class OcrWord {
  final String text;
  final Rect bounds;
  const OcrWord(this.text, this.bounds);
  Map<String, dynamic> toJson() => {
    'text': text,
    'bounds': [bounds.left, bounds.top, bounds.width, bounds.height],
  };
  factory OcrWord.fromJson(Map<String, dynamic> json) {
    final b = (json['bounds'] as List).cast<num>();
    return OcrWord(
      json['text'] as String,
      Rect.fromLTWH(
        b[0].toDouble(),
        b[1].toDouble(),
        b[2].toDouble(),
        b[3].toDouble(),
      ),
    );
  }
}

class OcrResult {
  final String text;
  final int width;
  final int height;
  final List<OcrWord> words;
  OcrResult correctWords(List<String> corrected) {
    if (corrected.length != words.length) {
      throw ArgumentError('Word count must match.');
    }
    final updated = [
      for (var i = 0; i < words.length; i++)
        OcrWord(corrected[i].trim(), words[i].bounds),
    ];
    return OcrResult(
      text: updated.map((w) => w.text).where((t) => t.isNotEmpty).join(' '),
      width: width,
      height: height,
      words: updated,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'width': width,
    'height': height,
    'words': words.map((w) => w.toJson()).toList(),
  };
  factory OcrResult.fromJson(Map<String, dynamic> json) => OcrResult(
    text: json['text'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
    words: [
      for (final w in json['words'] as List)
        OcrWord.fromJson(w as Map<String, dynamic>),
    ],
  );
  const OcrResult({
    required this.text,
    required this.width,
    required this.height,
    required this.words,
  });
}
