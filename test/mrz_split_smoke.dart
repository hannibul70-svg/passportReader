import 'dart:io';

import 'package:passport_reader_mobile/services/mrz_parser.dart';

void main() {
  const parser = MrzParser();
  const first = 'PMKORBAEK<<JAEWOO<<<<<';
  const tail = '<<<<<<<<<<<<<<<<<<<<<<';
  const second = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';
  final noisyLines = [
    ' $first !@#.',
    '\t$tail :;/>',
    '${second.substring(0, 20)} \t|_${second.substring(20)}?',
  ];
  final noisyRaw = noisyLines.join('\r\n');
  for (final explicitCandidates in [false, true]) {
    final cleaned = parser.parse(
      noisyRaw,
      mrzCandidateLines: explicitCandidates ? noisyLines : null,
    );
    if (!cleaned.hasMrz ||
        cleaned.rawText != noisyRaw ||
        MrzParser.normalizeOcrText(cleaned.mrzLines.join('\n')) !=
            '$first$tail\n$second' ||
        cleaned.givenNames != 'JAEWOO') {
      throw StateError('Noisy split MRZ failed: $explicitCandidates');
    }
  }
  if (MrzParser.normalizeOcrText(noisyRaw) != '$first\n$tail\n$second' ||
      MrzParser.normalizeOcrText(' !?\r\n\t<> ') != '<' ||
      MrzParser.normalizeLine('p<kor 0123!') != 'P<KOR0123') {
    throw StateError('MRZ allowed character filter failed');
  }
  for (final explicitCandidates in [false, true]) {
    const rawText = '$first\n$tail\n$second';
    final result = parser.parse(
      rawText,
      mrzCandidateLines: explicitCandidates ? [first, tail, second] : null,
    );
    if (!result.hasMrz ||
        result.mrzLines.first != '$first$tail' ||
        result.mrzLines.last != second ||
        result.rawText != rawText ||
        result.surname != 'BAEK' ||
        result.givenNames != 'JAEWOO' ||
        result.personalNumber != 'ZE184226B') {
      throw StateError(
        'Split MRZ 1 failed: explicitCandidates=$explicitCandidates',
      );
    }
  }
  const incompleteFirst = 'PMKORBAEK<<JAEWOO';
  const incompleteRawText = '$incompleteFirst\n$tail\n$second';
  final incomplete = parser.parse(incompleteRawText);
  if (incomplete.hasMrz ||
      incomplete.rawText != incompleteRawText ||
      incomplete.mrzLines.single != second) {
    throw StateError('Incomplete MRZ raw text was lost or padded');
  }
  final missingFiller = second.replaceAll('<', ' ');
  final missingFillerResult = parser.parse(missingFiller);
  if (missingFillerResult.rawText != missingFiller) {
    throw StateError('OCR spaces were replaced with invented fillers');
  }
  final invalid = parser.parse('THIS IS AN ORDINARY SENTENCE\n$second');
  if (invalid.hasMrz) {
    throw StateError('Ordinary text was accepted as MRZ 1');
  }
  stdout.writeln(
    'PASS: noisy split MRZ, allowed character filter, raw preservation, personal field cleanup, incomplete MRZ, ordinary text rejection',
  );
}
