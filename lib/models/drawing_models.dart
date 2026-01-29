import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

// 1. ENUM CÔNG CỤ
enum ActiveTool { brush, eraser, hand }

// 2. CLASS NÉT VẼ
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  Stroke(this.points, this.color, this.width, {this.isEraser = false});

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'color': color.value,
      'width': width,
      'isEraser': isEraser,
    };
  }

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List).map((p) => Offset(p['dx'], p['dy'])).toList();
    return Stroke(points, Color(json['color']), json['width'], isEraser: json['isEraser'] ?? false);
  }
}

// 3. CLASS ẢNH CHÈN VÀO
class ImportedImage {
  final ui.Image image;
  final Offset position;
  final double scale;
  final double width;
  final double height;

  ImportedImage({
    required this.image,
    required this.position,
    this.scale = 1.0,
  }) : width = image.width.toDouble(),
        height = image.height.toDouble();
}

// 4. CLASS LAYER
class DrawingLayer {
  String id;
  List<Stroke> strokes;
  List<ImportedImage> images;
  bool isVisible;

  DrawingLayer({
    required this.id,
    required this.strokes,
    List<ImportedImage>? images,
    this.isVisible = true,
  }) : images = images ?? [];
}

// 5. CLASS THÔNG TIN TRANH
class DrawingInfo {
  final String id;
  String name;
  final DateTime lastModified;
  final Uint8List? thumbnail;

  DrawingInfo({required this.id, required this.name, required this.lastModified, this.thumbnail});
}