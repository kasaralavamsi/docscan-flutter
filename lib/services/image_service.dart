import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  Future<String?> crop(String path) async {
    final result = await ImageCropper().cropImage(
      sourcePath: path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust document',
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(title: 'Adjust document'),
      ],
    );
    return result?.path;
  }

  Future<String> rotate(String path) async {
    final source = img.decodeImage(await File(path).readAsBytes());
    if (source == null) throw StateError('Could not decode image.');
    final rotated = img.copyRotate(img.bakeOrientation(source), angle: 90);
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/rotated_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await out.writeAsBytes(img.encodePng(rotated));
    return out.path;
  }

  Future<String> applyFilter(String path, String filter) async {
    final bytes = await File(path).readAsBytes();
    var source = img.decodeImage(bytes);
    if (source == null) throw Exception('Could not decode image');

    switch (filter) {
      case 'Grayscale':
        source = img.grayscale(source);
        break;
      case 'B&W':
        source = img.grayscale(source);
        source = img.adjustColor(source, contrast: 1.65);
        source = img.luminanceThreshold(source, threshold: 0.56);
        break;
      case 'Auto':
        source = img.adjustColor(source, contrast: 1.18, saturation: 0.92);
        break;
      default:
        break;
    }

    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/scan_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(img.encodeJpg(source, quality: 92));
    return out.path;
  }
}
