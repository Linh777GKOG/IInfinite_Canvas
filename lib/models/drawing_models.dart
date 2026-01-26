import 'dart:ui' as ui;       // 🔥 Để dùng ui.Image
import 'dart:typed_data';     // 🔥 Để dùng Uint8List (cho thumbnail)
import 'package:flutter/material.dart'; // 🔥 Để dùng Color, Offset
enum ActiveTool { brush, eraser, hand }
// 1. CLASS NÉT VẼ
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  Stroke(this.points, this.color, this.width, {this.isEraser = false});

  // Chuyển sang JSON để lưu
  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'color': color.value,
      'width': width,
      'isEraser': isEraser,
    };
  }

  // Đọc từ JSON để load lại
  factory Stroke.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List).map((p) {
      return Offset(p['dx'], p['dy']);
    }).toList();

    return Stroke(
      points,
      Color(json['color']),
      json['width'],
      isEraser: json['isEraser'] ?? false,
    );
  }
}

// 2. CLASS ẢNH CHÈN VÀO (Nếu sau này dùng)
class ImportedImage {
  final ui.Image image;
  final Offset position;
  final double scale;

  ImportedImage(this.image, this.position, this.scale);
}

// 3. CLASS LAYER (LỚP VẼ)
class DrawingLayer {
  String id;
  List<Stroke> strokes;
  bool isVisible;

  DrawingLayer({
    required this.id,
    required this.strokes,
    this.isVisible = true,
  });
}

// 4. CLASS THÔNG TIN TRANH (HIỆN NGOÀI SẢNH)
class DrawingInfo {
  final String id;
  String name;
  final DateTime lastModified;
  final Uint8List? thumbnail;

  DrawingInfo({
    required this.id,
    required this.name,
    required this.lastModified,
    this.thumbnail,
  });
}