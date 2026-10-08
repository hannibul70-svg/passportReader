import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:passport_reader_mobile/services/mrz_first_line_ocr.dart';
import 'package:passport_reader_mobile/services/mrz_line_assembler.dart';
import 'package:passport_reader_mobile/services/mrz_parser.dart';

void main() {
  final correct = 'P<UTOERIKSSON<<ANNA<MARIA'.padRight(44, '<');
  final numericError = correct.replaceFirst('ERIKSSON', 'ER1KSS0N');
  final letterError = correct.replaceFirst('ERIKSSON', 'ERIKSSQN');
  final fillerError = '${correct.substring(0, 41)}K<<';
  if (!preferMrzFirstLine(original: numericError, candidate: correct) ||
      preferMrzFirstLine(original: correct, candidate: numericError) ||
      preferMrzFirstLine(original: correct, candidate: fillerError) ||
      preferMrzFirstLine(
        original: correct,
        candidate: letterError,
        originalConfidence: 0.85,
        candidateConfidence: 0.86,
      ) ||
      !preferMrzFirstLine(
        original: letterError,
        candidate: correct,
        originalConfidence: 0.70,
        candidateConfidence: 0.90,
      ) ||
      preferMrzFirstLine(original: correct, candidate: letterError)) {
    throw StateError('First-line-only quality/confidence selection failed');
  }
  const second = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';
  final before = const MrzParser().parse(
    '',
    mrzCandidateLines: [numericError, second],
    mrzOcrLines: [numericError, second],
  );
  final after = const MrzParser().parse(
    '',
    mrzCandidateLines: [correct, second],
    mrzOcrLines: [correct, second],
  );
  if (before.mrzOcrLines[1] != after.mrzOcrLines[1] ||
      before.passportNumber != after.passportNumber ||
      before.nationality != after.nationality ||
      before.dateOfBirth != after.dateOfBirth ||
      before.expiryDate != after.expiryDate ||
      before.personalNumber != after.personalNumber) {
    throw StateError('MRZ2 fields changed while replacing MRZ1');
  }

  for (final slope in [0.0, 0.08, -0.08]) {
    final input = image.Image(width: 600, height: 140, numChannels: 3);
    input.clear(image.ColorRgb8(255, 255, 255));
    for (var x = 30; x < 570; x++) {
      final firstY = (40 + slope * (x - 300)).round();
      final secondY = (90 + slope * (x - 300)).round();
      for (var offset = -4; offset <= 4; offset++) {
        input.setPixelRgb(x, firstY + offset, 40, 40, 40);
        input.setPixelRgb(x, secondY + offset, 255, 0, 0);
      }
    }
    final row = [
      MrzOcrFragment(
        text: correct.substring(0, 20),
        centerX: 130,
        centerY: 40 + slope * (130 - 300),
        width: 200,
        height: 10,
        slope: slope,
        confidence: 0.8,
      ),
      MrzOcrFragment(
        text: correct.substring(20),
        centerX: 400,
        centerY: 40 + slope * (400 - 300),
        width: 340,
        height: 10,
        slope: slope,
        confidence: 0.9,
      ),
    ];
    for (final enhance in [false, true]) {
      final png = prepareMrzFirstLineImage((
        pngBytes: Uint8List.fromList(image.encodePng(input)),
        row: row,
        enhance: enhance,
      ));
      final output = image.decodePng(png)!;
      if (output.width > 1632 ||
          output.height > 192 ||
          output.any((pixel) => pixel.r > pixel.g + 40)) {
        throw StateError('MRZ1 crop includes MRZ2 or exceeds bounds: $slope');
      }
      final black = output.where((pixel) => pixel.r < 100).toList();
      if (black.isEmpty) throw StateError('MRZ1 text was lost');
      final ys = black.map((pixel) => pixel.y).toList()..sort();
      if (ys.last - ys.first > 22) {
        throw StateError('MRZ1 was not deskewed: $slope');
      }
    }
    final confidence = mrzFirstLineConfidence(row);
    if (confidence == null || confidence < 0.8 || confidence > 0.9) {
      throw StateError('Name-weighted OCR confidence failed');
    }
  }
  stdout.writeln(
    'PASS: MRZ1-only deskew/crop, MRZ2 exclusion and field preservation, bounded images, cautious shape/confidence selection',
  );
}
