import '../models/passport_result.dart';

bool shouldRetryMrzOcr(PassportResult result) =>
    !result.hasMrz || !result.hasValidChecks;

PassportResult preferMrzOcrResult(
  PassportResult original,
  PassportResult retry,
) => _quality(retry) > _quality(original) ? retry : original;

int _quality(PassportResult result) {
  const verifiedPairScore = 100000;
  const completePairScore = 10000;
  const fieldCheckScore = 100;
  const rowPatternScore = 1000;
  const td3LineLength = 44;
  if (result.hasMrz && result.hasValidChecks) return verifiedPairScore;
  var score = result.hasMrz ? completePairScore : 0;
  final checks = [
    result.documentNumberCheckPassed,
    result.birthDateCheckPassed,
    result.expiryDateCheckPassed,
    result.personalNumberCheckPassed,
    result.compositeCheckPassed,
  ];
  score += checks.where((passed) => passed).length * fieldCheckScore;
  final lines = result.mrzOcrLines;
  if (lines.length != 2) return score;
  if (RegExp(r'^P[A-Z<][A-Z]{3}').hasMatch(lines[0]) &&
      lines[0].contains('<<')) {
    score += rowPatternScore;
  }
  if (RegExp(r'^[A-Z0-9<]{9}[0-9][A-Z<]{3}').hasMatch(lines[1])) {
    score += rowPatternScore;
  }
  for (final line in lines) {
    // 긴 오인식 문자열 대신 44자에 가까운 행을 선호한다.
    score +=
        td3LineLength -
        (line.length - td3LineLength).abs().clamp(0, td3LineLength);
    if (line.length > td3LineLength) score -= rowPatternScore;
  }
  return score;
}
