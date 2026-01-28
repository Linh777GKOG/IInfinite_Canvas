import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/drawing_models.dart';

// 1. Enum định nghĩa kiểu lưới
enum GridType { lines, dots, none }

// 2. Class vẽ nét bút (DrawPainter) - Bị thiếu lúc nãy
class DrawPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<ImportedImage> images;
  final Color? canvasColor; // Màu nền để giả lập tẩy
  final bool isPreview;     // Cờ báo hiệu đang vẽ nháp hay vẽ thật

  DrawPainter(
      this.strokes,
      this.images, {
        this.canvasColor,
        this.isPreview = false, // Mặc định là false (vẽ thật)
      });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Vẽ ảnh trước
    for (var img in images) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(img.position.dx, img.position.dy,
            img.image.width * img.scale, img.image.height * img.scale),
        image: img.image,
        fit: BoxFit.fill,
      );
    }

    // 2. Tạo một Layer mới để xử lý BlendMode.clear chuẩn xác hơn (cho nét đã xong)
    // Lưu ý: Chỉ dùng saveLayer khi không phải preview để tối ưu hiệu năng
    if (!isPreview && strokes.any((s) => s.isEraser)) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    }

    // 3. Vẽ nét bút
    for (final stroke in strokes) {
      final paint = Paint()
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.isEraser) {
        if (isPreview && canvasColor != null) {
          // TRƯỜNG HỢP PREVIEW (ĐANG KÉO):
          // Vẽ màu nền đè lên để che nét cũ -> Tạo cảm giác đang tẩy
          paint.color = canvasColor!;
          paint.blendMode = BlendMode.srcOver;
        } else {
          // TRƯỜNG HỢP VẼ THẬT (ĐÃ THẢ TAY):
          // Đục thủng lớp vẽ để lộ nền bên dưới
          paint.color = Colors.transparent;
          paint.blendMode = BlendMode.clear;
        }
      } else {
        // Nét vẽ thường
        paint.color = stroke.color;
        paint.blendMode = BlendMode.srcOver;
      }

      // (Đoạn vẽ Path giữ nguyên như cũ)
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

    // Restore layer nếu đã save
    if (!isPreview && strokes.any((s) => s.isEraser)) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) => true;
}

// 3. Class vẽ lưới (GridPainter) - Đã sửa lỗi Vector3
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

    // Lấy thông tin ma trận biến đổi
    final Matrix4 matrix = controller.value;
    final double scale = matrix.getMaxScaleOnAxis();

    // Chuyển Vector3 thành Offset
    final translationVector = matrix.getTranslation();
    final Offset translation = Offset(translationVector.x, translationVector.y);

    // Tính toán vùng nhìn thấy (Viewport)
    final Rect viewport = Rect.fromLTWH(
      -translation.dx / scale,
      -translation.dy / scale,
      size.width / scale,
      size.height / scale,
    );

    // Vẽ rộng ra một chút để không bị đứt nét ở rìa
    final Rect drawBounds = viewport.inflate(gridSize);

    final double startX = (drawBounds.left / gridSize).floor() * gridSize;
    final double endX = (drawBounds.right / gridSize).ceil() * gridSize;
    final double startY = (drawBounds.top / gridSize).floor() * gridSize;
    final double endY = (drawBounds.bottom / gridSize).ceil() * gridSize;

    if (gridType == GridType.lines) {
      // Vẽ kẻ ô
      for (double x = startX; x <= endX; x += gridSize) {
        canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
      }
      for (double y = startY; y <= endY; y += gridSize) {
        canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      }
    } else if (gridType == GridType.dots) {
      // Vẽ chấm tròn
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