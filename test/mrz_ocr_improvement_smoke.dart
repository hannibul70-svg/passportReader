import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:passport_reader_mobile/services/mrz_ocr_image.dart';
import 'package:passport_reader_mobile/services/mrz_ocr_quality.dart';
import 'package:passport_reader_mobile/services/mrz_parser.dart';

void main() {
  const parser = MrzParser();
  final first = 'P<UTOERIKSSON<<ANNA<MARIA'.padRight(44, '<');
  const second = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';
  final complete = parser.parse(
    'complete',
    mrzCandidateLines: [first, second],
    mrzOcrLines: [first, second],
  );
  final partial = parser.parse(
    'partial',
    mrzCandidateLines: [first.substring(0, 39), second],
    mrzOcrLines: [first.substring(0, 39), second],
  );
  final worse = parser.parse(
    'worse',
    mrzCandidateLines: [first.substring(0, 18), second.substring(0, 16)],
    mrzOcrLines: [first.substring(0, 18), second.substring(0, 16)],
  );
  if (shouldRetryMrzOcr(complete) ||
      !shouldRetryMrzOcr(partial) ||
      !identical(preferMrzOcrResult(partial, complete), complete) ||
      !identical(preferMrzOcrResult(partial, worse), partial) ||
      !identical(preferMrzOcrResult(complete, worse), complete) ||
      !identical(preferMrzOcrResult(partial, partial), partial)) {
    throw StateError('Retry gating or whole-result quality selection failed');
  }
  final wrongCheckSecond = '${second.substring(0, 43)}1';
  final wrongCheck = parser.parse(
    'wrong check',
    mrzCandidateLines: [first, wrongCheckSecond],
    mrzOcrLines: [first, wrongCheckSecond],
  );
  if (!shouldRetryMrzOcr(wrongCheck) ||
      !identical(preferMrzOcrResult(wrongCheck, complete), complete)) {
    throw StateError('Check-digit quality preference failed');
  }

  final page = image.Image(width: 800, height: 800, numChannels: 3);
  page.clear(image.ColorRgb8(200, 200, 200));
  page.setPixelRgb(0, 0, 255, 0, 0);
  for (var x = 100; x < 700; x++) {
    page.setPixelRgb(x, 650, 160, 160, 160);
    page.setPixelRgb(x, 710, 160, 160, 160);
  }
  final pageBytes = Uint8List.fromList(image.encodePng(page));
  final original = image.decodePng(
    prepareMrzOcrImage((pageBytes: pageBytes, enhance: false)),
  )!;
  final enhanced = image.decodePng(
    prepareMrzOcrImage((pageBytes: pageBytes, enhance: true)),
  )!;
  if (original.width != 824 ||
      original.height != 224 ||
      enhanced.width != 1432 ||
      enhanced.height != 376 ||
      original.getPixel(12, 12).r != 200 ||
      original.getPixel(12, 12).g != 200) {
    throw StateError('Crop, padding or bounded upscale failed');
  }
  final minInk = enhanced.fold<num>(
    255,
    (value, pixel) => pixel.r < value ? pixel.r : value,
  );
  if (minInk > 5) throw StateError('Low-contrast normalization failed');

  for (final name in ['ICAO_Example.png', 'honggildong.jpg']) {
    final sampleFile = File('Sample/$name');
    // 여권 이미지는 저장소에 포함하지 않는다. 로컬 샘플이 있을 때만 추가 검사한다.
    if (!sampleFile.existsSync()) {
      stdout.writeln('SKIP: optional local sample $name');
      continue;
    }
    final bytes = sampleFile.readAsBytesSync();
    for (final enhance in [false, true]) {
      final png = prepareMrzOcrImage((pageBytes: bytes, enhance: enhance));
      final result = image.decodePng(png)!;
      if (enhance && (result.width > 1432 || result.height > 536)) {
        throw StateError('Sample preprocessing exceeded bounds: $name');
      }
      stdout.writeln(
        'Sample preprocessing PASS: $name enhance=$enhance ${result.width}x${result.height}',
      );
    }
  }
  final large = image.Image(width: 3000, height: 1000, numChannels: 3);
  final largePng = prepareMrzOcrImage((
    pageBytes: Uint8List.fromList(image.encodePng(large)),
    enhance: true,
  ));
  final limited = image.decodePng(largePng)!;
  if (limited.width > 1432 || limited.height > 536) {
    throw StateError('Large MRZ output is not bounded');
  }
  stdout.writeln(
    'PASS: lossless MRZ-only preprocessing, contrast, size bounds, retry gating, regression-safe whole-result selection',
  );
}
