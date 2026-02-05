import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore {
  static const String _kFavoriteDrawingIds = 'favorite_drawing_ids_v1';

  static Future<Set<String>> loadFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kFavoriteDrawingIds) ?? const <String>[];
    return list.toSet();
  }

  static Future<void> saveFavoriteIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavoriteDrawingIds, ids.toList()..sort());
  }

  static Future<void> setFavorite(String drawingId, bool isFavorite) async {
    final ids = await loadFavoriteIds();
    if (isFavorite) {
      ids.add(drawingId);
    } else {
      ids.remove(drawingId);
    }
    await saveFavoriteIds(ids);
  }
}
