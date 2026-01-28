import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drawing_models.dart';

class StorageHelper {
  // --- CÁC KHÓA LƯU TRỮ ---
  static const String _kDrawingsMeta = "drawings_meta_v1";

  // 1. LẤY DANH SÁCH TẤT CẢ TRANH
  static Future<List<DrawingInfo>> getAllDrawings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_kDrawingsMeta);

    if (jsonStr == null) return [];

    List<dynamic> list = jsonDecode(jsonStr);
    List<DrawingInfo> drawings = [];

    for (var item in list) {
      final id = item['id'];
      final name = item['name'];
      final date = DateTime.parse(item['date']);

      // Load Thumbnail từ file
      Uint8List? thumb;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$id.png');
        if (await file.exists()) {
          thumb = await file.readAsBytes();
        }
      } catch (e) {
        print("Lỗi load thumb: $e");
      }

      drawings.add(DrawingInfo(id: id, name: name, lastModified: date, thumbnail: thumb));
    }

    // Sắp xếp: Mới nhất lên đầu
    drawings.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return drawings;
  }

  // 2. TẠO HOẶC CẬP NHẬT TRANH
  static Future<void> saveDrawing(String id, List<Stroke> strokes, Uint8List pngBytes, {String? name}) async {
    final dir = await getApplicationDocumentsDirectory();

    // A. Lưu file dữ liệu nét vẽ (JSON)
    final jsonFile = File('${dir.path}/$id.json');
    List<Map<String, dynamic>> strokesList = strokes.map((s) => s.toJson()).toList();
    await jsonFile.writeAsString(jsonEncode(strokesList));

    // B. Lưu file ảnh thumbnail (PNG)
    final pngFile = File('${dir.path}/$id.png');
    await pngFile.writeAsBytes(pngBytes);

    // C. Cập nhật Metadata (Tên & Thời gian)
    await _updateMetadata(id, name: name, updateDate: true);
  }

  // 3. LOAD NÉT VẼ
  static Future<List<Stroke>> loadDrawing(String id) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$id.json');
      if (!await file.exists()) return [];

      String content = await file.readAsString();
      List<dynamic> list = jsonDecode(content);
      return list.map((e) => Stroke.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // 4. ĐỔI TÊN TRANH (Fix lỗi không lưu tên)
  static Future<void> renameDrawing(String id, String newName) async {
    await _updateMetadata(id, name: newName, updateDate: false);
  }

  // 5. XÓA TRANH
  static Future<void> deleteDrawing(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_kDrawingsMeta);
    if (jsonStr == null) return;

    List<dynamic> list = jsonDecode(jsonStr);
    list.removeWhere((item) => item['id'] == id);
    await prefs.setString(_kDrawingsMeta, jsonEncode(list));

    // Xóa file vật lý
    final dir = await getApplicationDocumentsDirectory();
    final f1 = File('${dir.path}/$id.json');
    final f2 = File('${dir.path}/$id.png');
    if (await f1.exists()) await f1.delete();
    if (await f2.exists()) await f2.delete();
  }

  // --- HÀM PHỤ TRỢ: QUẢN LÝ METADATA ---
  static Future<void> _updateMetadata(String id, {String? name, bool updateDate = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_kDrawingsMeta);
    List<dynamic> list = jsonStr != null ? jsonDecode(jsonStr) : [];

    int index = list.indexWhere((item) => item['id'] == id);

    if (index != -1) {
      // Đã tồn tại -> Cập nhật
      if (name != null) list[index]['name'] = name;
      if (updateDate) list[index]['date'] = DateTime.now().toIso8601String();
    } else {
      // Chưa tồn tại -> Tạo mới
      list.add({
        'id': id,
        'name': name ?? "Untitled Drawing",
        'date': DateTime.now().toIso8601String(),
      });
    }

    await prefs.setString(_kDrawingsMeta, jsonEncode(list));
  }

  // Lấy tên hiện tại của tranh
  static Future<String> getDrawingName(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_kDrawingsMeta);
    if (jsonStr == null) return "Untitled Drawing";

    List<dynamic> list = jsonDecode(jsonStr);
    var item = list.firstWhere((e) => e['id'] == id, orElse: () => null);
    return item != null ? item['name'] : "Untitled Drawing";
  }
}
//