import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/drawing_models.dart';

// 1. Enum định nghĩa kiểu lưới
enum GridType { lines, dots, none }

// 2. Class vẽ nét bút và ảnh (DrawPainter)
class DrawPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<ImportedImage> images;
  final Color? canvasColor;
  final bool isPreview;

  DrawPainter(
      this.strokes,
      this.images, {
        this.canvasColor,
        this.isPreview = false,
      });

  @override
  void paint(Canvas canvas, Size size) {
    // --- 1. VẼ ẢNH (Nằm dưới cùng) ---
    for (var img in images) {
      final dstRect = Rect.fromLTWH(
        img.position.dx,
        img.position.dy,
        img.width * img.scale,
        img.height * img.scale,
      );

      paintImage(
        canvas: canvas,
        rect: dstRect,
        image: img.image,
        filterQuality: FilterQuality.medium,
        fit: BoxFit.fill,
      );
    }

    // --- 2. VẼ NÉT BÚT ---
    for (final stroke in strokes) {
      final paint = Paint()
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.isEraser) {
        //  LOGIC TẨY AN TOÀN: Tô đè màu nền
        paint.color = canvasColor ?? Colors.white;
        paint.blendMode = BlendMode.srcOver;
      } else {
        // Nét vẽ thường
        paint.color = stroke.color;
        paint.blendMode = BlendMode.srcOver;
      }

      // Nếu chỉ là 1 điểm chấm
      if (stroke.points.length == 1) {
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
        continue;
      }

      // Vẽ đường cong mượt
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
  }

  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) => true;
}

// 3. Class vẽ lưới (GridPainter) - Đã được khôi phục
class GridPainter extends CustomPainter {
  final double gridSize;
  final Color gridColor;
  final TransformationController controller;
  final GridType gridType;

  GridPainter({
    required this.gridSize,
    required this.gridColor,
    required this.controller,
    required this.gridType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gridType == GridType.none) return;

    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Lấy thông tin Zoom/Pan
    final Matrix4 matrix = controller.value;
    final double scale = matrix.getMaxScaleOnAxis();
    final translationVector = matrix.getTranslation();

    // Tính vùng nhìn thấy (Viewport)
    final Rect viewport = Rect.fromLTWH(
      -translationVector.x / scale,
      -translationVector.y / scale,
      size.width / scale,
      size.height / scale,
    );

    final Rect drawBounds = viewport.inflate(gridSize);

    final double startX = (drawBounds.left / gridSize).floor() * gridSize;
    final double endX = (drawBounds.right / gridSize).ceil() * gridSize;
    final double startY = (drawBounds.top / gridSize).floor() * gridSize;
    final double endY = (drawBounds.bottom / gridSize).ceil() * gridSize;

    if (gridType == GridType.lines) {
      for (double x = startX; x <= endX; x += gridSize) {
        canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
      }
      for (double y = startY; y <= endY; y += gridSize) {
        canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      }
    } else if (gridType == GridType.dots) {
      final dotPaint = Paint()
        ..color = gridColor
        ..style = PaintingStyle.fill;

      final double dotRadius = 1.5 / scale.clamp(0.5, 2.0);

      for (double x = startX; x <= endX; x += gridSize) {
        for (double y = startY; y <= endY; y += gridSize) {
          canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.controller != controller ||
        oldDelegate.gridType != gridType;
  }
}