import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/drawing_models.dart';

// 1. Enum định nghĩa kiểu lưới
enum GridType { lines, dots, none }

// 2. Class vẽ nét bút (DrawPainter)
class DrawPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<ImportedImage> images;
  final List<CanvasText> texts;
  final Color? canvasColor;
  final bool isPreview;

  late final bool _hasEraser;

  DrawPainter(
    this.strokes,
    this.images, {
    this.texts = const [],
    this.canvasColor,
    this.isPreview = false,
  }) {
    _hasEraser = !isPreview && strokes.any((s) => s.isEraser);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final img in images) {
      final w = img.image.width * img.scale;
      final h = img.image.height * img.scale;

      canvas.save();
      canvas.translate(img.position.dx + w / 2, img.position.dy + h / 2);
      canvas.rotate(img.rotation);
      canvas.translate(-w / 2, -h / 2);

      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, w, h),
        image: img.image,
        fit: BoxFit.fill,
      );

      canvas.restore();
    }

    if (_hasEraser) {
      canvas.saveLayer(null, Paint());
    }

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      paint.strokeWidth = stroke.width;

      if (stroke.isEraser) {
        if (isPreview && canvasColor != null) {
          paint.color = canvasColor!;
          paint.blendMode = BlendMode.srcOver;
        } else {
          paint.color = Colors.transparent;
          paint.blendMode = BlendMode.clear;
        }
      } else {
        paint.color = stroke.color;
        paint.blendMode = BlendMode.srcOver;
      }

      if (stroke.points.isEmpty) continue;
      if (stroke.points.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke.points, paint);
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i];
        final p1 = stroke.points[i + 1];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);

        if (i == 0) {
          path.lineTo(mid.dx, mid.dy);
        } else {
          path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
        }
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
      canvas.drawPath(path, paint);
    }

    if (_hasEraser) {
      canvas.restore();
    }

    for (final t in texts) {
      if (t.text.trim().isEmpty) continue;

      final textPainter = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: t.color,
            fontSize: t.fontSize,
            fontWeight: t.fontWeight,
            fontFamily: t.fontFamily,
            fontStyle: t.italic ? FontStyle.italic : FontStyle.normal,
            decoration:
                t.underline ? TextDecoration.underline : TextDecoration.none,
          ),
        ),
        textAlign: t.align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: t.maxWidth ?? double.infinity);

      final extraPad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      final baseW = textPainter.width + extraPad;
      final baseH = textPainter.height + extraPad;
      final w = baseW * t.scale;
      final h = baseH * t.scale;

      canvas.save();
      canvas.translate(t.position.dx + w / 2, t.position.dy + h / 2);
      canvas.rotate(t.rotation);
      canvas.scale(t.scale);
      canvas.translate(-baseW / 2, -baseH / 2);

      if (t.backgroundColor != null) {
        final bgPaint = Paint()..color = t.backgroundColor!;
        final rect = Rect.fromLTWH(0, 0, baseW, baseH);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          bgPaint,
        );
      }

      final contentOffset = t.backgroundColor == null
          ? Offset.zero
          : Offset(t.padding, t.padding);
      textPainter.paint(canvas, contentOffset);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length ||
        oldDelegate.strokes != strokes ||
        oldDelegate.images != images ||
        oldDelegate.texts != texts ||
        oldDelegate.canvasColor != canvasColor ||
        oldDelegate.isPreview != isPreview;
  }
}

// 3. Class vẽ lưới (GridPainter) - Đã tối ưu hóa
class GridPainter extends CustomPainter {
  final double gridSize;
  final Color gridColor;
  final GridType gridType;

  GridPainter({
    required this.gridSize,
    required this.gridColor,
    required this.gridType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gridType == GridType.none) return;

    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Vẽ toàn bộ lưới dựa trên kích thước của canvas (size)
    // Vì GridPainter nằm trong InteractiveViewer, nên nó sẽ tự động được scale/translate
    if (gridType == GridType.lines) {
      for (double x = 0; x <= size.width; x += gridSize) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = 0; y <= size.height; y += gridSize) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (gridType == GridType.dots) {
      final dotPaint = Paint()
        ..color = gridColor
        ..style = PaintingStyle.fill;
      
      const double dotRadius = 1.2;

      for (double x = 0; x <= size.width; x += gridSize) {
        for (double y = 0; y <= size.height; y += gridSize) {
          canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridType != gridType ||
        oldDelegate.gridSize != gridSize ||
        oldDelegate.gridColor != gridColor;
  }
}

// 4. Class vẽ khung chọn (SelectionPainter)
class SelectionPainter extends CustomPainter {
  final ImportedImage? selectedImage;
  final CanvasText? selectedText;
  final double viewportScale;

  SelectionPainter({
    this.selectedImage,
    this.selectedText,
    required this.viewportScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Rect? rect;
    Offset? center;
    double? rotation;

    if (selectedImage != null) {
      final img = selectedImage!;
      final w = img.image.width * img.scale;
      final h = img.image.height * img.scale;
      center = Offset(img.position.dx + w / 2, img.position.dy + h / 2);
      rotation = img.rotation;
      rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    } else if (selectedText != null) {
      final t = selectedText!;
      if (t.text.trim().isEmpty) return;
      final textPainter = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: t.color,
            fontSize: t.fontSize,
            fontWeight: t.fontWeight,
            fontFamily: t.fontFamily,
            fontStyle: t.italic ? FontStyle.italic : FontStyle.normal,
            decoration:
                t.underline ? TextDecoration.underline : TextDecoration.none,
          ),
        ),
        textAlign: t.align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: t.maxWidth ?? double.infinity);

      final extraPad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      final baseW = textPainter.width + extraPad;
      final baseH = textPainter.height + extraPad;
      final w = baseW * t.scale;
      final h = baseH * t.scale;
      center = Offset(t.position.dx + w / 2, t.position.dy + h / 2);
      rotation = t.rotation;
      rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    }

    if (rect != null && center != null && rotation != null) {
      _drawSelectionBox(canvas, rect, center, rotation);
    }
  }

  void _drawSelectionBox(
      Canvas canvas, Rect rect, Offset center, double rotation) {
    final framePaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 / viewportScale).clamp(1.0, 3.0);

    final handleRadius = (7.0 / viewportScale).clamp(2.0, 14.0);
    final handleGap = (18.0 / viewportScale).clamp(6.0, 32.0);
    final handleFillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleStrokePaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 / viewportScale).clamp(1.0, 3.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    canvas.drawRect(rect, framePaint);

    final corners = <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    for (final p in corners) {
      canvas.drawCircle(p, handleRadius, handleFillPaint);
      canvas.drawCircle(p, handleRadius, handleStrokePaint);
    }

    final rotateHandlePos = Offset(0, rect.top - handleGap);
    canvas.drawLine(Offset(0, rect.top), rotateHandlePos, handleStrokePaint);
    canvas.drawCircle(rotateHandlePos, handleRadius, handleFillPaint);
    canvas.drawCircle(rotateHandlePos, handleRadius, handleStrokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return oldDelegate.selectedImage != selectedImage ||
        oldDelegate.selectedText != selectedText ||
        oldDelegate.viewportScale != viewportScale;
  }
}
