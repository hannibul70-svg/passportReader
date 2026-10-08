class PassportResult {
  const PassportResult({
    required this.rawText,
    required this.mrzLines,
    this.mrzOcrLines = const [],
    this.documentType,
    this.issuingCountry,
    this.surname,
    this.givenNames,
    this.passportNumber,
    this.nationality,
    this.dateOfBirth,
    this.sex,
    this.expiryDate,
    this.personalNumber,
    this.documentNumberCheckPassed = false,
    this.birthDateCheckPassed = false,
    this.expiryDateCheckPassed = false,
    this.personalNumberCheckPassed = false,
    this.compositeCheckPassed = false,
  });

  final String rawText;
  final List<String> mrzLines;
  // 물리적 MRZ 1·2행. 불완전 인식도 보존하며 완전 판정과 분리한다.
  final List<String> mrzOcrLines;
  final String? documentType;
  final String? issuingCountry;
  final String? surname;
  final String? givenNames;
  final String? passportNumber;
  final String? nationality;
  final String? dateOfBirth;
  final String? sex;
  final String? expiryDate;
  final String? personalNumber;
  final bool documentNumberCheckPassed;
  final bool birthDateCheckPassed;
  final bool expiryDateCheckPassed;
  final bool personalNumberCheckPassed;
  final bool compositeCheckPassed;

  bool get hasMrz => mrzLines.length == 2;

  bool get hasPartialMrz => mrzLines.isNotEmpty && !hasMrz;

  bool get hasValidChecks =>
      documentNumberCheckPassed &&
      birthDateCheckPassed &&
      expiryDateCheckPassed &&
      personalNumberCheckPassed &&
      compositeCheckPassed;
}
