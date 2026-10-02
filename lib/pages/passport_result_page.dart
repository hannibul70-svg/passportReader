import 'dart:io';

import 'package:flutter/material.dart';

import '../models/passport_result.dart';

class PassportResultPage extends StatelessWidget {
  const PassportResultPage({
    super.key,
    required this.imagePath,
    required this.result,
  });

  final String imagePath;
  final PassportResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('여권 OCR 확인')),
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
          _MrzText(lines: result.mrzLines),
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
    final text = !result.hasMrz
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
    final text = lines.isEmpty ? '인식된 MRZ가 없습니다.' : lines.join('\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
      ),
    );
  }
}
