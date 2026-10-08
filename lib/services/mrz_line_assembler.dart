import 'dart:math' as math;

import 'mrz_parser.dart';

class MrzOcrFragment {
  const MrzOcrFragment({
    required this.text,
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    this.slope = 0,
    this.confidence,
  });

  final String text;
  final double centerX;
  final double centerY;
  final double width;
  final double height;
  final double slope;
  final double? confidence;
}

class MrzLineAssembler {
  const MrzLineAssembler();

  List<String> assemble(List<MrzOcrFragment> fragments) {
    final rows = groupRows(fragments);
    if (rows.isEmpty) return ['', ''];
    // MRZ 전용 crop의 아래 두 행만 사용한다. 문자를 추가하거나 자르지 않는다.
    final bottomRows = rows.skip(math.max(0, rows.length - 2)).map((row) {
      return row.map((part) => MrzParser.normalizeLine(part.text)).join();
    }).toList();
    if (bottomRows.length == 2) return bottomRows;
    final onlyLine = bottomRows.single;
    final isFirstLine = RegExp(r'^P[A-Z<][A-Z]{3}').hasMatch(onlyLine);
    return isFirstLine ? [onlyLine, ''] : ['', onlyLine];
  }

  List<List<MrzOcrFragment>> groupRows(List<MrzOcrFragment> fragments) {
    final usable = fragments
        .where((part) => MrzParser.normalizeLine(part.text).isNotEmpty)
        .where((part) => part.width > 0 && part.height > 0)
        .toList();
    if (usable.isEmpty) return [];

    // 가장 긴 OCR 조각의 기울기로 같은 행의 좌우 조각을 정렬한다.
    final widest = usable.reduce((a, b) => a.width >= b.width ? a : b);
    final slope = widest.slope;
    double rowY(MrzOcrFragment part) => part.centerY - slope * part.centerX;
    final heights = usable.map((part) => part.height).toList()..sort();
    const sameRowHeightFraction = 0.6;
    final tolerance = heights[heights.length ~/ 2] * sameRowHeightFraction;
    usable.sort((a, b) => rowY(a).compareTo(rowY(b)));
    final rows = <List<MrzOcrFragment>>[];
    for (final part in usable) {
      if (rows.isEmpty) {
        rows.add([part]);
        continue;
      }
      final lastRow = rows.last;
      final meanY = lastRow.map(rowY).reduce((a, b) => a + b) / lastRow.length;
      if ((rowY(part) - meanY).abs() <= tolerance) {
        lastRow.add(part);
      } else {
        rows.add([part]);
      }
    }

    for (final row in rows) {
      row.sort((a, b) => a.centerX.compareTo(b.centerX));
    }
    return rows;
  }
}
