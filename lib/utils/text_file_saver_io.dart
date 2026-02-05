import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class TextFileSaverImpl {
  static Future<String?> saveUtf8Text(
    String text, {
    required String fileName,
    String mimeType = 'text/plain',
  }) async {
    return saveBytes(
      Uint8List.fromList(utf8.encode(text)),
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  static Future<String?> saveBytes(
    Uint8List bytes, {
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    // Prefer desktop-style save dialog when available.
    String? path;

    try {
      path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save file',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: _inferExtensions(fileName),
      );
    } catch (_) {
      // Some platforms may throw (e.g., mobile).
      path = null;
    }

    if (path == null || path.trim().isEmpty) {
      // Fallback: store in app documents directory.
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}${Platform.pathSeparator}$fileName';
    }

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }

  static List<String> _inferExtensions(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return const <String>[];
    return <String>[fileName.substring(dot + 1)];
  }
}
