import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/models/detection_result.dart';
import 'package:platevision_ai/config/app_config.dart';

/// Renders detection bounding boxes over an image with zoom/pan support.
///
/// Draws color-coded bounding boxes with class labels. Supports tap on
/// individual detections for detail, zoom/pan on the image, and optional
/// filtering by class name.
class DetectionOverlay extends StatefulWidget {
  /// The image provider to display as the base layer.
  final ImageProvider imageProvider;

  /// List of detection results to render as bounding boxes.
  final List<DetectionResult> detections;

  /// Optional filter: only show detections of this class.
  final String? selectedClass;

  /// Callback when a detection bounding box is tapped.
  final ValueChanged<DetectionResult>? onDetectionTap;

  /// Whether to show confidence percentages on labels.
  final bool showConfidence;

  /// Optional semantic label for accessibility.
  final String? semanticLabel;

  const DetectionOverlay({
    super.key,
    required this.imageProvider,
    required this.detections,
    this.selectedClass,
    this.onDetectionTap,
    this.showConfidence = true,
    this.semanticLabel,
  });

  @override
  State<DetectionOverlay> createState() => _DetectionOverlayState();
}

class _DetectionOverlayState extends State<DetectionOverlay> {
  final TransformationController _transformController =
      TransformationController();

  ui.Image? _image;
  bool _imageLoaded = false;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant DetectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _imageLoaded = false;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final newStream =
        widget.imageProvider.resolve(ImageConfiguration.empty);
    if (newStream != _imageStream) {
      _imageListener?.let((listener) {
        _imageStream?.removeListener(listener);
      });
      _imageStream = newStream;
      _imageListener = ImageStreamListener(
        (ImageInfo info, bool _) {
          setState(() {
            _image = info.image;
            _imageLoaded = true;
          });
        },
      );
      _imageStream!.addListener(_imageListener!);
    }
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _transformController.dispose();
    super.dispose();
  }

  List<DetectionResult> get _filteredDetections {
    if (widget.selectedClass == null) return widget.detections;
    return widget.detections
        .where((d) => d.className == widget.selectedClass)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel ?? 'Detection overlay with ${_filteredDetections.length} detections',
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Base image
                Image(
                  image: widget.imageProvider,
                  fit: BoxFit.contain,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),

                // Detection overlay
                if (_imageLoaded && _image != null)
                  Positioned.fill(
                    child: _DetectionCanvas(
                      image: _image!,
                      detections: _filteredDetections,
                      showConfidence: widget.showConfidence,
                      onDetectionTap: widget.onDetectionTap,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter that draws detection bounding boxes over the image area.
class _DetectionCanvas extends StatelessWidget {
  final ui.Image image;
  final List<DetectionResult> detections;
  final bool showConfidence;
  final ValueChanged<DetectionResult>? onDetectionTap;

  const _DetectionCanvas({
    required this.image,
    required this.detections,
    required this.showConfidence,
    this.onDetectionTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DetectionPainter(
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
        detections: detections,
        showConfidence: showConfidence,
      ),
      child: _buildTapAreas(context),
    );
  }

  Widget _buildTapAreas(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
        final fittedSize = _applyBoxFit(
          BoxFit.contain,
          imageSize,
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        final offsetX = (constraints.maxWidth - fittedSize.width) / 2;
        final offsetY = (constraints.maxHeight - fittedSize.height) / 2;
        final scaleX = fittedSize.width / imageSize.width;
        final scaleY = fittedSize.height / imageSize.height;

        return Stack(
          children: detections.map((detection) {
            final rect = Rect.fromLTRB(
              offsetX + detection.boundingBox.left * scaleX,
              offsetY + detection.boundingBox.top * scaleY,
              offsetX + detection.boundingBox.right * scaleX,
              offsetY + detection.boundingBox.bottom * scaleY,
            );

            return Positioned.fromRect(
              rect: rect,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => onDetectionTap?.call(detection),
                child: Container(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Computes the fitted size matching BoxFit behavior.
  Size _applyBoxFit(BoxFit fit, Size input, Size output) {
    if (input.width <= 0 || input.height <= 0) {
      return Size.zero;
    }
    final inputAspect = input.width / input.height;
    final outputAspect = output.width / output.height;

    switch (fit) {
      case BoxFit.contain:
        if (inputAspect > outputAspect) {
          return Size(output.width, output.width / inputAspect);
        } else {
          return Size(output.height * inputAspect, output.height);
        }
      case BoxFit.cover:
        if (inputAspect > outputAspect) {
          return Size(output.height * inputAspect, output.height);
        } else {
          return Size(output.width, output.width / inputAspect);
        }
      default:
        return output;
    }
  }
}

/// Custom painter for drawing bounding boxes and labels.
class _DetectionPainter extends CustomPainter {
  final double imageWidth;
  final double imageHeight;
  final List<DetectionResult> detections;
  final bool showConfidence;

  _DetectionPainter({
    required this.imageWidth,
    required this.imageHeight,
    required this.detections,
    required this.showConfidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    // Calculate the BoxFit.contain transform
    final fittedSize = _applyBoxFit(
      BoxFit.contain,
      Size(imageWidth, imageHeight),
      size,
    );
    final offsetX = (size.width - fittedSize.width) / 2;
    final offsetY = (size.height - fittedSize.height) / 2;
    final scaleX = fittedSize.width / imageWidth;
    final scaleY = fittedSize.height / imageHeight;

    for (final detection in detections) {
      final color = AppColors.getDetectionColor(detection.className);

      // Transform bounding box coordinates
      final rect = Rect.fromLTRB(
        offsetX + detection.boundingBox.left * scaleX,
        offsetY + detection.boundingBox.top * scaleY,
        offsetX + detection.boundingBox.right * scaleX,
        offsetY + detection.boundingBox.bottom * scaleY,
      );

      // Draw bounding box
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSpacing.boundingBoxBorderWidth;

      canvas.drawRect(rect, boxPaint);

      // Draw semi-transparent fill
      final fillPaint = Paint()
        ..color = color.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      // Draw corner accents (top-left, top-right, bottom-left, bottom-right)
      _drawCornerAccent(canvas, rect, color, Corner.topLeft);
      _drawCornerAccent(canvas, rect, color, Corner.topRight);
      _drawCornerAccent(canvas, rect, color, Corner.bottomLeft);
      _drawCornerAccent(canvas, rect, color, Corner.bottomRight);

      // Draw label
      _drawLabel(canvas, rect, detection, color);
    }
  }

  void _drawCornerAccent(Canvas canvas, Rect rect, Color color, Corner corner) {
    final cornerLen = 10.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    double x, y, dx1, dy1, dx2, dy2;
    switch (corner) {
      case Corner.topLeft:
        x = rect.left;
        y = rect.top;
        dx1 = cornerLen;
        dy1 = 0;
        dx2 = 0;
        dy2 = cornerLen;
        break;
      case Corner.topRight:
        x = rect.right;
        y = rect.top;
        dx1 = -cornerLen;
        dy1 = 0;
        dx2 = 0;
        dy2 = cornerLen;
        break;
      case Corner.bottomLeft:
        x = rect.left;
        y = rect.bottom;
        dx1 = cornerLen;
        dy1 = 0;
        dx2 = 0;
        dy2 = -cornerLen;
        break;
      case Corner.bottomRight:
        x = rect.right;
        y = rect.bottom;
        dx1 = -cornerLen;
        dy1 = 0;
        dx2 = 0;
        dy2 = -cornerLen;
        break;
    }

    canvas.drawLine(Offset(x, y), Offset(x + dx1, y + dy1), paint);
    canvas.drawLine(Offset(x, y), Offset(x + dx2, y + dy2), paint);
  }

  void _drawLabel(
    Canvas canvas,
    Rect rect,
    DetectionResult detection,
    Color color,
  ) {
    final classLabel = AppConfig.formatClassName(detection.className);
    final confidenceLabel = showConfidence
        ? ' ${detection.confidenceLabel}'
        : '';
    final text = '$classLabel$confidenceLabel';

    final textSpan = TextSpan(
      text: text,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final labelWidth = textPainter.width + AppSpacing.boundingBoxLabelPaddingH * 2;
    final labelHeight = textPainter.height + AppSpacing.boundingBoxLabelPaddingV * 2;

    // Position label at top-left corner of the bounding box
    final labelOffset = Offset(rect.left, rect.top - labelHeight);

    // Draw label background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelOffset.dx, labelOffset.dy, labelWidth, labelHeight),
      Radius.circular(AppSpacing.boundingBoxLabelRadius),
    );

    canvas.drawRRect(
      bgRect,
      Paint()..color = color.withOpacity(0.85),
    );

    // Draw text
    textPainter.paint(
      canvas,
      Offset(
        labelOffset.dx + AppSpacing.boundingBoxLabelPaddingH,
        labelOffset.dy + AppSpacing.boundingBoxLabelPaddingV,
      ),
    );
  }

  Size _applyBoxFit(BoxFit fit, Size input, Size output) {
    if (input.width <= 0 || input.height <= 0) return Size.zero;
    final inputAspect = input.width / input.height;
    final outputAspect = output.width / output.height;

    switch (fit) {
      case BoxFit.contain:
        if (inputAspect > outputAspect) {
          return Size(output.width, output.width / inputAspect);
        } else {
          return Size(output.height * inputAspect, output.height);
        }
      case BoxFit.cover:
        if (inputAspect > outputAspect) {
          return Size(output.height * inputAspect, output.height);
        } else {
          return Size(output.width, output.width / inputAspect);
        }
      default:
        return output;
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.showConfidence != showConfidence;
  }
}

enum Corner { topLeft, topRight, bottomLeft, bottomRight }

/// Extension to add a `let` utility on nullable types.
extension _NullableLet<T> on T? {
  R? let<R>(R Function(T) fn) {
    final v = this;
    return v == null ? null : fn(v);
  }
}
