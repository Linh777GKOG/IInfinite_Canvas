import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

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
    final safeName = fileName.trim().isEmpty
        ? 'download_${DateTime.now().millisecondsSinceEpoch}'
        : fileName;

    final blob = html.Blob(<dynamic>[bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    try {
      final anchor = html.AnchorElement(href: url)
        ..download = safeName
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      return safeName;
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}
