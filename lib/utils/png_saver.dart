import 'dart:typed_data';

import 'png_saver_stub.dart'
    if (dart.library.html) 'png_saver_web.dart'
    if (dart.library.io) 'png_saver_io.dart';

/// Cross-platform PNG saving utility.
///
/// - Web: triggers a browser download.
/// - Android/iOS/macOS: saves to gallery via `gal`.
/// - Other IO platforms: throws [UnsupportedError].
abstract class PngSaver {
  static Future<void> savePngBytes(
    Uint8List bytes, {
    String? fileName,
  }) {
    return PngSaverImpl.savePngBytes(bytes, fileName: fileName);
  }
}
