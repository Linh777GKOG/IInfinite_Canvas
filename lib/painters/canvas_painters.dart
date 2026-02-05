import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/drawing_models.dart';

enum GridType { lines, dots, none }

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
            decoration: t.underline ? TextDecoration.underline : TextDecoration.none,
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
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, baseW, baseH), const Radius.circular(8)),
          bgPaint,
        );
      }
      textPainter.paint(canvas, t.backgroundColor == null ? Offset.zero : Offset(t.padding, t.padding));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  final double gridSize;
  final GridType gridType;
  final Color baseColor;

  GridPainter({
    required this.gridSize,
    required this.gridType,
    required this.baseColor, // Đảm bảo có tham số này
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gridType == GridType.none) return;

    final majorPaint = Paint()
      ..color = baseColor.withOpacity(0.25)
      ..strokeWidth = 1.0;

    final minorPaint = Paint()
      ..color = baseColor.withOpacity(0.1)
      ..strokeWidth = 0.5;

    if (gridType == GridType.lines) {
      for (double x = 0; x <= size.width; x += gridSize / 5) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
      }
      for (double y = 0; y <= size.height; y += gridSize / 5) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
      }
      for (double x = 0; x <= size.width; x += gridSize) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
      }
      for (double y = 0; y <= size.height; y += gridSize) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
      }
    } else if (gridType == GridType.dots) {
      for (double x = 0; x <= size.width; x += gridSize) {
        for (double y = 0; y <= size.height; y += gridSize) {
          canvas.drawCircle(Offset(x, y), 1.2, majorPaint..style = PaintingStyle.fill);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridType != gridType || 
           oldDelegate.gridSize != gridSize ||
           oldDelegate.baseColor != baseColor;
  }
}

class SelectionPainter extends CustomPainter {
  final ImportedImage? selectedImage;
  final CanvasText? selectedText;
  final double viewportScale;

  SelectionPainter({this.selectedImage, this.selectedText, required this.viewportScale});

  @override
  void paint(Canvas canvas, Size size) {
    Rect? rect; Offset? center; double? rotation;
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
        text: TextSpan(text: t.text, style: TextStyle(color: t.color, fontSize: t.fontSize, fontWeight: t.fontWeight, fontFamily: t.fontFamily, fontStyle: t.italic ? FontStyle.italic : FontStyle.normal, decoration: t.underline ? TextDecoration.underline : TextDecoration.none)),
        textAlign: t.align, textDirection: TextDirection.ltr,
      )..layout(maxWidth: t.maxWidth ?? double.infinity);
      final extraPad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      final w = (textPainter.width + extraPad) * t.scale;
      final h = (textPainter.height + extraPad) * t.scale;
      center = Offset(t.position.dx + w / 2, t.position.dy + h / 2);
      rotation = t.rotation;
      rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    }

    if (rect != null && center != null && rotation != null) {
      final framePaint = Paint()..color = Colors.blueAccent.withOpacity(0.9)..style = PaintingStyle.stroke..strokeWidth = (2.0 / viewportScale).clamp(1.0, 3.0);
      final handleRadius = (7.0 / viewportScale).clamp(2.0, 14.0);
      final handleGap = (18.0 / viewportScale).clamp(6.0, 32.0);
      final handleFillPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
      final handleStrokePaint = Paint()..color = Colors.blueAccent.withOpacity(0.95)..style = PaintingStyle.stroke..strokeWidth = (2.0 / viewportScale).clamp(1.0, 3.0);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.drawRect(rect, framePaint);
      final corners = <Offset>[rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
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
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) => true;
}
