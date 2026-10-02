import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/passport_ocr_service.dart';
import 'passport_result_page.dart';

class PassportCameraPage extends StatefulWidget {
  const PassportCameraPage({super.key});

  @override
  State<PassportCameraPage> createState() => _PassportCameraPageState();
}

class _PassportCameraPageState extends State<PassportCameraPage> {
  final PassportOcrService _ocrService = PassportOcrService();
  CameraController? _cameraController;
  String? _errorMessage;
  bool _isCapturing = false;

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
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    XFile? image;
    try {
      image = await controller.takePicture();
      final result = await _ocrService.recognize(image.path);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PassportResultPage(imagePath: image.path, result: result),
        ),
      );
    } on CameraException catch (error) {
      _showMessage(_cameraErrorMessage(error));
    } catch (_) {
      _showMessage('OCR 처리에 실패했습니다. 빛 반사를 줄이고 MRZ 두 줄이 선명하게 보이도록 다시 촬영해 주세요.');
    } finally {
      if (image != null) {
        try {
          await File(image.path).delete();
        } on FileSystemException {
          // 카메라 플러그인이 임시 파일을 먼저 정리한 경우에는 무시한다.
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
            CameraPreview(controller),
            const _PassportGuide(),
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

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 64, 28, 120),
        child: Column(
          children: [
            const Text(
              '여권 데이터면을 가이드 안에 맞춰 주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.42,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '반사를 피하고, 하단 MRZ 두 줄이 또렷하게 보이게 촬영하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ],
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
