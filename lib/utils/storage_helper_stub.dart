import '../models/drawing_models.dart';

class StorageHelper {
  static Future<List<DrawingInfo>> getAllDrawings() {
    throw UnsupportedError('Storage is not supported on this platform.');
  }

  static Future<void> saveDrawing(
    String id, {
    required DrawingDocument doc,
    required List<int> thumbnailPngBytes,
    String? name,
  }) {
    throw UnsupportedError('Storage is not supported on this platform.');
  }

  static Future<DrawingDocument?> loadDocument(String id) {
    throw UnsupportedError('Storage is not supported on this platform.');
  }

  static Future<List<Stroke>> loadDrawing(String id) async {
    final doc = await loadDocument(id);
    return doc?.strokes ?? [];
  }

  static Future<void> renameDrawing(String id, String newName) {
    throw UnsupportedError('Storage is not supported on this platform.');
  }

  static Future<void> deleteDrawing(String id) {
    throw UnsupportedError('Storage is not supported on this platform.');
  }

  static Future<String> getDrawingName(String id) {
    throw UnsupportedError('Storage is not supported on this platform.');
  }
}
