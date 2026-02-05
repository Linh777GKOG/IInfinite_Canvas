import 'package:flutter/material.dart';

class DrawingToolbar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onSettingsSelect;
  final VoidCallback? onAddImage;
  final VoidCallback? onAddText;
  final VoidCallback onRename;
  final String drawingName;
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
    final shadowColor = Colors.black.withOpacity(0.08);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // --- LEFT BAR: MENU & NAME ---
            Flexible(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIcon(Icons.grid_view_rounded, onTap: onBack),
                    const VerticalDivider(width: 12, thickness: 1, indent: 10, endIndent: 10),
                    Flexible(
                      child: GestureDetector(
                        onTap: onRename,
                        child: Text(
                          drawingName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildIcon(Icons.layers_outlined, onTap: onSettingsSelect, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // --- CENTER: ZOOM ---
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Center(
                child: Text(
                  zoomLevel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // --- RIGHT BAR: ACTIONS ---
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onAddImage != null)
                    _buildIcon(Icons.add_photo_alternate_outlined, onTap: onAddImage!),
                  _buildIcon(Icons.ios_share_rounded, onTap: onSave),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, {required VoidCallback onTap, double size = 22}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: Colors.black87, size: size),
      ),
    );
  }
}
