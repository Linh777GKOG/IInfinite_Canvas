import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/drawing_models.dart';

class StorageHelper {
  static const String _kDrawingsMeta = 'drawings_meta_v2';

  static String _docKey(String id) => 'drawing_doc_v2_$id';

  static Future<List<DrawingInfo>> getAllDrawings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kDrawingsMeta);
    if (jsonStr == null) return [];

    final list = jsonDecode(jsonStr) as List<dynamic>;
    final drawings = <DrawingInfo>[];

    for (final item in list) {
      final id = item['id'] as String;
      final name = item['name'] as String;
      final date = DateTime.parse(item['date'] as String);

      Uint8List? thumb;
      final thumbB64 = item['thumb'] as String?;
      if (thumbB64 != null) {
        try {
          thumb = base64Decode(thumbB64);
        } catch (_) {}
      }

      drawings.add(
        DrawingInfo(id: id, name: name, lastModified: date, thumbnail: thumb),
      );
    }

    drawings.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return drawings;
  }

  static Future<void> saveDrawing(
    String id, {
    required DrawingDocument doc,
    required List<int> thumbnailPngBytes,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Save document as JSON (includes base64 images)
    await prefs.setString(
      _docKey(id),
      jsonEncode(doc.toJson(webInlineImages: true)),
    );

    await _updateMetadata(
      id,
      name: name,
      updateDate: true,
      thumbnailPngBytes: thumbnailPngBytes,
    );
  }

  static Future<DrawingDocument?> loadDocument(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_docKey(id));
    if (jsonStr == null) return null;

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DrawingDocument.fromJson(map, webInlineImages: true);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Stroke>> loadDrawing(String id) async {
    final doc = await loadDocument(id);
    return doc?.strokes ?? [];
  }

  static Future<void> renameDrawing(String id, String newName) async {
    await _updateMetadata(id, name: newName, updateDate: false);
  }

  static Future<void> deleteDrawing(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonStr = prefs.getString(_kDrawingsMeta);
    if (jsonStr != null) {
      final list = (jsonDecode(jsonStr) as List<dynamic>);
      list.removeWhere((e) => e['id'] == id);
      await prefs.setString(_kDrawingsMeta, jsonEncode(list));
    }

    await prefs.remove(_docKey(id));
  }

  static Future<String> getDrawingName(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kDrawingsMeta);
    if (jsonStr == null) return 'Untitled Drawing';

    final list = (jsonDecode(jsonStr) as List<dynamic>);
    final match = list.cast<Map<String, dynamic>>().where((e) => e['id'] == id);
    if (match.isEmpty) return 'Untitled Drawing';
    return (match.first['name'] as String?) ?? 'Untitled Drawing';
  }

  static Future<void> _updateMetadata(
    String id, {
    String? name,
    bool updateDate = false,
    List<int>? thumbnailPngBytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kDrawingsMeta);
    final list = jsonStr != null ? (jsonDecode(jsonStr) as List<dynamic>) : <dynamic>[];

    final index = list.indexWhere((e) => e['id'] == id);
    final now = DateTime.now().toIso8601String();

    String? thumbB64;
    if (thumbnailPngBytes != null && thumbnailPngBytes.isNotEmpty) {
      thumbB64 = base64Encode(Uint8List.fromList(thumbnailPngBytes));
    }

    if (index != -1) {
      if (name != null) list[index]['name'] = name;
      if (updateDate) list[index]['date'] = now;
      if (thumbB64 != null) list[index]['thumb'] = thumbB64;
    } else {
      list.add({
        'id': id,
        'name': name ?? 'Untitled Drawing',
        'date': now,
        if (thumbB64 != null) 'thumb': thumbB64,
      });
    }

    await prefs.setString(_kDrawingsMeta, jsonEncode(list));
  }
}
