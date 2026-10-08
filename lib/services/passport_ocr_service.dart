import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/passport_result.dart';
import 'mrz_parser.dart';
import 'mrz_line_assembler.dart';
import 'mrz_ocr_image.dart';
import 'mrz_ocr_quality.dart';
import 'mrz_first_line_ocr.dart';

typedef _MrzOcrScan = ({
  PassportResult result,
  List<MrzOcrFragment> fragments,
  Uint8List pngBytes,
});

class PassportOcrService {
  PassportOcrService({MrzParser? mrzParser})
    : _mrzParser = mrzParser ?? const MrzParser();

  final MrzParser _mrzParser;
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<PassportResult> recognize(String imagePath) async {
    // 기존 가이드 내부 사진과 하단 25% OCR 범위는 유지한다.
    final pageBytes = await File(imagePath).readAsBytes();
    final mrzImagePath = '$imagePath.mrz.png';
    final firstLineImagePath = '$imagePath.mrz1.png';
    try {
      final originalPng = await compute(prepareMrzOcrImage, (
        pageBytes: pageBytes,
        enhance: false,
      ));
      final original = await _recognizePrepared(mrzImagePath, originalPng);
      var selected = original;
      if (shouldRetryMrzOcr(original.result)) {
        try {
          final enhancedPng = await compute(prepareMrzOcrImage, (
            pageBytes: pageBytes,
            enhance: true,
          ));
          final retry = await _recognizePrepared(mrzImagePath, enhancedPng);
          if (identical(
            preferMrzOcrResult(original.result, retry.result),
            retry.result,
          )) {
            selected = retry;
          }
        } on Exception catch (error) {
          debugPrint('MRZ 보정 재시도 실패 (${error.runtimeType}), 최초 결과 유지');
        }
      }
      // MRZ 2의 검사 숫자가 정상이어도 MRZ 1 성명은 별도로 재인식한다.
      return await _improveFirstLine(selected, firstLineImagePath);
    } finally {
      for (final path in [mrzImagePath, firstLineImagePath]) {
        if (await File(path).exists()) await File(path).delete();
      }
    }
  }

  Future<_MrzOcrScan> _recognizePrepared(
    String mrzImagePath,
    Uint8List pngBytes,
  ) async {
    await File(mrzImagePath).writeAsBytes(pngBytes);
    final recognizedText = await _textRecognizer.processImage(
      InputImage.fromFilePath(mrzImagePath),
    );
    final fragments = _fragments(recognizedText);
    final mrzLines = const MrzLineAssembler().assemble(fragments);
    final result = _mrzParser.parse(
      recognizedText.text,
      mrzCandidateLines: mrzLines,
      mrzOcrLines: mrzLines,
    );
    return (result: result, fragments: fragments, pngBytes: pngBytes);
  }

  List<MrzOcrFragment> _fragments(RecognizedText recognizedText) =>
      recognizedText.blocks.expand((block) => block.lines).map((line) {
        final box = line.boundingBox;
        final points = line.cornerPoints;
        final hasCorners = points.length == 4;
        final edgeWidth = hasCorners ? points[1].x - points[0].x : 0;
        return MrzOcrFragment(
          text: line.text,
          confidence: line.confidence,
          centerX: box.center.dx,
          centerY: box.center.dy,
          width: box.width,
          height: hasCorners
              ? (points[3].y - points[0].y).abs().toDouble()
              : box.height,
          slope: edgeWidth == 0 ? 0 : (points[1].y - points[0].y) / edgeWidth,
        );
      }).toList();

  Future<PassportResult> _improveFirstLine(
    _MrzOcrScan scan,
    String imagePath,
  ) async {
    const assembler = MrzLineAssembler();
    final rows = assembler.groupRows(scan.fragments);
    if (rows.isEmpty) return scan.result;
    final firstRow = rows.length >= 2 ? rows[rows.length - 2] : rows.single;
    final physical = scan.result.mrzOcrLines;
    if (physical.length != 2 || (rows.length == 1 && physical[0].isEmpty)) {
      return scan.result;
    }
    var firstLine = physical[0];
    var confidence = mrzFirstLineConfidence(firstRow);
    String? selectedRawText;
    for (final enhance in [false, true]) {
      try {
        final png = await compute(prepareMrzFirstLineImage, (
          pngBytes: scan.pngBytes,
          row: firstRow,
          enhance: enhance,
        ));
        await File(imagePath).writeAsBytes(png);
        final recognized = await _textRecognizer.processImage(
          InputImage.fromFilePath(imagePath),
        );
        final candidateRows = assembler.groupRows(_fragments(recognized));
        if (candidateRows.isEmpty) continue;
        final candidateRow = candidateRows.reduce(
          (a, b) =>
              a.fold<double>(0, (sum, part) => sum + part.width) >=
                  b.fold<double>(0, (sum, part) => sum + part.width)
              ? a
              : b,
        );
        final candidate = candidateRow
            .map((part) => MrzParser.normalizeLine(part.text))
            .join();
        final candidateConfidence = mrzFirstLineConfidence(candidateRow);
        if (preferMrzFirstLine(
          original: firstLine,
          candidate: candidate,
          originalConfidence: confidence,
          candidateConfidence: candidateConfidence,
        )) {
          firstLine = candidate;
          confidence = candidateConfidence;
          selectedRawText = recognized.text;
        }
      } on Exception catch (error) {
        debugPrint('MRZ 1 전용 재인식 실패 (${error.runtimeType}), 기존 행 유지');
      }
    }
    if (firstLine == physical[0]) return scan.result;
    final lines = [firstLine, physical[1]];
    return _mrzParser.parse(
      '${scan.result.rawText}\n[MRZ1 전용 재인식 원문]\n$selectedRawText',
      mrzCandidateLines: lines,
      mrzOcrLines: lines,
    );
  }

  Future<void> dispose() => _textRecognizer.close();
}
