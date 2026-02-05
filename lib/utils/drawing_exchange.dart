import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/drawing_models.dart';

const String kDrawingExchangeFormat = 'infinitive_canvas_exchange';

class DrawingExchangeFile {
  final int formatVersion;
  final String exportedAt;
  final String originalId;
  final String name;
  final Map<String, dynamic> doc;

  const DrawingExchangeFile({
    required this.formatVersion,
    required this.exportedAt,
    required this.originalId,
    required this.name,
    required this.doc,
  });

  Map<String, dynamic> toJson() {
    return {
      'format': kDrawingExchangeFormat,
      'formatVersion': formatVersion,
      'exportedAt': exportedAt,
      'drawing': {'originalId': originalId, 'name': name, 'doc': doc},
    };
  }

  static DrawingExchangeFile fromJson(Map<String, dynamic> json) {
    if (json['format'] != kDrawingExchangeFormat) {
      throw FormatException('Unknown exchange format');
    }

    final v = (json['formatVersion'] as num?)?.toInt() ?? 1;
    final exportedAt = (json['exportedAt'] as String?) ?? '';

    final drawing = json['drawing'] as Map<String, dynamic>;
    final originalId = (drawing['originalId'] as String?) ?? '';
    final name = (drawing['name'] as String?) ?? 'Untitled Drawing';
    final doc = drawing['doc'] as Map<String, dynamic>;

    return DrawingExchangeFile(
      formatVersion: v,
      exportedAt: exportedAt,
      originalId: originalId,
      name: name,
      doc: doc,
    );
  }

  static String encodePretty(Map<String, dynamic> map) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }

  static String exportToPrettyJson({
    required String drawingId,
    required String name,
    required DrawingDocument doc,
  }) {
    final exchange = DrawingExchangeFile(
      formatVersion: 1,
      exportedAt: DateTime.now().toIso8601String(),
      originalId: drawingId,
      name: name,
      doc: doc.toJson(webInlineImages: true),
    );
    return encodePretty(exchange.toJson());
  }

  static DrawingDocument parseDocumentFromJsonString(String jsonText) {
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final exchange = DrawingExchangeFile.fromJson(decoded);

    // We always export with inline base64 images for portability.
    return DrawingDocument.fromJson(exchange.doc, webInlineImages: true);
  }

  static DrawingExchangeFile parseExchange(String jsonText) {
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    return DrawingExchangeFile.fromJson(decoded);
  }

  static String defaultFileName(String name) {
    final safe = name
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    final base = safe.isEmpty ? 'drawing' : safe;
    return '$base.infinite_canvas.json';
  }

  static void validateDocSize(DrawingDocument doc) {
    // Guard against accidental huge exports that can freeze the UI.
    final strokeCount = doc.strokes.length;
    if (strokeCount > 20000) {
      debugPrint('Large export: $strokeCount strokes');
    }
  }
}
