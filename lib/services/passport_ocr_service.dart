import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/passport_result.dart';
import 'mrz_parser.dart';

class PassportOcrService {
  PassportOcrService({MrzParser? mrzParser})
    : _mrzParser = mrzParser ?? const MrzParser();

  final MrzParser _mrzParser;
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<PassportResult> recognize(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return _mrzParser.parse(recognizedText.text);
  }

  Future<void> dispose() => _textRecognizer.close();
}
