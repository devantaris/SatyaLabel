import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../services/location_service.dart';
import '../../state/app_state.dart';
import 'crop_screen.dart';
import 'scan_result_screen.dart';

/// Camera capture → scan submission.
///
/// Pass [sessionId] to add scans to an inspector batch raid session.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

enum _CapturePhase { ready, submitting, queued }

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _cameraError;
  bool _initializing = true;
  _CapturePhase _phase = _CapturePhase.ready;
  String? _submitError;
  FlashMode _flashMode = FlashMode.off;

  /// On-device OCR (Google ML Kit) — runs on the phone, offline-capable.
  /// The recognised text is sent with the scan; the backend then skips its
  /// own (weaker) OCR engines and runs only field extraction + rules.
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  String? get _sessionId => widget.sessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.max, // max resolution — OCR needs sharp, large text
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
        _initializing = false;
      });
    } on CameraException catch (e) {
      setState(() {
        _cameraError = e.description ?? 'Camera error: ${e.code}';
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _cameraError = 'Camera unavailable: $e';
        _initializing = false;
      });
    }
  }

  Future<void> _onCapture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_phase != _CapturePhase.ready) return;

    setState(() {
      _phase = _CapturePhase.submitting;
      _submitError = null;
    });

    Uint8List? imageBytes;
    String? ocrText;
    String? ocrLinesJson;
    try {
      final xfile = await controller.takePicture();

      // Let the user frame the label — a tight crop reads far better
      // than a whole-shelf photo.
      if (!mounted) return;
      final cropped = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => CropScreen(imagePath: xfile.path)),
      );
      if (cropped == null) {
        // Cancelled — back to the camera, nothing submitted.
        if (mounted) setState(() => _phase = _CapturePhase.ready);
        return;
      }

      var bytes = await _shrinkIfNeeded(cropped);
      imageBytes = bytes;

      // On-device OCR (ML Kit): text + per-line bounding boxes, so the
      // backend can reassemble misaligned key/value blocks.
      final ocr = await _recognize(bytes);
      ocrText = ocr?.text;
      ocrLinesJson = ocr?.linesJson;

      if (!mounted) return;
      final app = context.read<AppState>();
      final location = await LocationService.currentPosition();

      if (!app.backendReachable) {
        await app.queue.enqueue(
          bytes,
          mimeType: 'image/png',
          latitude: location?.latitude,
          longitude: location?.longitude,
          sessionId: _sessionId,
          ocrText: ocrText,
          ocrLinesJson: ocrLinesJson,
        );
        if (mounted) setState(() => _phase = _CapturePhase.queued);
        return;
      }

      final result = await app.api.submitScan(
        bytes,
        mimeType: 'image/png',
        latitude: location?.latitude,
        longitude: location?.longitude,
        sessionId: _sessionId,
        ocrText: ocrText,
        ocrLinesJson: ocrLinesJson,
      );
      await app.rememberScan(result.scanId);

      if (!mounted) return;
      setState(() => _phase = _CapturePhase.ready);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            result: result,
            imageBytes: bytes,
            batchMode: _sessionId != null,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CapturePhase.ready;
        _submitError = 'Server rejected the scan (${e.statusCode}): ${e.message}';
      });
    } on NetworkException catch (e) {
      // Connection dropped mid-upload — queue it for the sync service.
      if (imageBytes == null) {
        if (mounted) {
          setState(() {
            _phase = _CapturePhase.ready;
            _submitError = 'Network error: $e';
          });
        }
        return;
      }
      if (!mounted) return;
      final app = context.read<AppState>();
      final location = await LocationService.currentPosition();
      await app.queue.enqueue(
        imageBytes,
        mimeType: 'image/png',
        latitude: location?.latitude,
        longitude: location?.longitude,
        sessionId: _sessionId,
        ocrText: ocrText,
        ocrLinesJson: ocrLinesJson,
      );
      if (mounted) setState(() => _phase = _CapturePhase.queued);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CapturePhase.ready;
        _submitError = 'Failed to process image: $e';
      });
    }
  }

  /// Runs ML Kit text recognition on the cropped image bytes. Returns the
  /// recognised text plus a JSON array of per-line results with bounding
  /// boxes, or null when recognition fails — the backend then falls back
  /// to its own OCR engines.
  Future<({String text, String linesJson})?> _recognize(Uint8List bytes) async {
    File? temp;
    try {
      final dir = await getTemporaryDirectory();
      temp = File('${dir.path}/satyalabel_ocr_'
          '${DateTime.now().microsecondsSinceEpoch}.png');
      await temp.writeAsBytes(bytes);
      final recognized = await _textRecognizer.processImage(
        InputImage.fromFilePath(temp.path),
      );
      final lines = <Map<String, dynamic>>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final b = line.boundingBox;
          lines.add({
            'text': line.text,
            'x': b.left.round(),
            'y': b.top.round(),
            'w': b.width.round(),
            'h': b.height.round(),
          });
        }
      }
      final text = recognized.text.trim();
      if (text.isEmpty && lines.isEmpty) return null;
      return (text: text, linesJson: jsonEncode(lines));
    } catch (e) {
      debugPrint('ML Kit OCR failed: $e');
      return null;
    } finally {
      try {
        if (temp != null && temp.existsSync()) temp.deleteSync();
      } catch (_) {}
    }
  }

  /// Re-encodes the photo when it exceeds the backend's 10 MB limit.
  /// Dart's `toByteData` has no JPEG format, so PNG at a reduced width is
  /// used — still far below the cap for a label photo.
  Future<Uint8List> _shrinkIfNeeded(Uint8List bytes) async {
    const maxBytes = 9 * 1024 * 1024; // headroom below the 10 MB cap
    if (bytes.length <= maxBytes) return bytes;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1600, // plenty for OCR while drastically reducing size
    );
    final frame = await codec.getNextFrame();
    final data =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return bytes;
    final shrunk = data.buffer.asUint8List();
    return shrunk.length < bytes.length ? shrunk : bytes;
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await controller.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final controller = _controller;
    final busy = _phase != _CapturePhase.ready;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_sessionId == null ? 'Scan Label' : 'Raid $_sessionId'),
        actions: [
          if (controller != null && controller.value.isInitialized)
            IconButton(
              icon: Icon(
                _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                color: Colors.white,
              ),
              onPressed: busy ? null : _toggleFlash,
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initializing)
            const Center(child: CircularProgressIndicator())
          else if (_cameraError != null)
            _CameraErrorView(
              error: _cameraError!,
              onRetry: () {
                setState(() => _initializing = true);
                _initCamera();
              },
            )
          else if (controller != null && controller.value.isInitialized)
            CameraPreview(controller)
          else
            const Center(child: Text('Camera unavailable', style: TextStyle(color: Colors.white))),

          if (_phase == _CapturePhase.queued)
            _QueuedOverlay(onDone: () => Navigator.pop(context)),

          if (busy && _phase == _CapturePhase.submitting)
            const _SubmittingOverlay(),

          if (_submitError != null && _phase == _CapturePhase.ready)
            Positioned(
              left: 16,
              right: 16,
              bottom: 160,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _submitError!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _cameraError == null && !_initializing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!app.backendReachable)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Offline — scans will be queued',
                          style: TextStyle(color: Colors.amber),
                        ),
                      ),
                    Center(
                      child: GestureDetector(
                        onTap: busy ? null : _onCapture,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: busy ? Colors.grey : Colors.white,
                            border: Border.all(color: Colors.white24, width: 4),
                          ),
                          child: busy
                            ? const Padding(
                                padding: EdgeInsets.all(22),
                                child: CircularProgressIndicator(strokeWidth: 3),
                              )
                            : const Icon(Icons.camera, size: 36, color: Colors.black),
                        ),
                      ),
                    ),
                    if (_sessionId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Batch mode — scans join session $_sessionId',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _SubmittingOverlay extends StatefulWidget {
  const _SubmittingOverlay();

  @override
  State<_SubmittingOverlay> createState() => _SubmittingOverlayState();
}

class _SubmittingOverlayState extends State<_SubmittingOverlay> {
  static const _steps = [
    'Reading label on-device…',
    'Extracting mandatory declarations…',
    'Applying Legal Metrology Rules, 2011…',
    'Generating compliance verdict…',
  ];

  int _step = 0;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(milliseconds: 1100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_step < _steps.length - 1) setState(() => _step++);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i <= _step; i++) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i < _step)
                      const Icon(Icons.check_circle, color: Colors.tealAccent, size: 20)
                    else
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                      ),
                    const SizedBox(width: 12),
                    Text(
                      _steps[i],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
                if (i < _steps.length - 1) const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QueuedOverlay extends StatelessWidget {
  const _QueuedOverlay({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_queue, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Saved offline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The scan is queued and will be uploaded automatically '
                'when the backend is reachable.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onDone, child: const Text('OK')),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
