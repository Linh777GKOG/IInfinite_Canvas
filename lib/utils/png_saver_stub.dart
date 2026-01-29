import 'dart:typed_data';

class PngSaverImpl {
  static Future<void> savePngBytes(
    Uint8List bytes, {
    String? fileName,
  }) {
    throw UnsupportedError('PNG saving is not supported on this platform.');
  }
}
