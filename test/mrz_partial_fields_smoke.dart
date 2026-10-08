import 'dart:io';

import 'package:passport_reader_mobile/services/mrz_parser.dart';

void main() {
  const parser = MrzParser();
  final first = 'P<UTOERIKSSON<<ANNA<MARIA'.padRight(44, '<');
  const second = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';
  // 앞에서부터 읽힌 범위만 기대값으로 사용하고 모든 중간 종료 위치를 검사한다.
  String prefixField(String full, int length, int start, int end) =>
      length <= start ? '' : full.substring(start, end > length ? length : end);
  String clean(String value) => value.replaceAll('<', ' ').trim();

  for (var length = 0; length <= 44; length++) {
    final prefix = second.substring(0, length);
    final result = parser.parse(
      'diagnostic',
      mrzCandidateLines: [first, prefix],
      mrzOcrLines: [first, prefix],
    );
    final fields = [
      (result.passportNumber, clean(prefixField(second, length, 0, 9))),
      (result.nationality, clean(prefixField(second, length, 10, 13))),
      (result.dateOfBirth, prefixField(second, length, 13, 19)),
      (result.sex, clean(prefixField(second, length, 20, 21))),
      (result.expiryDate, prefixField(second, length, 21, 27)),
      (result.personalNumber, clean(prefixField(second, length, 28, 42))),
    ];
    if (fields.any((field) => field.$1 != field.$2) ||
        result.surname != 'ERIKSSON' ||
        result.rawText != 'diagnostic' ||
        (length < 44 && result.hasMrz)) {
      throw StateError('MRZ 2 prefix fields failed at length=$length');
    }
    final firstPrefix = first.substring(0, length);
    final firstResult = parser.parse(
      '',
      mrzCandidateLines: [firstPrefix, second],
      mrzOcrLines: [firstPrefix, second],
    );
    final names = prefixField(first, length, 5, 44).split('<<');
    if (firstResult.documentType != clean(prefixField(first, length, 0, 2)) ||
        firstResult.issuingCountry != clean(prefixField(first, length, 2, 5)) ||
        firstResult.surname != clean(names[0]) ||
        firstResult.givenNames != (names.length > 1 ? clean(names[1]) : '') ||
        firstResult.passportNumber != 'L898902C3' ||
        (length < 44 && firstResult.hasMrz)) {
      throw StateError('MRZ 1 prefix fields failed at length=$length');
    }
  }
  final partialDate = second.substring(0, 16);
  final result = parser.parse(
    '',
    mrzCandidateLines: ['', partialDate],
    mrzOcrLines: ['', partialDate],
  );
  if (result.dateOfBirth != '740' ||
      result.expiryDate != '' ||
      result.birthDateCheckPassed ||
      result.hasMrz) {
    throw StateError('Partial date was hidden, padded, or verified');
  }
  stdout.writeln(
    'PASS: every MRZ1/MRZ2 prefix length 0..44, partial fields, missing suffixes, unchanged validation',
  );
}
