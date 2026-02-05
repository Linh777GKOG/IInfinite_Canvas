import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 1. Import Firebase Auth

import '../models/drawing_models.dart';
import '../services/cloud_sync_service.dart';
import '../utils/storage_helper.dart';
import '../utils/favorites_store.dart';
import '../utils/drawing_exchange.dart';
import '../utils/text_file_saver.dart';
import 'draw_page.dart';

enum _GallerySort { modifiedDesc, modifiedAsc, nameAsc, nameDesc }

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<DrawingInfo> drawings = [];
  bool isLoading = true;
  bool _isCloudBusy = false;
  Set<String> _favoriteIds = <String>{};
  String _query = '';
  bool _showFavoritesOnly = false;
  _GallerySort _sort = _GallerySort.modifiedDesc;

  @override
  void initState() {
    super.initState();
    // Hiện lại thanh trạng thái khi ra ngoài sảnh
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _loadFavorites();
    _loadDrawings();
  }

  Future<void> _loadFavorites() async {
    final ids = await FavoritesStore.loadFavoriteIds();
    if (!mounted) return;
    setState(() => _favoriteIds = ids);
  }

  Future<void> _loadDrawings() async {
    final data = await StorageHelper.getAllDrawings();
    if (mounted) {
      setState(() {
        drawings = data;
        isLoading = false;
      });
    }
  }

  List<DrawingInfo> get _visibleDrawings {
    Iterable<DrawingInfo> list = drawings;

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) => d.name.toLowerCase().contains(q));
    }
    if (_showFavoritesOnly) {
      list = list.where((d) => _favoriteIds.contains(d.id));
    }

    final result = list.toList();
    switch (_sort) {
      case _GallerySort.modifiedDesc:
        result.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      case _GallerySort.modifiedAsc:
        result.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        break;
      case _GallerySort.nameAsc:
        result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case _GallerySort.nameDesc:
        result.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
    }

    // Secondary: favorites first (stable-ish UX)
    result.sort((a, b) {
      final af = _favoriteIds.contains(a.id);
      final bf = _favoriteIds.contains(b.id);
      if (af == bf) return 0;
      return af ? -1 : 1;
    });

    return result;
  }

  void _createNewDrawing() {
    final String newId = const Uuid().v4();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DrawPage(drawingId: newId)),
    ).then((_) => _loadDrawings()); // Reload khi quay lại
  }

  void _openDrawing(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DrawPage(drawingId: id)),
    ).then((_) => _loadDrawings()); // Reload khi quay lại
  }

  void _deleteDrawing(String id) async {
    await StorageHelper.deleteDrawing(id);
    _loadDrawings();
  }

  Future<void> _renameDrawing(DrawingInfo info) async {
    final controller = TextEditingController(text: info.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Drawing name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    await StorageHelper.renameDrawing(info.id, newName);
    await _loadDrawings();
  }

  Future<void> _exportDrawingJson(DrawingInfo info) async {
    try {
      final doc = await StorageHelper.loadDocument(info.id);
      if (doc == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy dữ liệu để export.')),
        );
        return;
      }

      DrawingExchangeFile.validateDocSize(doc);

      final jsonText = DrawingExchangeFile.exportToPrettyJson(
        drawingId: info.id,
        name: info.name,
        doc: doc,
      );
      final fileName = DrawingExchangeFile.defaultFileName(info.name);

      final savedTo = await TextFileSaver.saveUtf8Text(
        jsonText,
        fileName: fileName,
        mimeType: 'application/json',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedTo == null || savedTo == fileName
                ? '✅ Đã xuất JSON: $fileName'
                : '✅ Đã lưu JSON: $savedTo',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export lỗi: $e')));
    }
  }

  Future<void> _importDrawingJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import drawing JSON',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      if (picked.bytes == null) {
        throw Exception(
          'Không đọc được file (bytes=null). Hãy thử lại hoặc chọn file nhỏ hơn.',
        );
      }
      final jsonText = utf8.decode(picked.bytes!, allowMalformed: true);

      final exchange = DrawingExchangeFile.parseExchange(jsonText);
      final doc = DrawingExchangeFile.parseDocumentFromJsonString(jsonText);

      // Avoid overwriting: if ID exists, create a new one.
      final existing = await StorageHelper.getAllDrawings();
      final existingIds = existing.map((e) => e.id).toSet();
      final newId = existingIds.contains(exchange.originalId)
          ? const Uuid().v4()
          : exchange.originalId;

      final name = exchange.name.trim().isEmpty
          ? 'Imported Drawing'
          : exchange.name;
      await StorageHelper.saveDrawing(
        newId,
        doc: doc,
        thumbnailPngBytes: const <int>[],
        name: name,
      );

      await _loadDrawings();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Đã import: $name')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import lỗi: $e')));
    }
  }

  Future<void> _runCloudJob(Future<void> Function() job) async {
    if (_isCloudBusy) return;
    setState(() => _isCloudBusy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _isCloudBusy = false);
    }
  }

  Future<void> _cloudBackupAll() async {
    await _runCloudJob(() async {
      final list = List<DrawingInfo>.from(drawings);
      if (list.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có bản vẽ để backup.')),
        );
        return;
      }

      int ok = 0;
      int fail = 0;

      for (final info in list) {
        try {
          final doc = await StorageHelper.loadDocument(info.id);
          if (doc == null) {
            fail++;
            continue;
          }
          await CloudSyncService.uploadDrawing(
            drawingId: info.id,
            name: info.name,
            doc: doc,
            thumbnailPngBytes: info.thumbnail,
          );
          ok++;
        } catch (_) {
          fail++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Backup xong: $ok ok, $fail lỗi')),
      );
    });
  }

  Future<void> _cloudRestoreOne() async {
    await _runCloudJob(() async {
      final cloud = await CloudSyncService.listDrawings();
      if (!mounted) return;

      if (cloud.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud chưa có bản vẽ nào.')),
        );
        return;
      }

      final picked = await showModalBottomSheet<CloudDrawingSummary>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: cloud.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (c, i) {
                final d = cloud[i];
                final date = DateFormat('yyyy-MM-dd HH:mm').format(d.updatedAt);
                return ListTile(
                  leading: Icon(d.hasThumbnail ? Icons.image : Icons.cloud),
                  title: Text(d.name),
                  subtitle: Text(date),
                  onTap: () => Navigator.pop(ctx, d),
                );
              },
            ),
          );
        },
      );

      if (picked == null) return;

      final (jsonText, thumbBytes) = await CloudSyncService.downloadDrawing(
        drawingId: picked.drawingId,
      );

      final exchange = DrawingExchangeFile.parseExchange(jsonText);
      final doc = DrawingExchangeFile.parseDocumentFromJsonString(jsonText);

      final existing = await StorageHelper.getAllDrawings();
      final existingIds = existing.map((e) => e.id).toSet();
      final newId = existingIds.contains(exchange.originalId)
          ? const Uuid().v4()
          : exchange.originalId;

      final name = exchange.name.trim().isEmpty
          ? (picked.name.trim().isEmpty ? 'Imported Drawing' : picked.name)
          : exchange.name;

      await StorageHelper.saveDrawing(
        newId,
        doc: doc,
        thumbnailPngBytes: thumbBytes ?? const <int>[],
        name: name,
      );

      await _loadDrawings();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Đã restore: $name')));
    });
  }

  // 🔥 2. HÀM ĐĂNG XUẤT (Thêm mới)
  Future<void> _signOut() async {
    // Hiện hộp thoại hỏi cho chắc
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Thực hiện đăng xuất
      await FirebaseAuth.instance.signOut();
      // Không cần Navigator.push... vì StreamBuilder ở main.dart sẽ tự lo việc đó
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleDrawings;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Nền xám Concepts
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Drawings",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -1,
                    ),
                  ),

                  // 🔥 3. Cụm nút bấm bên phải (Thêm nút Đăng xuất)
                  Row(
                    children: [
                      IconButton(
                        onPressed: _importDrawingJson,
                        tooltip: 'Import JSON',
                        icon: const Icon(
                          Icons.file_upload_outlined,
                          color: Colors.black87,
                          size: 28,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(
                          () => _showFavoritesOnly = !_showFavoritesOnly,
                        ),
                        tooltip: _showFavoritesOnly
                            ? "Show All"
                            : "Show Favorites",
                        icon: Icon(
                          _showFavoritesOnly ? Icons.star : Icons.star_border,
                          color: Colors.amber[700],
                          size: 28,
                        ),
                      ),
                      PopupMenuButton<_GallerySort>(
                        tooltip: "Sort",
                        initialValue: _sort,
                        onSelected: (v) => setState(() => _sort = v),
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(
                            value: _GallerySort.modifiedDesc,
                            child: Text('Modified (newest)'),
                          ),
                          PopupMenuItem(
                            value: _GallerySort.modifiedAsc,
                            child: Text('Modified (oldest)'),
                          ),
                          PopupMenuItem(
                            value: _GallerySort.nameAsc,
                            child: Text('Name (A → Z)'),
                          ),
                          PopupMenuItem(
                            value: _GallerySort.nameDesc,
                            child: Text('Name (Z → A)'),
                          ),
                        ],
                        child: const Icon(
                          Icons.sort,
                          color: Colors.black87,
                          size: 28,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Cloud sync',
                        enabled: !_isCloudBusy,
                        onSelected: (v) {
                          if (v == 'backup_all') {
                            _cloudBackupAll();
                          } else if (v == 'restore_one') {
                            _cloudRestoreOne();
                          }
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(
                            value: 'backup_all',
                            child: Text('Backup all to cloud'),
                          ),
                          PopupMenuItem(
                            value: 'restore_one',
                            child: Text('Restore from cloud…'),
                          ),
                        ],
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_sync_outlined,
                              color: Colors.black87,
                              size: 28,
                            ),
                            if (_isCloudBusy)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Nút Đăng Xuất
                      IconButton(
                        onPressed: _signOut,
                        tooltip: "Sign Out",
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Nút Cài đặt (Giữ nguyên)
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.black87,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // SEARCH
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search drawings...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => _query = ''),
                          icon: const Icon(Icons.clear),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // 2. GRID DRAWINGS
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : visible.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // 2 cột
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            childAspectRatio: 0.8, // Tỉ lệ khung hình
                          ),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        return _buildDrawingCard(visible[index]);
                      },
                    ),
            ),
          ],
        ),
      ),

      // 3. FLOATING ACTION BUTTON (NÚT +)
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewDrawing,
        backgroundColor: Colors.black,
        elevation: 5,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.brush_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            "Start something new",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingCard(DrawingInfo info) {
    final isFav = _favoriteIds.contains(info.id);
    return GestureDetector(
      onTap: () => _openDrawing(info.id),
      onLongPress: () {
        // Action menu
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(info.name),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _renameDrawing(info);
                },
                child: const Text('Rename'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportDrawingJson(info);
                },
                child: const Text('Export JSON'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteDrawing(info.id);
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // THUMBNAIL
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (info.thumbnail != null)
                      Image.memory(info.thumbnail!, fit: BoxFit.cover)
                    else
                      Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[300],
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white.withOpacity(0.9),
                        shape: const CircleBorder(),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: isFav ? 'Unfavorite' : 'Favorite',
                          onPressed: () async {
                            final next = !isFav;
                            setState(() {
                              if (next) {
                                _favoriteIds.add(info.id);
                              } else {
                                _favoriteIds.remove(info.id);
                              }
                            });
                            await FavoritesStore.setFavorite(info.id, next);
                          },
                          icon: Icon(
                            isFav ? Icons.star : Icons.star_border,
                            color: isFav ? Colors.amber[700] : Colors.black54,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // INFO
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(info.lastModified),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
