import '../models/drawing_models.dart';

abstract class StorageHelperImpl {
  static Future<List<DrawingInfo>> getAllDrawings() {
    throw UnimplementedError();
  }

  static Future<void> saveDrawing(
    String id, {
    required DrawingDocument doc,
    required DrawingInfoUpdate info,
  }) {
    throw UnimplementedError();
  }

  static Future<DrawingDocument?> loadDocument(String id) {
    throw UnimplementedError();
  }

  static Future<void> renameDrawing(String id, String newName) {
    throw UnimplementedError();
  }

  static Future<void> deleteDrawing(String id) {
    throw UnimplementedError();
  }

  static Future<String> getDrawingName(String id) {
    throw UnimplementedError();
  }
}

class DrawingInfoUpdate {
  final String? name;
  final bool updateDate;
  final List<int>? thumbnailPngBytes;

  const DrawingInfoUpdate({
    this.name,
    this.updateDate = false,
    this.thumbnailPngBytes,
  });
}
