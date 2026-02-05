import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/drawing_models.dart';
import '../painters/canvas_painters.dart';
import 'png_saver.dart';

class ExportHelper {
  /// Hàm xử lý toàn bộ logic xuất ảnh
  static Future<void> exportDrawing({
    required BuildContext context,
    required List<Stroke> completedStrokes,
    required Stroke? currentStroke,
    required Color canvasColor,
    required List<ImportedImage> images,
    required List<CanvasText> texts,
    required Function(bool) onLoadingChanged, // Callback để bật tắt loading
  }) async {
    // 1. Kiểm tra
    if (completedStrokes.isEmpty &&
        currentStroke == null &&
        images.isEmpty &&
        texts.isEmpty) {
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

      // Include imported images
      for (final img in images) {
        final w = img.image.width * img.scale;
        final h = img.image.height * img.scale;
        final left = img.position.dx;
        final top = img.position.dy;
        final right = left + w;
        final bottom = top + h;
        if (left < minX) minX = left;
        if (top < minY) minY = top;
        if (right > maxX) maxX = right;
        if (bottom > maxY) maxY = bottom;
      }

      // Include text elements
      for (final t in texts) {
        if (t.text.trim().isEmpty) continue;
        final tp = TextPainter(
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
        final w = (tp.width + extraPad) * t.scale;
        final h = (tp.height + extraPad) * t.scale;
        final left = t.position.dx;
        final top = t.position.dy;
        final right = left + w;
        final bottom = top + h;
        if (left < minX) minX = left;
        if (top < minY) minY = top;
        if (right > maxX) maxX = right;
        if (bottom > maxY) maxY = bottom;
      }

      // If nothing updated (still infinities), fall back to default
      if (minX == double.infinity || minY == double.infinity) {
        minX = 0;
        minY = 0;
        maxX = 1080;
        maxY = 1920;
      }

      minX -= 50;
      minY -= 50;
      maxX += 50;
      maxY += 50;
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

      final painter = DrawPainter(allStrokes, images, texts: texts);
      painter.paint(canvas, Size(width, height));

      final picture = recorder.endRecording();
      final img = await picture.toImage(targetWidth, targetHeight);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

        // Save / download depending on platform
        final fileName =
          'infinite_canvas_${DateTime.now().millisecondsSinceEpoch}.png';
        await PngSaver.savePngBytes(pngBytes, fileName: fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(kIsWeb
                ? "✅ Đã tải ảnh xuống (Downloads)."
                : "✅ Đã lưu ảnh thành công!"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Lỗi lưu: $e");
      if (context.mounted) {
        final message = e is UnsupportedError
            ? "Thiết bị này chưa hỗ trợ lưu vào Thư viện. Hãy chạy trên Android/iOS (hoặc chạy bản Web để tải file)."
            : "Lỗi: $e";
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      // Tắt Loading
      onLoadingChanged(false);
    }
  }
}