import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import 'image_path_reader.dart';

class PickedImage {
  final Uint8List bytes;
  final String? name;
  final ui.Image image;

  PickedImage({
    required this.bytes,
    required this.name,
    required this.image,
  });
}

class ImageLoader {
  static Future<PickedImage?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    Uint8List? bytes = file.bytes;

    if (bytes == null && file.path != null) {
      final read = await ImagePathReader.readBytes(file.path!);
      bytes = Uint8List.fromList(read);
    }

    if (bytes == null) return null;

    final img = await _decodeToUiImage(bytes);
    return PickedImage(bytes: bytes, name: file.name, image: img);
  }

  static Future<ui.Image> _decodeToUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<ui.Image> decodeToUiImage(Uint8List bytes) {
    return _decodeToUiImage(bytes);
  }
}
