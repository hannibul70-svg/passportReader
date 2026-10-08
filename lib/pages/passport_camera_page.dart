import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/passport_ocr_service.dart';
import '../services/passport_photo_extractor.dart';
import '../services/passport_capture_cropper.dart';
import 'passport_result_page.dart';

class PassportCameraPage extends StatefulWidget {
  const PassportCameraPage({super.key});

  @override
  State<PassportCameraPage> createState() => _PassportCameraPageState();
}

class _PassportCameraPageState extends State<PassportCameraPage> {
  final PassportOcrService _ocrService = PassportOcrService();
  final PassportPhotoExtractor _photoExtractor = const PassportPhotoExtractor();
  final PassportCaptureCropper _captureCropper = const PassportCaptureCropper();
  Rect? _normalizedCaptureRegion;
  double? _previewAspectRatio;
  CameraController? _cameraController;
  String? _errorMessage;
  bool _isCapturing = false;
  Offset? _focusTarget;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', '사용 가능한 카메라가 없습니다.');
      }
      final rearCameras = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      final selectedCamera = rearCameras.isEmpty
          ? cameras.first
          : rearCameras.first;
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _cameraErrorMessage(error));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = '카메라를 시작할 수 없습니다. 카메라 권한과 기기 상태를 확인해 주세요.',
        );
      }
    }
  }

  Future<void> _captureAndRecognize() async {
    final controller = _cameraController;
    final captureRegion = _normalizedCaptureRegion;
    final previewAspectRatio = _previewAspectRatio;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        captureRegion == null ||
        previewAspectRatio == null) {
      return;
    }

    setState(() => _isCapturing = true);
    XFile? image;
    String? faceImagePath;
    String? pageImagePath;
    try {
      final capturedImage = await controller.takePicture();
      image = capturedImage;
      pageImagePath = await _captureCropper.crop(
        capturedImage.path,
        captureRegion,
        previewAspectRatio: previewAspectRatio,
      );
      final result = await _ocrService.recognize(pageImagePath);
      faceImagePath = await _photoExtractor.extract(pageImagePath);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PassportResultPage(
            imagePath: pageImagePath!,
            faceImagePath: faceImagePath,
            result: result,
          ),
        ),
      );
    } on CameraException catch (error) {
      _showMessage(_cameraErrorMessage(error));
    } catch (_) {
      _showMessage('OCR 처리에 실패했습니다. 빛 반사를 줄이고 MRZ 두 줄이 선명하게 보이도록 다시 촬영해 주세요.');
    } finally {
      if (pageImagePath != null) {
        try {
          await File(pageImagePath).delete();
        } on FileSystemException {
          // 결과 화면을 닫은 뒤 이미 삭제된 파일은 무시한다.
        }
      }
      if (image != null) {
        try {
          await File(image.path).delete();
        } on FileSystemException {
          // 카메라 플러그인이 임시 파일을 먼저 정리한 경우에는 무시한다.
        }
      }
      if (faceImagePath != null) {
        try {
          await File(faceImagePath).delete();
        } on FileSystemException {
          // 결과 화면을 닫은 뒤 파일 시스템이 임시 파일을 먼저 정리한 경우는 무시한다.
        }
      }
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _focusCameraAt(
    TapUpDetails details,
    BoxConstraints previewConstraints,
  ) async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        previewConstraints.maxWidth == 0 ||
        previewConstraints.maxHeight == 0) {
      return;
    }

    final focusPoint = Offset(
      (details.localPosition.dx / previewConstraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / previewConstraints.maxHeight).clamp(0.0, 1.0),
    );

    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(focusPoint);
      if (mounted) {
        setState(() => _focusTarget = focusPoint);
      }
    } on CameraException {
      _showMessage('이 기기에서는 터치 초점 기능을 사용할 수 없습니다.');
    }
  }

  String _cameraErrorMessage(CameraException error) {
    if (error.code == 'CameraAccessDenied') {
      return '카메라 권한이 필요합니다. 기기 설정에서 카메라 접근을 허용해 주세요.';
    }
    return '카메라를 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.';
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    if (_errorMessage != null) {
      return _CameraErrorPage(message: _errorMessage!);
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isPortrait =
                    MediaQuery.orientationOf(context) == Orientation.portrait;
                final previewAspect = isPortrait
                    ? 1 / controller.value.aspectRatio
                    : controller.value.aspectRatio;
                _previewAspectRatio = previewAspect;
                final previewSize = applyBoxFit(
                  BoxFit.contain,
                  Size(previewAspect, 1),
                  constraints.biggest,
                ).destination;
                final previewRect = Alignment.center.inscribe(
                  previewSize,
                  Offset.zero & constraints.biggest,
                );
                const guideAspect = 1.42 / 0.8;
                final guideSize = applyBoxFit(
                  BoxFit.contain,
                  const Size(guideAspect, 1),
                  Size(previewRect.width * 0.94, previewRect.height * 0.65),
                ).destination;
                final guideRect = Alignment.center.inscribe(
                  guideSize,
                  previewRect,
                );
                _normalizedCaptureRegion = Rect.fromLTWH(
                  (guideRect.left - previewRect.left) / previewRect.width,
                  (guideRect.top - previewRect.top) / previewRect.height,
                  guideRect.width / previewRect.width,
                  guideRect.height / previewRect.height,
                );
                return Stack(
                  children: [
                    Positioned.fromRect(
                      rect: previewRect,
                      child: LayoutBuilder(
                        builder: (context, previewConstraints) =>
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) =>
                                  _focusCameraAt(details, previewConstraints),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(controller),
                                  if (_focusTarget != null)
                                    Align(
                                      alignment: Alignment(
                                        _focusTarget!.dx * 2 - 1,
                                        _focusTarget!.dy * 2 - 1,
                                      ),
                                      child: const _FocusTargetIndicator(),
                                    ),
                                ],
                              ),
                            ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: guideRect,
                      child: const _PassportGuide(),
                    ),
                    const Positioned(
                      top: 20,
                      left: 16,
                      right: 16,
                      child: IgnorePointer(
                        child: Text(
                          '인적사항 면만 격자에 맞춰 주세요\nMRZ 두 줄은 4행 · 격자 밖은 OCR하지 않습니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: FilledButton.icon(
                onPressed: _isCapturing ? null : _captureAndRecognize,
                icon: _isCapturing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_isCapturing ? 'OCR 처리 중...' : '여권 촬영'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassportGuide extends StatelessWidget {
  const _PassportGuide();

  static const _guideColor = Color(0xFF63F59B);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: _guideColor, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const _PassportCaptureGuides(),
          const CustomPaint(painter: _PassportGridPainter()),
          const Offstage(child: _GuideStatus()),
          const Offstage(child: _RecognitionTargetPanel()),
        ],
      ),
    );
  }
}

class _GuideStatus extends StatelessWidget {
  const _GuideStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xDD071B10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '위쪽 안내 면은 제외 · MRZ 두 줄은 격자 4행에 · 좌표 예: A4',
        style: TextStyle(color: Color(0xFFD7FFE4), fontSize: 12),
      ),
    );
  }
}

class _PassportCaptureGuides extends StatelessWidget {
  const _PassportCaptureGuides();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Offstage(
          child: _FacePhotoGuide(
            alignment: Alignment(-0.48, 0.08),
            widthFactor: 0.36,
            heightFactor: 0.38,
          ),
        ),
        _CaptureGuideRegion(
          label: 'MRZ 1',
          alignment: Alignment(0, 0.72),
          widthFactor: 0.84,
          heightFactor: 0.08,
        ),
        _CaptureGuideRegion(
          label: 'MRZ 2',
          alignment: Alignment(0, 0.91),
          widthFactor: 0.84,
          heightFactor: 0.08,
        ),
      ],
    );
  }
}

class _PassportGridPainter extends CustomPainter {
  const _PassportGridPainter();

  static const _cellCount = 4;
  static const _columns = 'ABCD';

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x8863F59B)
      ..strokeWidth = 1;
    final cellWidth = size.width / _cellCount;
    final cellHeight = size.height / _cellCount;
    for (var index = 1; index < _cellCount; index++) {
      canvas.drawLine(
        Offset(cellWidth * index, 0),
        Offset(cellWidth * index, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, cellHeight * index),
        Offset(size.width, cellHeight * index),
        paint,
      );
    }
    for (var row = 0; row < _cellCount; row++) {
      for (var column = 0; column < _cellCount; column++) {
        final label = TextPainter(
          text: TextSpan(
            text: '${_columns[column]}${row + 1}',
            style: const TextStyle(
              color: Color(0xFF63F59B),
              fontSize: 12,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(
          canvas,
          Offset(column * cellWidth + 5, row * cellHeight + 5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PassportGridPainter oldDelegate) => false;
}

class _FacePhotoGuide extends StatelessWidget {
  const _FacePhotoGuide({
    required this.alignment,
    required this.widthFactor,
    required this.heightFactor,
  });

  final Alignment alignment;
  final double widthFactor;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _FaceOutlinePainter()),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: Text(
                '얼굴 사진',
                style: TextStyle(
                  color: Color(0xFF63F59B),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceOutlinePainter extends CustomPainter {
  const _FaceOutlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF63F59B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final face = Rect.fromLTWH(
      size.width * 0.25,
      size.height * 0.13,
      size.width * 0.5,
      size.height * 0.59,
    );
    final shoulders = Path()
      ..moveTo(size.width * 0.13, size.height * 0.94)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.62,
        size.width * 0.87,
        size.height * 0.94,
      );

    canvas.drawOval(face, linePaint);
    canvas.drawPath(shoulders, linePaint);
  }

  @override
  bool shouldRepaint(covariant _FaceOutlinePainter oldDelegate) => false;
}

class _CaptureGuideRegion extends StatelessWidget {
  const _CaptureGuideRegion({
    required this.label,
    required this.alignment,
    required this.widthFactor,
    required this.heightFactor,
  });

  final String label;
  final Alignment alignment;
  final double widthFactor;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: const Color(0xFF63F59B), width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF63F59B),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 3)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusTargetIndicator extends StatelessWidget {
  const _FocusTargetIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFD35C), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _RecognitionTargetPanel extends StatelessWidget {
  const _RecognitionTargetPanel();

  static const _targets = ['얼굴 사진', 'MRZ 1', 'MRZ 2'];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE807130E),
        border: Border.all(color: const Color(0xFF214E35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '촬영 대상',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 2.2,
                physics: const NeverScrollableScrollPhysics(),
                children: _targets
                    .map((target) => _RecognitionTargetChip(label: target))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecognitionTargetChip extends StatelessWidget {
  const _RecognitionTargetChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF2E9F57)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFD7FFE4), fontSize: 9),
        ),
      ),
    );
  }
}

class _CameraErrorPage extends StatelessWidget {
  const _CameraErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('여권 OCR')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
