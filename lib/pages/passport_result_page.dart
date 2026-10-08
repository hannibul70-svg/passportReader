import 'dart:io';

import 'package:flutter/material.dart';

import '../models/passport_result.dart';
import '../services/mrz_parser.dart';

class PassportResultPage extends StatelessWidget {
  const PassportResultPage({
    super.key,
    required this.imagePath,
    required this.faceImagePath,
    required this.result,
  });

  final String imagePath;
  final String? faceImagePath;
  final PassportResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('여권 OCR 확인 · 진단 2026-10-08 F')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(imagePath), fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          _StatusCard(result: result),
          const SizedBox(height: 16),
          if (faceImagePath != null) ...[
            const Text(
              '여권 사진',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(faceImagePath!),
                  width: 128,
                  height: 176,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            '인식된 인적사항',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _FieldTable(result: result),
          const SizedBox(height: 16),
          const Text(
            'MRZ OCR',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _MrzText(lines: result.mrzOcrLines),
          const SizedBox(height: 16),
          const Text(
            'MRZ 영역 OCR 원문',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _RawOcrText(rawText: result.rawText),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('다시 촬영'),
          ),
          const SizedBox(height: 8),
          const Text(
            'MVP에서는 촬영·OCR 결과를 앱 메모리에서만 표시하며 저장하거나 서버로 전송하지 않습니다.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.result});

  final PassportResult result;

  @override
  Widget build(BuildContext context) {
    final success = result.hasMrz && result.hasValidChecks;
    final hasPhysicalText = result.mrzOcrLines.any((line) => line.isNotEmpty);
    final text = !result.hasMrz && hasPhysicalText
        ? 'MRZ가 불완전하거나 형식이 맞지 않습니다. 인적사항에는 앞부분부터 읽힌 값만 표시합니다. 검증된 정보가 아니므로 확인해 주세요.'
        : result.hasPartialMrz
        ? 'MRZ 한 줄만 인식했습니다. 인적사항을 추출하려면 MRZ 1·2가 모두 선명하게 보이도록 다시 촬영해 주세요.'
        : !result.hasMrz
        ? 'MRZ 두 줄을 찾지 못했습니다. 하단 MRZ가 선명하게 보이도록 다시 촬영해 주세요.'
        : success
        ? 'MRZ 검증이 완료되었습니다.'
        : 'MRZ는 인식되었지만 검증에 실패했습니다. 내용을 확인하고 다시 촬영해 주세요.';
    return Card(
      color: success ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.verified_outlined : Icons.warning_amber_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _FieldTable extends StatelessWidget {
  const _FieldTable({required this.result});

  final PassportResult result;

  @override
  Widget build(BuildContext context) {
    final fields = <(String, String?)>[
      ('문서 종류', result.documentType),
      ('발급 국가', result.issuingCountry),
      ('성', result.surname),
      ('이름', result.givenNames),
      ('여권 번호', result.passportNumber),
      ('국적', result.nationality),
      ('생년월일 (YYMMDD)', result.dateOfBirth),
      ('성별', result.sex),
      ('만료일 (YYMMDD)', result.expiryDate),
      ('개인 번호', result.personalNumber),
    ];
    return Card(
      child: Column(
        children: fields
            .map(
              (field) => ListTile(
                dense: true,
                title: Text(field.$1),
                trailing: Text(field.$2?.isNotEmpty == true ? field.$2! : '-'),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MrzText extends StatelessWidget {
  const _MrzText({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final physicalLines = lines.length == 2 ? lines : const ['', ''];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < 2; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            Text(
              'MRZ ${index + 1} · ${physicalLines[index].length}/44자',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            // 행마다 가로 스크롤하여 44자가 좁은 화면에서도 줄바꿈되지 않는다.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                physicalLines[index].isEmpty ? '인식되지 않음' : physicalLines[index],
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RawOcrText extends StatelessWidget {
  const _RawOcrText({required this.rawText});

  final String rawText;

  @override
  Widget build(BuildContext context) {
    final numberedText = rawText
        .split(RegExp(r'\r?\n'))
        .asMap()
        .entries
        .map((entry) {
          final normalizedLength = MrzParser.normalizeLine(entry.value).length;
          return 'M${entry.key + 1} [원문 ${entry.value.length}자 / MRZ 문자 $normalizedLength자] ${entry.value}';
        })
        .join('\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(rawText.isEmpty ? '인식된 문자가 없습니다.' : numberedText),
    );
  }
}
