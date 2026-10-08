import 'dart:io';

import 'package:passport_reader_mobile/services/mrz_line_assembler.dart';
import 'package:passport_reader_mobile/services/mrz_parser.dart';

void main() {
  const assembler = MrzLineAssembler();
  const parser = MrzParser();
  // Sample/ICAO_Example.png의 MRZ 내용. 이미지 OCR 실행이 아닌 좌표 결합 회귀 검사.
  final first = 'P<UTOERIKSSON<<ANNA<MARIA'.padRight(44, '<');
  const second = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';
  for (final slope in [0.0, 0.08, -0.08]) {
    MrzOcrFragment part(String text, double x, double y, double width) =>
        MrzOcrFragment(
          text: text,
          centerX: x,
          centerY: y + slope * x,
          width: width,
          height: 16,
          slope: slope,
        );
    final fragments = [
      part(second.substring(22), 330, 130, 220),
      part(first.substring(22), 330, 100, 220),
      part('ISSUED ON', 200, 50, 100),
      part(first.substring(0, 22), 110, 101, 220),
      part(second.substring(0, 22), 110, 130, 220),
    ];
    final lines = assembler.assemble(fragments);
    final result = parser.parse(
      'unchanged OCR diagnostic',
      mrzCandidateLines: lines,
      mrzOcrLines: lines,
    );
    if (lines.length != 2 ||
        lines[0] != first ||
        lines[1] != second ||
        !result.hasMrz ||
        !result.hasValidChecks ||
        result.givenNames != 'ANNA MARIA') {
      throw StateError('ICAO spatial split assembly failed: slope=$slope');
    }
    final incomplete = assembler.assemble([
      part(first.substring(0, 18), 80, 100, 160),
      part(first.substring(18, 39), 280, 100, 200),
      part(second, 220, 130, 440),
    ]);
    final partial = parser.parse(
      '',
      mrzCandidateLines: incomplete,
      mrzOcrLines: incomplete,
    );
    if (incomplete.length != 2 ||
        incomplete[0].length != 39 ||
        partial.hasMrz ||
        partial.mrzOcrLines.length != 2) {
      throw StateError('Incomplete physical rows were padded or lost');
    }
    final secondOnly = assembler.assemble([part(second, 220, 130, 440)]);
    if (secondOnly[0].isNotEmpty || secondOnly[1] != second) {
      throw StateError('MRZ 2 was placed in MRZ 1 slot');
    }
  }
  // 한국 샘플과 같은 이름/발급국 형태도 분할 위치에 관계없이 결합한다.
  final koreanFirst = 'PMKORHONG<<GILDONG'.padRight(44, '<');
  final korean = assembler.assemble([
    MrzOcrFragment(
      text: koreanFirst.substring(12),
      centerX: 280,
      centerY: 50,
      width: 320,
      height: 14,
    ),
    MrzOcrFragment(
      text: koreanFirst.substring(0, 12),
      centerX: 60,
      centerY: 50,
      width: 120,
      height: 14,
    ),
    const MrzOcrFragment(
      text: second,
      centerX: 220,
      centerY: 80,
      width: 440,
      height: 14,
    ),
  ]);
  if (korean[0] != koreanFirst || assembler.assemble([]).length != 2) {
    throw StateError('Korean split or empty row assembly failed');
  }
  stdout.writeln(
    'PASS: two physical rows, shuffled fragments, name/filler splits, skew, incomplete rows, MRZ2-only',
  );
}
