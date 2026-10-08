import 'package:flutter_test/flutter_test.dart';
import 'package:passport_reader_mobile/services/mrz_parser.dart';

void main() {
  const parser = MrzParser();

  test('ICAO TD3 예제에서 인적사항과 체크디지트를 읽는다', () {
    const rawMrz = '''P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<
L898902C36UTO7408122F1204159ZE184226B<<<<<10''';

    final result = parser.parse(rawMrz);

    expect(result.hasMrz, isTrue);
    expect(result.documentType, 'P');
    expect(result.issuingCountry, 'UTO');
    expect(result.surname, 'ERIKSSON');
    expect(result.givenNames, 'ANNA MARIA');
    expect(result.passportNumber, 'L898902C3');
    expect(result.nationality, 'UTO');
    expect(result.dateOfBirth, '740812');
    expect(result.expiryDate, '120415');
    expect(result.hasValidChecks, isTrue);
  });

  test('MRZ 두 줄이 없으면 인식 실패 상태를 반환한다', () {
    final result = parser.parse('여권을 다시 촬영해 주세요.');

    expect(result.hasMrz, isFalse);
    expect(result.hasValidChecks, isFalse);
  });

  test('< 기호를 공백으로 바꾸고 양끝 공백을 제거한다', () {
    final firstLine = 'P<UTO<DOE<<JANE<ANN'.padRight(44, '<');
    const secondLine = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

    final result = parser.parse('$firstLine\n$secondLine');

    expect(result.documentType, 'P');
    expect(result.surname, 'DOE');
    expect(result.givenNames, 'JANE ANN');
  });

  test('긴 일반 문장을 MRZ 1행으로 선택하지 않는다', () {
    const unrelatedText = 'THISISNOTAPASSPORTMRZLINEANDMUSTNOTBESELECTEDX';
    final firstMrzLine = 'PMKORBAEK<<JAEWOO'.padRight(44, '<');
    const secondMrzLine = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

    final result = parser.parse(
      '$firstMrzLine\n$unrelatedText\n$secondMrzLine',
    );

    expect(result.hasMrz, isTrue);
    expect(result.mrzLines.first, firstMrzLine);
    expect(result.surname, 'BAEK');
    expect(result.givenNames, 'JAEWOO');
  });

  test('하단 OCR 후보의 일반 문장을 MRZ 1행으로 되돌리지 않는다', () {
    const unrelatedText = 'THISISNOTAPASSPORTMRZLINEANDMUSTNOTBESELECTEDX';
    const secondMrzLine = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

    final result = parser.parse(
      '$unrelatedText\n$secondMrzLine',
      mrzCandidateLines: [unrelatedText, secondMrzLine],
    );

    expect(result.hasMrz, isFalse);
    expect(result.hasPartialMrz, isTrue);
    expect(result.mrzLines, [secondMrzLine]);
    expect(result.surname, isNull);
  });

  test('MRZ 2행만 인식되면 부분 MRZ로 반환한다', () {
    const secondMrzLine = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

    final result = parser.parse(secondMrzLine);

    expect(result.hasMrz, isFalse);
    expect(result.hasPartialMrz, isTrue);
    expect(result.mrzLines, [secondMrzLine]);
  });

  test('MRZ 2행에 문자 하나가 틀려도 부분 MRZ로 반환한다', () {
    const imperfectSecondMrzLine =
        'L898902C36UTOO408122F1204159ZE184226B<<<<<10';

    final result = parser.parse(imperfectSecondMrzLine);

    expect(result.hasMrz, isFalse);
    expect(result.hasPartialMrz, isTrue);
    expect(result.mrzLines, [imperfectSecondMrzLine]);
  });

  test('전체 OCR의 일반 문장 대신 하단 MRZ 후보만 사용한다', () {
    const firstMrzLine = 'PMKORBAEK<<JAEWOO<<<<<<<<<<<<<<<<<<<<<<<<<<<';
    const secondMrzLine = 'M91906698KOR8801018M30122138577743V27840922';
    const unrelatedText = 'THISISNOTAPASSPORTMRZLINEANDMUSTNOTBESELECTEDX';

    final result = parser.parse(
      '$unrelatedText\n$firstMrzLine\n$secondMrzLine',
      mrzCandidateLines: [firstMrzLine, secondMrzLine],
    );

    expect(result.mrzLines, [firstMrzLine, secondMrzLine]);
    expect(result.surname, 'BAEK');
    expect(result.givenNames, 'JAEWOO');
  });

  test('MRZ 두 행 사이에 일반 OCR 줄이 있어도 TD3 쌍을 찾는다', () {
    const firstMrzLine = 'PMKORBAEK<<JAEWOO<<<<<<<<<<<<<<<<<<<<<<<<<<<';
    const secondMrzLine = 'M91906698KOR8801018M30122138577743V27840922';

    final result = parser.parse(
      'full OCR text',
      mrzCandidateLines: [
        firstMrzLine,
        'F FOREIGN AFFAIRS',
        '05 NOV 2035',
        '<<<<<<<<<<<<<<<<<<<<',
        secondMrzLine,
      ],
    );

    expect(result.hasMrz, isTrue);
    expect(result.mrzLines, [firstMrzLine, secondMrzLine]);
  });

  test('44자보다 짧은 MRZ 1행은 완전 MRZ로 사용하지 않는다', () {
    const incompleteFirstMrzLine = 'PMKORBAEK<<JAEWOO<<<<<';
    const secondMrzLine = 'M91906698KOR8801018M30122138577743V27840922';

    final result = parser.parse(
      'full OCR text',
      mrzCandidateLines: [incompleteFirstMrzLine, secondMrzLine],
    );

    expect(result.hasMrz, isFalse);
    expect(result.mrzLines, [secondMrzLine]);
  });

  test('MRZ OCR에는 OCR 원문 줄을 가공하지 않고 보존한다', () {
    const firstMrzLine = 'P<UTO ERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
    const secondMrzLine = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

    final result = parser.parse(
      'full OCR text',
      mrzCandidateLines: [firstMrzLine, secondMrzLine],
    );

    expect(result.hasMrz, isTrue);
    expect(result.mrzLines, [firstMrzLine, secondMrzLine]);
    expect(result.surname, 'ERIKSSON');
    expect(result.givenNames, 'ANNA MARIA');
  });

  test('두 OCR 조각으로 분리된 MRZ 1행을 원문 그대로 결합한다', () {
    const firstFragment = 'PMKORBAEK<<JAEWOO<<<<<';
    const secondFragment = '<<<<<<<<<<<<<<<<<<<<<<';
    const secondMrzLine = 'M91906698KOR8801018M30122138577743V27840922';

    final result = parser.parse(
      'full OCR text',
      mrzCandidateLines: [firstFragment, secondFragment, secondMrzLine],
    );

    expect(result.hasMrz, isTrue);
    expect(result.mrzLines.first, '$firstFragment$secondFragment');
    expect(result.surname, 'BAEK');
  });
}
