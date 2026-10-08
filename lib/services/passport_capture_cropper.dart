import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as image;

class PassportCaptureCropper {
  const PassportCaptureCropper();

  Future<String> crop(
    String imagePath,
    Rect normalizedRegion, {
    required double previewAspectRatio,
  }) async {
    final decoded = image.decodeImage(await File(imagePath).readAsBytes());
    if (decoded == null) {
      throw const FormatException('촬영 이미지를 읽을 수 없습니다.');
    }
    final source = image.bakeOrientation(decoded);
    // 미리보기와 촬영본의 비율이 다르면 가운데에 보이는 영역으로 좌표를 맞춘다.
    final sourceAspectRatio = source.width / source.height;
    final visibleWidth = sourceAspectRatio > previewAspectRatio
        ? source.height * previewAspectRatio
        : source.width.toDouble();
    final visibleHeight = sourceAspectRatio > previewAspectRatio
        ? source.height.toDouble()
        : source.width / previewAspectRatio;
    final visibleLeft = (source.width - visibleWidth) / 2;
    final visibleTop = (source.height - visibleHeight) / 2;
    final left = (visibleLeft + normalizedRegion.left * visibleWidth)
        .round()
        .clamp(0, source.width - 1);
    final top = (visibleTop + normalizedRegion.top * visibleHeight)
        .round()
        .clamp(0, source.height - 1);
    final width = (normalizedRegion.width * visibleWidth).round().clamp(
      1,
      source.width - left,
    );
    final height = (normalizedRegion.height * visibleHeight).round().clamp(
      1,
      source.height - top,
    );
    final cropped = image.copyCrop(
      source,
      x: left,
      y: top,
      width: width,
      height: height,
    );
    final outputPath = '$imagePath.page.jpg';
    await File(outputPath).writeAsBytes(image.encodeJpg(cropped, quality: 95));
    return outputPath;
  }
}
