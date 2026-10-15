import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../models/ocr_result.dart';

class OcrService {
  Future<OcrResult> recognize(String path) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('OCR requires Android or iOS.');
    }
    final image = img.decodeImage(await File(path).readAsBytes());
    if (image == null) throw StateError('Could not decode the page for OCR.');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return OcrResult(
        text: result.text,
        width: image.width,
        height: image.height,
        words: [
          for (final block in result.blocks)
            for (final line in block.lines)
              for (final word in line.elements)
                OcrWord(word.text, word.boundingBox),
        ],
      );
    } finally {
      await recognizer.close();
    }
  }
}
