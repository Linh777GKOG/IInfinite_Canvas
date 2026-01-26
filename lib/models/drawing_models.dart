import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Class lưu nét vẽ
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  Stroke(this.points, this.color, this.width, {this.isEraser = false});

  // 1. Chuyển Stroke thành JSON (Map) để lưu
  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'color': color.value,
      'width': width,
      'isEraser': isEraser,
    };
  }

  // 2. Đọc JSON biến lại thành Stroke
  factory Stroke.fromJson(Map<String, dynamic> json) {
    var pointsList = (json['points'] as List).map((p) {
      return Offset(p['dx'], p['dy']);
    }).toList();

    return Stroke(
      pointsList,
      Color(json['color']),
      json['width'],
      isEraser: json['isEraser'] ?? false,
    );
  }
}

class ImportedImage {
  final ui.Image image;
  final Offset position;
  final double scale;
  // Lưu ý: Lưu ảnh import phức tạp hơn (cần lưu đường dẫn file ảnh),
  // bản MVP này tạm thời chưa lưu ảnh import để tránh quá tải code.
  ImportedImage(this.image, this.position, {this.scale = 1.0});
}

class DrawingLayer {
  String id;
  List<Stroke> strokes; // Mỗi layer chứa một danh sách nét vẽ riêng
  bool isVisible;       // Trạng thái ẩn/hiện

  DrawingLayer({
    required this.id,
    required this.strokes,
    this.isVisible = true,
  });
}
class DrawingInfo {
  final String id;
  String name;
  final DateTime lastModified;
  final Uint8List? thumbnail; // Ảnh thu nhỏ để xem trước

  DrawingInfo({
    required this.id,
    required this.name,
    required this.lastModified,
    this.thumbnail,
  });
}