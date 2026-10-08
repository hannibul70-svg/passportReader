import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'mrz_line_assembler.dart';
import 'mrz_parser.dart';

typedef MrzFirstLineImageRequest = ({
  Uint8List pngBytes,
  List<MrzOcrFragment> row,
  bool enhance,
});

Uint8List prepareMrzFirstLineImage(MrzFirstLineImageRequest request) {
  final source = image.decodePng(request.pngBytes);
  if (source == null || request.row.isEmpty) {
    throw const FormatException('MRZ 1 행 이미지를 읽을 수 없습니다.');
  }
  final widest = request.row.reduce((a, b) => a.width >= b.width ? a : b);
  const maxDeskewDegrees = 15.0;
  final radians = math.atan(widest.slope);
  final degrees = radians * 180 / math.pi;
  if (degrees.abs() > maxDeskewDegrees) {
    throw const FormatException('MRZ 1 행의 기울기가 보정 범위를 초과했습니다.');
  }
  source.backgroundColor = image.ColorRgb8(255, 255, 255);
  final straight = image.copyRotate(
    source,
    angle: -degrees,
    interpolation: image.Interpolation.cubic,
  );
  final centerY =
      request.row
          .map(
            (part) =>
                part.centerY - widest.slope * (part.centerX - source.width / 2),
          )
          .reduce((a, b) => a + b) /
      request.row.length;
  final rotatedY =
      (centerY - source.height / 2) * math.cos(radians) + straight.height / 2;
  final heights = request.row.map((part) => part.height).toList()..sort();
  const lineMarginFactor = 1.8;
  final cropHeight = (heights[heights.length ~/ 2] * lineMarginFactor)
      .ceil()
      .clamp(1, straight.height);
  final top = (rotatedY - cropHeight / 2).floor().clamp(
    0,
    straight.height - cropHeight,
  );
  var rowImage = image
      .copyCrop(
        straight,
        x: 0,
        y: top,
        width: straight.width,
        height: cropHeight,
      )
      .convert(numChannels: 3);
  const maxScale = 2.0;
  const maxWidth = 1600;
  const maxHeight = 160;
  final scale = math.min(
    maxScale,
    math.min(maxWidth / rowImage.width, maxHeight / rowImage.height),
  );
  rowImage = image.copyResize(
    rowImage,
    width: math.max(1, (rowImage.width * scale).round()),
    height: math.max(1, (rowImage.height * scale).round()),
    interpolation: image.Interpolation.cubic,
  );
  if (request.enhance) {
    rowImage = image.normalize(image.grayscale(rowImage), min: 0, max: 255);
  }
  const padding = 16;
  return Uint8List.fromList(
    image.encodePng(
      image.copyExpandCanvas(
        rowImage,
        padding: padding,
        backgroundColor: image.ColorRgb8(255, 255, 255),
      ),
    ),
  );
}

double? mrzFirstLineConfidence(List<MrzOcrFragment> row) {
  var weighted = 0.0;
  var weight = 0;
  for (final part in row) {
    // 채움 문자보다 문서 코드와 이름의 OCR 신뢰도를 우선한다.
    final letters = MrzParser.normalizeLine(
      part.text,
    ).replaceAll('<', '').length;
    if (letters == 0 || part.confidence == null) continue;
    weighted += part.confidence! * letters;
    weight += letters;
  }
  return weight == 0 ? null : weighted / weight;
}

bool preferMrzFirstLine({
  required String original,
  required String candidate,
  double? originalConfidence,
  double? candidateConfidence,
}) {
  final originalScore = _firstLineQuality(original);
  final candidateScore = _firstLineQuality(candidate);
  if (candidateScore != originalScore) return candidateScore > originalScore;
  // 같은 형식의 다른 이름은 신뢰도가 명확히 높을 때만 후보 전체를 선택한다.
  const confidenceMargin = 0.08;
  return originalConfidence != null &&
      candidateConfidence != null &&
      candidateConfidence >= originalConfidence + confidenceMargin;
}

int _firstLineQuality(String line) {
  line = MrzParser.normalizeLine(line);
  if (line.isEmpty) return 0;
  const td3Length = 44;
  const prefixScore = 200;
  const nameSeparatorScore = 100;
  const completeShapeScore = 1000;
  const validNameShapeScore = 300;
  const invalidCharacterPenalty = 30;
  var score = td3Length - (line.length - td3Length).abs().clamp(0, td3Length);
  if (RegExp(r'^P[A-Z<][A-Z]{3}').hasMatch(line)) score += prefixScore;
  if (line.length > 5 && line.substring(5).contains('<<')) {
    score += nameSeparatorScore;
  }
  final validNameShape = RegExp(
    r'^P[A-Z<][A-Z]{3}[A-Z]+(?:<[A-Z]+)*<<[A-Z]*(?:<[A-Z]+)*<*$',
  ).hasMatch(line);
  if (validNameShape) score += validNameShapeScore;
  if (validNameShape && line.length == td3Length) score += completeShapeScore;
  score -= RegExp(r'[0-9]').allMatches(line).length * invalidCharacterPenalty;
  if (line.length > td3Length) score -= completeShapeScore;
  return score;
}
