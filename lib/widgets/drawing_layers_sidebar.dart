import 'package:flutter/material.dart';
import '../models/drawing_models.dart';

class DrawingLayersSidebar extends StatefulWidget {
  final List<DrawingLayer> layers;
  final int activeLayerIndex;
  final VoidCallback onNewLayer;
  final Function(int) onSelectLayer;
  final Function(int) onToggleVisibility;
  final Function(int) onDeleteLayer;

  const DrawingLayersSidebar({
    super.key,
    required this.layers,
    required this.activeLayerIndex,
    required this.onNewLayer,
    required this.onSelectLayer,
    required this.onToggleVisibility,
    required this.onDeleteLayer,
  });

  @override
  State<DrawingLayersSidebar> createState() => _DrawingLayersSidebarState();
}

class _DrawingLayersSidebarState extends State<DrawingLayersSidebar> {
  int? _layerPendingDeleteIndex;

  // BIẾN MỚI: Kiểm soát việc mở rộng hay thu gọn menu
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_layerPendingDeleteIndex != null) {
          setState(() => _layerPendingDeleteIndex = null);
        }
      },
      child: Container(
        width: 120,
        color: Colors.transparent,
        padding: const EdgeInsets.only(top: 0, right: 5, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 1. NÚT TOGGLE CHÍNH (ICON LAYERS)
            GestureDetector(
              // Bấm vào đây để ẨN/HIỆN menu
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: _isExpanded ? BoxDecoration(
                  color: Colors.black.withOpacity(0.05), // Highlight nhẹ khi đang mở
                  shape: BoxShape.circle,
                ) : null,
                child: Icon(
                    Icons.layers_outlined,
                    color: _isExpanded ? Colors.black : Colors.black54,
                    size: 28
                ),
              ),
            ),

            const SizedBox(height: 10),

            // CHỈ HIỆN PHẦN DƯỚI NẾU ĐANG MỞ (_isExpanded == true)
            if (_isExpanded) ...[
              _buildTextAction("Automatic ⇅", onTap: () {}),
              const SizedBox(height: 12),
              _buildTextAction("New Layer +", onTap: widget.onNewLayer),

              const SizedBox(height: 20),

              // Danh sách Layer
              Flexible(
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = widget.layers.length - 1; i >= 0; i--)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildLayerItem(i),
                        )
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTextAction(String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
          textAlign: TextAlign.right,
        ),
      ),
    );
  }

  Widget _buildLayerItem(int index) {
    final layer = widget.layers[index];
    final isActive = index == widget.activeLayerIndex;
    final isPendingDelete = index == _layerPendingDeleteIndex;

    return GestureDetector(
      onTap: () {
        if (_layerPendingDeleteIndex != null) {
          setState(() => _layerPendingDeleteIndex = null);
        } else {
          widget.onSelectLayer(index);
        }
      },
      onLongPress: () {
        setState(() => _layerPendingDeleteIndex = index);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isPendingDelete)
            InkWell(
              onTap: () => widget.onToggleVisibility(index),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  layer.isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: layer.isVisible ? Colors.black87 : Colors.black26,
                ),
              ),
            ),

          if (isPendingDelete)
            InkWell(
              onTap: () {
                widget.onDeleteLayer(index);
                setState(() => _layerPendingDeleteIndex = null);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
              ),
            ),

          Container(
            width: 50,
            height: 35,
            decoration: BoxDecoration(
              color: isPendingDelete ? Colors.red.shade50 : Colors.white,
              border: Border.all(
                color: isPendingDelete
                    ? Colors.red
                    : (isActive ? Colors.black : Colors.black12),
                width: isActive || isPendingDelete ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                "${index + 1}",
                style: TextStyle(
                  fontSize: 10,
                  color: isPendingDelete ? Colors.red : (isActive ? Colors.black : Colors.grey),
                  fontWeight: isPendingDelete ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}