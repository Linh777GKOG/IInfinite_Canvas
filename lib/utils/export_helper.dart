import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import '../models/drawing_models.dart';
import '../painters/canvas_painters.dart';

class ExportHelper {
  /// Hàm xử lý toàn bộ logic xuất ảnh
  static Future<void> exportDrawing({
    required BuildContext context,
    required List<Stroke> completedStrokes,
    required Stroke? currentStroke,
    required Color canvasColor,
    required List<ImportedImage> images,
    required Function(bool) onLoadingChanged, // Callback để bật tắt loading
  }) async {
    // 1. Kiểm tra
    if (completedStrokes.isEmpty && currentStroke == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tranh trắng tinh, hãy vẽ gì đó ")));
      return;
    }

    // 2. Hỏi xác nhận
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text("Xuất ảnh", style: TextStyle(color: Colors.white)),
        content: const Text("Lưu tác phẩm vào Thư viện ảnh?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
              child: const Text("Lưu ngay",
                  style: TextStyle(
                      color: Color(0xFF32C5FF), fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirm != true) return;

    // Bật Loading
    onLoadingChanged(true);

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      // --- TÍNH TOÁN BOUNDING BOX ---
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

      final allStrokes = [...completedStrokes];
      if (currentStroke != null) allStrokes.add(currentStroke);

      for (var stroke in allStrokes) {
        for (var point in stroke.points) {
          if (point.dx < minX) minX = point.dx;
          if (point.dy < minY) minY = point.dy;
          if (point.dx > maxX) maxX = point.dx;
          if (point.dy > maxY) maxY = point.dy;
        }
      }

      minX -= 50; minY -= 50; maxX += 50; maxY += 50;
      double width = maxX - minX;
      double height = maxY - minY;

      if (width <= 0 || height <= 0) {
        width = 1080; height = 1920; minX = 0; minY = 0;
      }

      // --- GIỚI HẠN KÍCH THƯỚC ---
      double scaleFactor = 1.0;
      double maxDimension = 4000.0;
      if (width > maxDimension || height > maxDimension) {
        double scaleX = maxDimension / width;
        double scaleY = maxDimension / height;
        scaleFactor = scaleX < scaleY ? scaleX : scaleY;
      }

      int targetWidth = (width * scaleFactor).toInt();
      int targetHeight = (height * scaleFactor).toInt();

      // --- VẼ RA ẢNH ---
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()));

      // Vẽ nền
      canvas.drawRect(
          Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
          Paint()..color = canvasColor);

      canvas.scale(scaleFactor);
      canvas.translate(-minX, -minY);

      final painter = DrawPainter(allStrokes, images);
      painter.paint(canvas, Size(width, height));

      final picture = recorder.endRecording();
      final img = await picture.toImage(targetWidth, targetHeight);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Lưu vào máy
      await Gal.putImageBytes(pngBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Đã lưu ảnh thành công!"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Lỗi lưu: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red));
      }
    } finally {
      // Tắt Loading
      onLoadingChanged(false);
    }
  }
}