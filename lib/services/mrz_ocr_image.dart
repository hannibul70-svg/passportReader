import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

typedef MrzOcrImageRequest = ({Uint8List pageBytes, bool enhance});

// UI isolate 밖에서 호출한다. 확대/명암 보정은 MRZ crop에만 적용한다.
Uint8List prepareMrzOcrImage(MrzOcrImageRequest request) {
  final decoded = image.decodeImage(request.pageBytes);
  if (decoded == null) {
    throw const FormatException('MRZ 이미지를 읽을 수 없습니다.');
  }
  final page = image.bakeOrientation(decoded);
  const mrzTopFraction = 0.75;
  final top = (page.height * mrzTopFraction).floor();
  var mrz = image
      .copyCrop(
        page,
        x: 0,
        y: top,
        width: page.width,
        height: page.height - top,
      )
      .convert(numChannels: 3);

  if (request.enhance) {
    const maxScale = 2.0;
    const maxWidth = 1408;
    const maxHeight = 512;
    final scale = math.min(
      maxScale,
      math.min(maxWidth / mrz.width, maxHeight / mrz.height),
    );
    mrz = image.copyResize(
      mrz,
      width: math.max(1, (mrz.width * scale).round()),
      height: math.max(1, (mrz.height * scale).round()),
      interpolation: image.Interpolation.cubic,
    );
    mrz = image.grayscale(mrz);
    mrz = image.normalize(mrz, min: 0, max: 255);
    // 얇은 '<' 획을 지울 수 있는 강제 이진화/침식은 적용하지 않는다.
  }

  const padding = 12;
  final padded = image.copyExpandCanvas(
    mrz,
    padding: padding,
    backgroundColor: image.ColorRgb8(255, 255, 255),
  );
  return Uint8List.fromList(image.encodePng(padded));
}
