import 'package:flutter/material.dart';

class DrawingToolbar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onImport; // THÊM: Hàm nhập ảnh
  final VoidCallback onSettingsSelect;
  final VoidCallback onRename;
  final String drawingName;
  final String zoomLevel;

  const DrawingToolbar({
    super.key,
    required this.onBack,
    required this.onSave,
    required this.onImport, // Yêu cầu tham số này
    required this.onSettingsSelect,
    required this.onRename,
    required this.drawingName,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.only(left: 4, right: 4, top: 15, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // --- CỤM TRÁI ---
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSquareBtn(Icons.grid_view_rounded, onTap: onBack),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: Colors.black12),
              const SizedBox(width: 8),

              InkWell(
                onTap: onRename,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: SizedBox(
                    width: 120,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            drawingName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: Colors.black26),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // --- CỤM PHẢI ---
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  zoomLevel,
                  style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 12)
              ),
              const SizedBox(width: 12),

              Wrap(
                spacing: 0,
                children: [
                  // NÚT IMPORT ẢNH (Mới)
                  _buildIconBtn(Icons.add_photo_alternate_outlined, onTap: onImport),

                  // NÚT SAVE / EXPORT (Đã trở lại)
                  _buildIconBtn(Icons.download_rounded, onTap: onSave),

                  _buildIconBtn(Icons.settings_outlined, onTap: onSettingsSelect),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: Colors.black87, size: 24),
      ),
    );
  }

  Widget _buildSquareBtn(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))
            ]
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}