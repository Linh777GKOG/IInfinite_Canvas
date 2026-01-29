import 'dart:html' as html;
import 'dart:typed_data';

class PngSaverImpl {
  static Future<void> savePngBytes(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final safeName = (fileName == null || fileName.trim().isEmpty)
        ? 'infinite_canvas_${DateTime.now().millisecondsSinceEpoch}.png'
        : fileName;

    final blob = html.Blob(<dynamic>[bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);

    try {
      final anchor = html.AnchorElement(href: url)
        ..download = safeName
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}
