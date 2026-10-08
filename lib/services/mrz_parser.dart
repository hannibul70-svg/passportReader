import '../models/passport_result.dart';

class MrzParser {
  const MrzParser();

  static String normalizeLine(String line) =>
      line.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9<]'), '');

  static String normalizeOcrText(String rawText) => rawText
      .split(RegExp(r'\r?\n'))
      .map(normalizeLine)
      .where((line) => line.isNotEmpty)
      .join('\n');

  PassportResult parse(
    String rawText, {
    List<String>? mrzCandidateLines,
    List<String> mrzOcrLines = const [],
  }) {
    final candidates = _findMrzCandidates(
      mrzCandidateLines ?? rawText.split(RegExp(r'\r?\n')),
      keepShortLines: mrzCandidateLines != null,
    );
    final verifiedLines = _findTd3Lines(candidates);
    if (verifiedLines.length != 2 && mrzOcrLines.length != 2) {
      return PassportResult(
        rawText: rawText,
        mrzOcrLines: mrzOcrLines,
        mrzLines: _findPartialMrzLines(
          candidates,
        ).map((line) => line.raw).toList(),
      );
    }

    // 인적사항 표시는 완전 인식 판정과 분리한다. 없는 뒷부분은 채우지 않는다.
    final firstLine = mrzOcrLines.length == 2
        ? normalizeLine(mrzOcrLines[0])
        : verifiedLines[0].normalized;
    final secondLine = mrzOcrLines.length == 2
        ? normalizeLine(mrzOcrLines[1])
        : verifiedLines[1].normalized;
    final names = _available(firstLine, 5, 44).split('<<');
    final documentNumber = _available(secondLine, 0, 9);
    final birthDate = _available(secondLine, 13, 19);
    final expiryDate = _available(secondLine, 21, 27);
    final personalNumber = _available(secondLine, 28, 42);
    final compositeSource =
        '${_available(secondLine, 0, 10)}${_available(secondLine, 13, 20)}${_available(secondLine, 21, 43)}';

    return PassportResult(
      rawText: rawText,
      mrzOcrLines: mrzOcrLines,
      mrzLines:
          (verifiedLines.length == 2
                  ? verifiedLines
                  : _findPartialMrzLines(candidates))
              .map((line) => line.raw)
              .toList(),
      documentType: _clean(_available(firstLine, 0, 2)),
      issuingCountry: _clean(_available(firstLine, 2, 5)),
      surname: _normalizeMrzValue(names.first),
      givenNames: names.length > 1 ? _normalizeMrzValue(names[1]) : '',
      passportNumber: _clean(documentNumber),
      nationality: _clean(_available(secondLine, 10, 13)),
      dateOfBirth: birthDate,
      sex: _clean(_available(secondLine, 20, 21)),
      expiryDate: expiryDate,
      personalNumber: _clean(personalNumber),
      documentNumberCheckPassed: _hasValidCheck(
        documentNumber,
        _available(secondLine, 9, 10),
      ),
      birthDateCheckPassed: _hasValidCheck(
        birthDate,
        _available(secondLine, 19, 20),
      ),
      expiryDateCheckPassed: _hasValidCheck(
        expiryDate,
        _available(secondLine, 27, 28),
      ),
      personalNumberCheckPassed: _hasValidCheck(
        personalNumber,
        _available(secondLine, 42, 43),
      ),
      compositeCheckPassed: _hasValidCheck(
        compositeSource,
        _available(secondLine, 43, 44),
      ),
    );
  }

  String _available(String line, int start, int end) {
    if (start >= line.length) return '';
    return line.substring(start, end.clamp(start, line.length));
  }

  List<_MrzCandidate> _findMrzCandidates(
    List<String> lines, {
    required bool keepShortLines,
  }) {
    final candidates = lines
        .map(
          (line) => _MrzCandidate(raw: line, normalized: normalizeLine(line)),
        )
        .where((line) => line.normalized.isNotEmpty)
        .where((line) => line.normalized.length <= 44)
        .toList();
    final merged = _mergeSplitTd3FirstLines(candidates);
    return merged
        .where((line) => keepShortLines || line.normalized.length >= 30)
        .toList();
  }

  List<_MrzCandidate> _mergeSplitTd3FirstLines(List<_MrzCandidate> candidates) {
    final mergedCandidates = <_MrzCandidate>[];
    for (var index = 0; index < candidates.length; index++) {
      final current = candidates[index];
      if (index + 1 < candidates.length) {
        final next = candidates[index + 1];
        final merged = _MrzCandidate(
          raw: '${current.raw}${next.raw}',
          normalized: '${current.normalized}${next.normalized}',
        );
        if (_isTd3FirstLinePrefix(current.normalized) &&
            RegExp(r'^<+$').hasMatch(next.normalized) &&
            _isTd3FirstLine(merged.normalized)) {
          mergedCandidates.add(merged);
          index++;
          continue;
        }
      }
      mergedCandidates.add(current);
    }
    return mergedCandidates;
  }

  List<_MrzCandidate> _findTd3Lines(List<_MrzCandidate> candidates) {
    final firstLineIndex = candidates.indexWhere(
      (line) => _isTd3FirstLine(line.normalized),
    );
    if (firstLineIndex == -1) {
      return const [];
    }

    for (var index = firstLineIndex + 1; index < candidates.length; index++) {
      if (_isTd3SecondLine(candidates[index].normalized)) {
        return [candidates[firstLineIndex], candidates[index]];
      }
    }

    return const [];
  }

  List<_MrzCandidate> _findPartialMrzLines(List<_MrzCandidate> candidates) {
    final secondLine = candidates.lastWhere(
      (line) => _looksLikeTd3SecondLine(line.normalized),
      orElse: () => const _MrzCandidate(raw: '', normalized: ''),
    );
    if (secondLine.raw.isNotEmpty) {
      return [secondLine];
    }

    final firstLine = candidates.lastWhere(
      (line) => _isTd3FirstLine(line.normalized),
      orElse: () => const _MrzCandidate(raw: '', normalized: ''),
    );
    return firstLine.raw.isEmpty ? const [] : [firstLine];
  }

  bool _isTd3FirstLine(String line) =>
      line.length == 44 &&
      RegExp(r'^P[A-Z<][A-Z]{3}[A-Z<]*<<[A-Z<]*$').hasMatch(line);

  bool _isTd3FirstLinePrefix(String line) =>
      line.length < 44 &&
      RegExp(r'^P[A-Z<][A-Z]{3}[A-Z<]*<<[A-Z<]*$').hasMatch(line);

  bool _isTd3SecondLine(String line) => RegExp(
    r'^[A-Z0-9<]{9}[0-9][A-Z<]{3}[0-9]{6}[0-9][FM<][0-9]{6}[0-9][A-Z0-9<]{14}[0-9][0-9]$',
  ).hasMatch(line);

  bool _looksLikeTd3SecondLine(String line) => RegExp(
    r'^[A-Z0-9<]{10}[A-Z]{3}[A-Z0-9<]{7}[FM<][A-Z0-9<]{23}$',
  ).hasMatch(line);

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

  String _clean(String value) => _normalizeMrzValue(value);

  String _normalizeMrzValue(String value) => value.replaceAll('<', ' ').trim();
}

class _MrzCandidate {
  const _MrzCandidate({required this.raw, required this.normalized});

  final String raw;
  final String normalized;
}
