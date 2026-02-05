import 'dart:typed_data';

import 'text_file_saver_stub.dart'
    if (dart.library.html) 'text_file_saver_web.dart'
    if (dart.library.io) 'text_file_saver_io.dart';

/// Cross-platform helper to save/download a text file.
///
/// - Web: triggers a browser download.
/// - Desktop (Windows/macOS/Linux): uses a save dialog.
/// - Mobile: falls back to app documents directory.
abstract class TextFileSaver {
  static Future<String?> saveUtf8Text(
    String text, {
    required String fileName,
    String mimeType = 'application/json',
  }) {
    return TextFileSaverImpl.saveUtf8Text(
      text,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  static Future<String?> saveBytes(
    Uint8List bytes, {
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) {
    return TextFileSaverImpl.saveBytes(
      bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
