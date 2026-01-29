import 'package:flutter/material.dart';

class DrawingToolbar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onSettingsSelect;
  final VoidCallback? onAddImage;
  final VoidCallback? onAddText;
  final VoidCallback onRename; //  Hàm gọi khi bấm vào tên
  final String drawingName;    // Tên file hiện tại
  final String zoomLevel;

  const DrawingToolbar({
    super.key,
    required this.onBack,
    required this.onSave,
    required this.onSettingsSelect,
    this.onAddImage,
    this.onAddText,
    required this.onRename,
    required this.drawingName,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
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

                //  Text bấm được
                InkWell(
                  onTap: onRename, // Bấm vào để đổi tên
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                    child: SizedBox(
                      width: 120,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              drawingName, // Hiển thị tên biến truyền vào
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          // Icon bút chì nhỏ để người dùng biết là sửa được
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 12, color: Colors.black26),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // --- CỤM PHẢI  ---
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
                    if (onAddImage != null)
                      _buildIconBtn(Icons.photo_library_outlined,
                          onTap: onAddImage!),
                    if (onAddText != null)
                      _buildIconBtn(Icons.text_fields_rounded,
                          onTap: onAddText!),
                    _buildIconBtn(Icons.download_rounded, onTap: onSave),
                    _buildIconBtn(Icons.settings_outlined, onTap: onSettingsSelect),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: Colors.black87, size: 22),
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