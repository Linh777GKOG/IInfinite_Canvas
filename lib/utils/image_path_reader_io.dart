import 'dart:io';

class ImagePathReaderImpl {
  static Future<List<int>> readBytes(String path) {
    return File(path).readAsBytes();
  }
}
