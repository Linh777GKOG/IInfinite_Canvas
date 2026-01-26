import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/drawing_models.dart';
import '../utils/storage_helper.dart';
import 'draw_page.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<DrawingInfo> drawings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Hiện lại thanh trạng thái khi ra ngoài sảnh
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _loadDrawings();
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

  @override
  Widget build(BuildContext context) {
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
                  IconButton(
                    onPressed: (){}, // Nút cài đặt giả lập
                    icon: const Icon(Icons.settings_outlined, color: Colors.black87, size: 28),
                  )
                ],
              ),
            ),

            // 2. GRID DRAWINGS
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : drawings.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 cột
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.8, // Tỉ lệ khung hình
                ),
                itemCount: drawings.length,
                itemBuilder: (context, index) {
                  return _buildDrawingCard(drawings[index]);
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
          Text("Start something new", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDrawingCard(DrawingInfo info) {
    return GestureDetector(
      onTap: () => _openDrawing(info.id),
      onLongPress: () {
        // Hỏi xóa khi nhấn giữ
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("Delete Drawing?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            TextButton(onPressed: () { Navigator.pop(ctx); _deleteDrawing(info.id); }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
          ],
        ));
      },
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // THUMBNAIL
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: info.thumbnail != null
                    ? Image.memory(info.thumbnail!, fit: BoxFit.cover)
                    : Container(
                  color: Colors.grey[100],
                  child: Icon(Icons.image_not_supported, color: Colors.grey[300]),
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
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(info.lastModified),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}