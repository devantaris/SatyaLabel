import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Post-capture step: the user drags a rectangle over the label text so
/// OCR works on a clean, tight crop instead of the whole photo.
///
/// Returns the cropped PNG bytes (or the full photo), or null if cancelled.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _image;
  Uint8List? _originalBytes;
  Rect? _selection;
  Offset? _dragStart;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _originalBytes = data;
        _image = frame.image;
      });
    }
  }

  Future<Uint8List?> _crop(Rect screenSel, double dx, double dy, double scale) async {
    final img = _image!;
    final px = Rect.fromLTRB(
      ((screenSel.left - dx) / scale).clamp(0.0, img.width.toDouble()),
      ((screenSel.top - dy) / scale).clamp(0.0, img.height.toDouble()),
      ((screenSel.right - dx) / scale).clamp(0.0, img.width.toDouble()),
      ((screenSel.bottom - dy) / scale).clamp(0.0, img.height.toDouble()),
    );
    if (px.width < 24 || px.height < 24) return null;
    final w = px.width.round();
    final h = px.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      img,
      px,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = FilterQuality.high,
    );
    final out = await recorder.endRecording().toImage(w, h);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Frame the label'),
        actions: [
          TextButton(
            onPressed: _originalBytes == null
                ? null
                : () => Navigator.pop(context, _originalBytes),
            child: const Text('Use full photo'),
          ),
        ],
      ),
      body: img == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final scale = math.min(
                  constraints.maxWidth / img.width,
                  constraints.maxHeight / img.height,
                );
                final dw = img.width * scale;
                final dh = img.height * scale;
                final dx = (constraints.maxWidth - dw) / 2;
                final dy = (constraints.maxHeight - dh) / 2;
                final imageRect = Rect.fromLTWH(dx, dy, dw, dh);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: (d) {
                          final p = _clamp(d.localPosition, imageRect);
                          setState(() {
                            _dragStart = p;
                            _selection = Rect.fromLTWH(p.dx, p.dy, 0, 0);
                          });
                        },
                        onPanUpdate: (d) {
                          final p = _clamp(d.localPosition, imageRect);
                          if (_dragStart != null) {
                            setState(() {
                              _selection = Rect.fromPoints(_dragStart!, p);
                            });
                          }
                        },
                        child: CustomPaint(
                          painter: _CropPainter(
                            image: img,
                            dst: imageRect,
                            selection: _selection,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    if (_selection != null &&
                        _selection!.width > 24 &&
                        _selection!.height > 24)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => _selection = null),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                ),
                                child: const Text('Redraw'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final sel = _selection!;
                                  final bytes =
                                      await _crop(sel, dx, dy, scale);
                                  if (bytes != null && mounted) {
                                    Navigator.pop(context, bytes);
                                  }
                                },
                                icon: const Icon(Icons.crop_free),
                                label: const Text('Scan this'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_selection == null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Drag a rectangle around the label text for the '
                            'most accurate reading — or use the full photo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Offset _clamp(Offset p, Rect r) => Offset(
        p.dx.clamp(r.left, r.right),
        p.dy.clamp(r.top, r.bottom),
      );
}

class _CropPainter extends CustomPainter {
  _CropPainter({required this.image, required this.dst, required this.selection});

  final ui.Image image;
  final Rect dst;
  final Rect? selection;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final sel = selection;
    if (sel != null) {
      // dim everything outside the selection
      final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
      final full = Offset.zero & size;
      final path = Path()
        ..addRect(full)
        ..addRect(sel)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(path, overlay);
      canvas.drawRect(
        sel,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.tealAccent,
      );
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.selection != selection || old.image != image;
}
