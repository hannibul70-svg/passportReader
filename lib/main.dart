import 'package:flutter/material.dart';

import 'pages/passport_camera_page.dart';

void main() {
  runApp(const PassportReaderApp());
}

class PassportReaderApp extends StatelessWidget {
  const PassportReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '여권 OCR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B4F6C)),
        useMaterial3: true,
      ),
      home: const PassportCameraPage(),
    );
  }
}
