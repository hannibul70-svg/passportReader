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
}
