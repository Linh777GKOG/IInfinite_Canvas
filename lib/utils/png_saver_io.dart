import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:gal/gal.dart';

class PngSaverImpl {
  static Future<void> savePngBytes(
    Uint8List bytes, {
    String? fileName,
  }) async {
    // `gal` supports Android/iOS/macOS. It will not work on Windows/Linux.
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      throw UnsupportedError(
        'Saving to gallery is only supported on Android/iOS/macOS for this app. '
        'On web, use the web build to download the PNG.',
      );
    }

    await Gal.putImageBytes(bytes);
  }
}
