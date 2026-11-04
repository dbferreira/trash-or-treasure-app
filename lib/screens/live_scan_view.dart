import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

class LiveScanView extends StatefulWidget {
  final bool isActive;

  const LiveScanView({super.key, required this.isActive});

  @override
  State<LiveScanView> createState() => _LiveScanViewState();
}

class _LiveScanViewState extends State<LiveScanView> {
  CameraController? _controller;
  ObjectDetector? _objectDetector;
  Size? _imageSize;
  List<_ScanBox> _boxes = [];
  DateTime? _lastDetectionTime;
  bool _isDetecting = false;
  bool _isLocked = false;
  bool _isEstimating = false;
  WorkflowResult? _liveResult;
  String _selectedLabel = '';
  Rect? _selectedBox;
  String? _error;

  static const Duration _detectInterval = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _initDetector();
    if (widget.isActive) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _objectDetector?.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LiveScanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initCamera();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopCamera();
    }
  }

  void _initDetector() {
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        classifyObjects: true,
        multipleObjects: true,
        mode: DetectionMode.stream,
      ),
    );
  }

  Future<void> _initCamera() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      setState(() {
        _error = 'Live scan is currently supported on Android only.';
      });
      return;
    }

    if (_controller != null && _controller!.value.isInitialized) {
      if (!_controller!.value.isStreamingImages) {
        await _controller!.startImageStream(_processImage);
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.startImageStream(_processImage);

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Camera failed to start: $error';
      });
    }
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
    if (!mounted) return;
    setState(() {
      _controller = null;
      _boxes = [];
      _selectedLabel = '';
      _isLocked = false;
      _isEstimating = false;
      _liveResult = null;
    });
  }

  Future<void> _processImage(CameraImage image) async {
    if (!widget.isActive) return;
    if (_isDetecting || _isLocked || _isEstimating) return;
    final now = DateTime.now();
    if (_lastDetectionTime != null &&
        now.difference(_lastDetectionTime!) < _detectInterval) {
      return;
    }
    _lastDetectionTime = now;
    _isDetecting = true;

    try {
      final detector = _objectDetector;
      final controller = _controller;
      if (detector == null || controller == null) return;

      final rotation = InputImageRotationValue.fromRawValue(
        controller.description.sensorOrientation,
      );
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (rotation == null || format == null) return;

      final bytes = _concatenatePlanes(image.planes);
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final objects = await detector.processImage(inputImage);
      final rotatedSize = _rotatedSizeFor(imageSize, rotation);
      _handleDetections(objects, rotatedSize);
    } catch (_) {
      // Swallow errors to keep the stream alive.
    } finally {
      _isDetecting = false;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final buffer = WriteBuffer();
    for (final plane in planes) {
      buffer.putUint8List(plane.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  Size _rotatedSizeFor(Size size, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return Size(size.height, size.width);
      default:
        return size;
    }
  }

  void _handleDetections(List<DetectedObject> objects, Size imageSize) {
    if (!mounted) return;

    if (objects.isEmpty) {
      setState(() {
        _imageSize = imageSize;
        _boxes = [];
      });
      return;
    }

    final boxes = objects.map((object) {
      final label = object.labels.isNotEmpty ? object.labels.first.text : 'Object';
      return _ScanBox(rect: object.boundingBox, label: label);
    }).toList();

    Rect? selectedBox;
    if (_selectedBox != null) {
      final selected = boxes
          .map((box) => box.rect)
          .reduce((best, rect) {
            final bestScore = _iou(best, _selectedBox!);
            final rectScore = _iou(rect, _selectedBox!);
            return rectScore > bestScore ? rect : best;
          });
      if (_iou(selected, _selectedBox!) >= 0.5) {
        selectedBox = selected;
      }
    }

    setState(() {
      _imageSize = imageSize;
      _boxes = boxes;
      _selectedBox = selectedBox ?? _selectedBox;
    });
  }

  double _areaOf(Rect rect) => max(1, rect.width * rect.height);

  double _iou(Rect a, Rect b) {
    final left = max(a.left, b.left);
    final top = max(a.top, b.top);
    final right = min(a.right, b.right);
    final bottom = min(a.bottom, b.bottom);
    if (right <= left || bottom <= top) return 0;
    final intersection = (right - left) * (bottom - top);
    final union = _areaOf(a) + _areaOf(b) - intersection;
    return intersection / union;
  }
  Future<void> _lockOnTarget(String? label) async {
    if (_isLocked || _isEstimating) return;
    _isLocked = true;
    _isEstimating = true;
    setState(() {});

    final appState = context.read<AppState>();
    try {
      final controller = _controller;
      if (controller == null) return;
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final photo = await controller.takePicture();
      final result =
          await appState.processImageFile(path: photo.path, description: label);
      if (!mounted) return;
      setState(() {
        _liveResult = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Scan failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEstimating = false;
        });
      }
    }
  }

  Future<void> _resumeScan() async {
    if (!widget.isActive) return;
    final controller = _controller;
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (!controller.value.isStreamingImages) {
      await controller.startImageStream(_processImage);
    }
    setState(() {
      _isLocked = false;
      _isEstimating = false;
      _liveResult = null;
      _selectedLabel = '';
      _selectedBox = null;
      _boxes = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;
    final orientation = MediaQuery.of(context).orientation;

    if (!widget.isActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Live scan is paused. Switch to the Scan tab to activate the camera.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final imageSize = _imageSize;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        Center(
          child: AspectRatio(
            aspectRatio: orientation == Orientation.portrait
                ? (1 / controller.value.aspectRatio)
                : controller.value.aspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final previewSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onTapDown: (details) => _handleTap(
                    details.localPosition,
                    previewSize,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(controller),
                      if (imageSize != null)
                        CustomPaint(
                          painter: _DetectionPainter(
                            boxes: _boxes,
                            selectedBox: _selectedBox,
                            imageSize: imageSize,
                            previewSize: previewSize,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _liveResult != null
                ? _LiveResultOverlay(
                    result: _liveResult!,
                    onResume: _resumeScan,
                  )
                    : _ScanStatusOverlay(
                        label: _selectedLabel,
                        isEstimating: _isEstimating,
                        isLocked: _isLocked,
                      ),
          ),
        ),
      ],
    );
  }

  void _handleTap(Offset position, Size previewSize) {
    if (_isLocked || _isEstimating || _boxes.isEmpty) return;
    final imageSize = _imageSize;
    if (imageSize == null) return;

    final scaleX = previewSize.width / imageSize.width;
    final scaleY = previewSize.height / imageSize.height;

    _ScanBox? selected;
    double selectedArea = double.infinity;
    for (final box in _boxes) {
      final rect = Rect.fromLTRB(
        box.rect.left * scaleX,
        box.rect.top * scaleY,
        box.rect.right * scaleX,
        box.rect.bottom * scaleY,
      );
      if (rect.contains(position)) {
        final area = rect.width * rect.height;
        if (area < selectedArea) {
          selectedArea = area;
          selected = box;
        }
      }
    }

    final chosen = selected;
    if (chosen == null) return;
    setState(() {
      _selectedLabel = chosen.label;
      _selectedBox = chosen.rect;
    });
    final label = chosen.label.trim().isEmpty ? null : chosen.label;
    _lockOnTarget(label);
  }
}

class _ScanBox {
  final Rect rect;
  final String label;

  _ScanBox({required this.rect, required this.label});
}

class _DetectionPainter extends CustomPainter {
  final List<_ScanBox> boxes;
  final Rect? selectedBox;
  final Size imageSize;
  final Size previewSize;

  _DetectionPainter({
    required this.boxes,
    required this.selectedBox,
    required this.imageSize,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = previewSize.width / imageSize.width;
    final scaleY = previewSize.height / imageSize.height;
    final paint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final selectedPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final box in boxes) {
      final rect = Rect.fromLTRB(
        box.rect.left * scaleX,
        box.rect.top * scaleY,
        box.rect.right * scaleX,
        box.rect.bottom * scaleY,
      );
      final isSelected =
          selectedBox != null && _iou(box.rect, selectedBox!) >= 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        isSelected ? selectedPaint : paint,
      );
      _drawLabel(canvas, rect, box.label);
    }
  }

  double _areaOf(Rect rect) => max(1, rect.width * rect.height);

  double _iou(Rect a, Rect b) {
    final left = max(a.left, b.left);
    final top = max(a.top, b.top);
    final right = min(a.right, b.right);
    final bottom = min(a.bottom, b.bottom);
    if (right <= left || bottom <= top) return 0;
    final intersection = (right - left) * (bottom - top);
    final union = _areaOf(a) + _areaOf(b) - intersection;
    return intersection / union;
  }

  void _drawLabel(Canvas canvas, Rect rect, String label) {
    if (label.trim().isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);
    final padding = 6.0;
    final labelRect = Rect.fromLTWH(
      rect.left,
      max(0, rect.top - textPainter.height - padding * 2),
      textPainter.width + padding * 2,
      textPainter.height + padding * 2,
    );
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
      bgPaint,
    );
    textPainter.paint(
      canvas,
      Offset(labelRect.left + padding, labelRect.top + padding),
    );
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.boxes != boxes ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.previewSize != previewSize;
  }
}

class _ScanStatusOverlay extends StatelessWidget {
  final String label;
  final bool isEstimating;
  final bool isLocked;

  const _ScanStatusOverlay({
    required this.label,
    required this.isEstimating,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayLabel = label.isEmpty ? 'Tap an item to search' : label;
    final subtitle = isEstimating
        ? 'Estimating value...'
        : isLocked
            ? 'Locked. Getting estimate...'
            : 'Tap a box to run pricing';

    return Card(
      color: Colors.black.withValues(alpha: 0.6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayLabel,
              style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveResultOverlay extends StatelessWidget {
  final WorkflowResult result;
  final VoidCallback onResume;

  const _LiveResultOverlay({
    required this.result,
    required this.onResume,
  });

  String _formatPrice(String price) {
    if (price.isEmpty) return r'$0';
    if (price.startsWith(r'$')) return price;
    return r'$' + price;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price =
        '${_formatPrice(result.price.low)} — ${_formatPrice(result.price.high)}';

    return Card(
      color: Colors.black.withValues(alpha: 0.7),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.item.name,
              style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.lightBlueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: onResume,
                  child: const Text('Resume Scan'),
                ),
                const SizedBox(width: 8),
                Text(
                  'Added to chat',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
