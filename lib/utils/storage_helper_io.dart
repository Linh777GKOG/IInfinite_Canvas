import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/drawing_models.dart';

class StorageHelper {
  static const String _kDrawingsMeta = 'drawings_meta_v2';
  static const String _kDrawingsMetaV1 = 'drawings_meta_v1';

  static Future<Directory> _dir() => getApplicationDocumentsDirectory();

  static String _jsonPath(Directory dir, String id) => '${dir.path}/$id.v2.json';
  static String _thumbPath(Directory dir, String id) => '${dir.path}/$id.png';
  static String _imgPath(Directory dir, String drawingId, String imageId) =>
      '${dir.path}/${drawingId}_img_$imageId.bin';

  static Future<List<DrawingInfo>> getAllDrawings() async {
    final prefs = await SharedPreferences.getInstance();
    var jsonStr = prefs.getString(_kDrawingsMeta);

    // Migration: if v2 metadata missing, fall back to v1.
    jsonStr ??= prefs.getString(_kDrawingsMetaV1);
    if (jsonStr == null) return [];

    // If it came from v1, write it to v2 so next run is fast.
    if (prefs.getString(_kDrawingsMeta) == null) {
      await prefs.setString(_kDrawingsMeta, jsonStr);
    }

    final list = jsonDecode(jsonStr) as List<dynamic>;
    final drawings = <DrawingInfo>[];

    final dir = await _dir();

    for (final item in list) {
      final id = item['id'] as String;
      final name = item['name'] as String;
      final date = DateTime.parse(item['date'] as String);

      Uint8List? thumb;
      final file = File(_thumbPath(dir, id));
      if (await file.exists()) {
        try {
          thumb = await file.readAsBytes();
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
    final dir = await _dir();

    // Save images as separate files, then write JSON referencing them.
    final imagesForJson = <ImportedImagePersisted>[];
    for (final img in doc.images) {
      final bytes = img.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final path = _imgPath(dir, id, img.id);
      await File(path).writeAsBytes(bytes, flush: true);
      imagesForJson.add(
        ImportedImagePersisted(
          id: img.id,
          position: img.position,
          scale: img.scale,
          rotation: img.rotation,
          fileRef: path,
          bytes: null,
        ),
      );
    }

    final docForJson = doc.copyWith(images: imagesForJson);
    await File(_jsonPath(dir, id)).writeAsString(
      jsonEncode(docForJson.toJson(webInlineImages: false)),
      flush: true,
    );

    if (thumbnailPngBytes.isNotEmpty) {
      await File(_thumbPath(dir, id)).writeAsBytes(
        Uint8List.fromList(thumbnailPngBytes),
        flush: true,
      );
    }

    await _updateMetadata(id, name: name, updateDate: true);
  }

  static Future<DrawingDocument?> loadDocument(String id) async {
    try {
      final dir = await _dir();
      final file = File(_jsonPath(dir, id));
      if (!await file.exists()) {
        // Back-compat: try v1 strokes-only json
        final v1 = File('${dir.path}/$id.json');
        if (!await v1.exists()) return null;
        final content = await v1.readAsString();
        final list = (jsonDecode(content) as List<dynamic>);
        final strokes = list.map((e) => Stroke.fromJson(e)).toList();
        return DrawingDocument(version: 2, strokes: strokes, texts: [], images: []);
      }

      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      var doc = DrawingDocument.fromJson(map, webInlineImages: false);

      // Load image bytes from files
      final hydrated = <ImportedImagePersisted>[];
      for (final img in doc.images) {
        if (img.fileRef == null) {
          hydrated.add(img);
          continue;
        }
        final f = File(img.fileRef!);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          hydrated.add(img.copyWith(bytes: bytes));
        } else {
          hydrated.add(img);
        }
      }
      doc = doc.copyWith(images: hydrated);
      return doc;
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

    final dir = await _dir();
    final v2 = File(_jsonPath(dir, id));
    final thumb = File(_thumbPath(dir, id));
    if (await v2.exists()) await v2.delete();
    if (await thumb.exists()) await thumb.delete();

    // Best-effort delete image blobs
    final entries = dir.listSync().whereType<File>();
    for (final f in entries) {
      if (f.path.contains('${id}_img_')) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }

    // Back-compat
    final v1 = File('${dir.path}/$id.json');
    if (await v1.exists()) {
      try {
        await v1.delete();
      } catch (_) {}
    }
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kDrawingsMeta);
    final list = jsonStr != null ? (jsonDecode(jsonStr) as List<dynamic>) : <dynamic>[];

    final index = list.indexWhere((e) => e['id'] == id);
    final now = DateTime.now().toIso8601String();

    if (index != -1) {
      if (name != null) list[index]['name'] = name;
      if (updateDate) list[index]['date'] = now;
    } else {
      list.add({
        'id': id,
        'name': name ?? 'Untitled Drawing',
        'date': now,
      });
    }

    await prefs.setString(_kDrawingsMeta, jsonEncode(list));
  }
}
