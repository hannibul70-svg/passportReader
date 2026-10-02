import '../models/passport_result.dart';

class MrzParser {
  const MrzParser();

  PassportResult parse(String rawText) {
    final lines = _findTd3Lines(rawText);
    if (lines.length != 2) {
      return PassportResult(rawText: rawText, mrzLines: lines);
    }

    final firstLine = lines[0];
    final secondLine = lines[1];
    final names = firstLine.substring(5).split('<<');
    final documentNumber = secondLine.substring(0, 9);
    final birthDate = secondLine.substring(13, 19);
    final expiryDate = secondLine.substring(21, 27);
    final personalNumber = secondLine.substring(28, 42);
    final compositeSource =
        '${secondLine.substring(0, 10)}${secondLine.substring(13, 20)}${secondLine.substring(21, 43)}';

    return PassportResult(
      rawText: rawText,
      mrzLines: lines,
      documentType: _clean(firstLine.substring(0, 2)),
      issuingCountry: _clean(firstLine.substring(2, 5)),
      surname: _namePart(names.first),
      givenNames: names.length > 1 ? _namePart(names[1]) : '',
      passportNumber: _clean(documentNumber),
      nationality: _clean(secondLine.substring(10, 13)),
      dateOfBirth: birthDate,
      sex: _clean(secondLine.substring(20, 21)),
      expiryDate: expiryDate,
      personalNumber: _clean(personalNumber),
      documentNumberCheckPassed: _hasValidCheck(documentNumber, secondLine[9]),
      birthDateCheckPassed: _hasValidCheck(birthDate, secondLine[19]),
      expiryDateCheckPassed: _hasValidCheck(expiryDate, secondLine[27]),
      personalNumberCheckPassed: _hasValidCheck(personalNumber, secondLine[42]),
      compositeCheckPassed: _hasValidCheck(compositeSource, secondLine[43]),
    );
  }

  List<String> _findTd3Lines(String rawText) {
    final normalizedLines = rawText
        .toUpperCase()
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'[^A-Z0-9<]'), ''))
        .where((line) => line.length >= 44)
        .map((line) => line.substring(0, 44))
        .toList();

    if (normalizedLines.length < 2) {
      return normalizedLines;
    }

    return normalizedLines.sublist(normalizedLines.length - 2);
  }

  bool _hasValidCheck(String value, String checkCharacter) {
    final expected = int.tryParse(checkCharacter);
    return expected != null && _checkDigit(value) == expected;
  }

  int _checkDigit(String value) {
    const weights = [7, 3, 1];
    var sum = 0;
    for (var index = 0; index < value.length; index++) {
      sum += _characterValue(value[index]) * weights[index % weights.length];
    }
    return sum % 10;
  }

  int _characterValue(String character) {
    if (character == '<') {
      return 0;
    }
    final code = character.codeUnitAt(0);
    if (code >= 48 && code <= 57) {
      return code - 48;
    }
    return code - 55;
  }

  String _clean(String value) => value.replaceAll('<', '').trim();

  String _namePart(String value) => value.replaceAll('<', ' ').trim();
}
