import 'dart:io';

import 'package:image/image.dart' as image;

class PassportPhotoExtractor {
  const PassportPhotoExtractor();

  static const _left = 0.08;
  static const _top = 0.12;
  static const _width = 0.30;
  static const _height = 0.60;

  Future<String?> extract(String imagePath) async {
    final sourceBytes = await File(imagePath).readAsBytes();
    final decoded = image.decodeImage(sourceBytes);
    if (decoded == null) {
      return null;
    }
    final source = image.bakeOrientation(decoded);

    final facePhoto = image.copyCrop(
      source,
      x: (source.width * _left).round(),
      y: (source.height * _top).round(),
      width: (source.width * _width).round(),
      height: (source.height * _height).round(),
    );
    final facePhotoPath = '$imagePath.face.jpg';
    await File(facePhotoPath).writeAsBytes(image.encodeJpg(facePhoto));
    return facePhotoPath;
  }
}
