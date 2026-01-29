import 'dart:ui' as ui;       //   dùng ui.Image
import 'dart:typed_data';     //  Uint8List (cho thumbnail)
import 'dart:convert';
import 'package:flutter/material.dart'; //   dùng Color, Offset
enum ActiveTool { brush, eraser, hand, image, text }
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
  final String id;
  final ui.Image image;
  final Uint8List? bytes;
  Offset position;
  double scale;
  double rotation;

  ImportedImage({
    required this.id,
    required this.image,
    required this.bytes,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

// 2b. TEXT CHÈN VÀO CANVAS
class CanvasText {
  final String id;
  String text;
  Offset position;
  Color color;
  double fontSize;
  FontWeight fontWeight;
  String? fontFamily;
  bool italic;
  bool underline;
  double rotation;
  double scale;
  TextAlign align;
  double? maxWidth;
  Color? backgroundColor;
  double padding;

  CanvasText({
    required this.id,
    required this.text,
    required this.position,
    required this.color,
    this.fontSize = 32,
    this.fontWeight = FontWeight.w600,
    this.fontFamily,
    this.italic = false,
    this.underline = false,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.align = TextAlign.left,
    this.maxWidth,
    this.backgroundColor,
    this.padding = 8,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'position': {'dx': position.dx, 'dy': position.dy},
      'color': color.value,
      'fontSize': fontSize,
      'fontWeight': fontWeight.index,
      'fontFamily': fontFamily,
      'italic': italic,
      'underline': underline,
      'rotation': rotation,
      'scale': scale,
      'align': align.index,
      'maxWidth': maxWidth,
      'backgroundColor': backgroundColor?.value,
      'padding': padding,
    };
  }

  factory CanvasText.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>;
    final weightIndex = (json['fontWeight'] as num?)?.toInt() ?? FontWeight.w600.index;
    final alignIndex = (json['align'] as num?)?.toInt() ?? TextAlign.left.index;
    return CanvasText(
      id: json['id'] as String,
      text: (json['text'] as String?) ?? '',
      position: Offset((pos['dx'] as num).toDouble(), (pos['dy'] as num).toDouble()),
      color: Color((json['color'] as num).toInt()),
      fontSize: ((json['fontSize'] as num?) ?? 32).toDouble(),
      fontWeight: FontWeight.values[weightIndex.clamp(0, FontWeight.values.length - 1)],
      fontFamily: json['fontFamily'] as String?,
      italic: (json['italic'] as bool?) ?? false,
      underline: (json['underline'] as bool?) ?? false,
      rotation: ((json['rotation'] as num?) ?? 0).toDouble(),
      scale: ((json['scale'] as num?) ?? 1).toDouble(),
      align: TextAlign.values[alignIndex.clamp(0, TextAlign.values.length - 1)],
      maxWidth: (json['maxWidth'] as num?)?.toDouble(),
      backgroundColor: json['backgroundColor'] == null
          ? null
          : Color((json['backgroundColor'] as num).toInt()),
      padding: ((json['padding'] as num?) ?? 8).toDouble(),
    );
  }
}

class ImportedImagePersisted {
  final String id;
  final Offset position;
  final double scale;
  final double rotation;
  final Uint8List? bytes;
  final String? fileRef;

  const ImportedImagePersisted({
    required this.id,
    required this.position,
    required this.scale,
    required this.rotation,
    this.bytes,
    this.fileRef,
  });

  static const Object _unset = Object();

  ImportedImagePersisted copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    Object? bytes = _unset,
    Object? fileRef = _unset,
  }) {
    return ImportedImagePersisted(
      id: id,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      bytes: bytes == _unset ? this.bytes : bytes as Uint8List?,
      fileRef: fileRef == _unset ? this.fileRef : fileRef as String?,
    );
  }

  Map<String, dynamic> toJson({required bool webInlineImages}) {
    return {
      'id': id,
      'position': {'dx': position.dx, 'dy': position.dy},
      'scale': scale,
      'rotation': rotation,
      if (webInlineImages)
        'bytes': bytes == null ? null : base64Encode(bytes!),
      if (!webInlineImages) 'fileRef': fileRef,
    };
  }

  factory ImportedImagePersisted.fromJson(
    Map<String, dynamic> json, {
    required bool webInlineImages,
  }) {
    final pos = json['position'] as Map<String, dynamic>;
    Uint8List? bytes;
    if (webInlineImages) {
      final b64 = json['bytes'] as String?;
      if (b64 != null) {
        try {
          bytes = base64Decode(b64);
        } catch (_) {}
      }
    }
    return ImportedImagePersisted(
      id: json['id'] as String,
      position: Offset((pos['dx'] as num).toDouble(), (pos['dy'] as num).toDouble()),
      scale: ((json['scale'] as num?) ?? 1).toDouble(),
      rotation: ((json['rotation'] as num?) ?? 0).toDouble(),
      bytes: bytes,
      fileRef: webInlineImages ? null : (json['fileRef'] as String?),
    );
  }
}

class DrawingDocument {
  final int version;
  final List<Stroke> strokes;
  final List<CanvasText> texts;
  final List<ImportedImagePersisted> images;

  const DrawingDocument({
    required this.version,
    required this.strokes,
    required this.texts,
    required this.images,
  });

  DrawingDocument copyWith({
    List<Stroke>? strokes,
    List<CanvasText>? texts,
    List<ImportedImagePersisted>? images,
  }) {
    return DrawingDocument(
      version: version,
      strokes: strokes ?? this.strokes,
      texts: texts ?? this.texts,
      images: images ?? this.images,
    );
  }

  Map<String, dynamic> toJson({required bool webInlineImages}) {
    return {
      'version': version,
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'texts': texts.map((t) => t.toJson()).toList(),
      'images': images.map((i) => i.toJson(webInlineImages: webInlineImages)).toList(),
    };
  }

  factory DrawingDocument.fromJson(
    Map<String, dynamic> json, {
    required bool webInlineImages,
  }) {
    final strokesList = (json['strokes'] as List<dynamic>? ?? const [])
        .map((e) => Stroke.fromJson(e as Map<String, dynamic>))
        .toList();
    final textsList = (json['texts'] as List<dynamic>? ?? const [])
        .map((e) => CanvasText.fromJson(e as Map<String, dynamic>))
        .toList();
    final imagesList = (json['images'] as List<dynamic>? ?? const [])
        .map((e) => ImportedImagePersisted.fromJson(
              e as Map<String, dynamic>,
              webInlineImages: webInlineImages,
            ))
        .toList();
    return DrawingDocument(
      version: (json['version'] as num?)?.toInt() ?? 2,
      strokes: strokesList,
      texts: textsList,
      images: imagesList,
    );
  }
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