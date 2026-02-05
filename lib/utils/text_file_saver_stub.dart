import 'dart:typed_data';

class TextFileSaverImpl {
  static Future<String?> saveUtf8Text(
    String text, {
    required String fileName,
    String mimeType = 'text/plain',
  }) async {
    throw UnsupportedError(
      'Text file saving is not supported on this platform.',
    );
  }

  static Future<String?> saveBytes(
    Uint8List bytes, {
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    throw UnsupportedError('File saving is not supported on this platform.');
  }
}
