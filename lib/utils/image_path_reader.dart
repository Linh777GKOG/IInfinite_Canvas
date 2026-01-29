import 'image_path_reader_stub.dart'
    if (dart.library.io) 'image_path_reader_io.dart';

abstract class ImagePathReader {
  static Future<List<int>> readBytes(String path) {
    return ImagePathReaderImpl.readBytes(path);
  }
}
