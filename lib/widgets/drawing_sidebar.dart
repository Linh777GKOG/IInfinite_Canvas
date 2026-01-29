import 'package:flutter/material.dart';
import '../models/drawing_models.dart'; // Nhớ import file model

class DrawingSidebar extends StatelessWidget {
  final double currentWidth;
  final double currentOpacity;
  final Color currentColor;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onOpacityChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onColorTap;

  //  Nhận vào trạng thái công cụ và 2 hàm chọn riêng
  final ActiveTool activeTool;
  final VoidCallback onSelectBrush;
  final VoidCallback onSelectEraser;
  final VoidCallback onSelectHand;
  final VoidCallback onSelectText;

  const DrawingSidebar({
    super.key,
    required this.currentWidth,
    required this.currentOpacity,
    required this.currentColor,
    required this.onWidthChanged,
    required this.onOpacityChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onColorTap,
    required this.activeTool,      // Mới
    required this.onSelectBrush,   // Mới
    required this.onSelectEraser,  // Mới
    required this.onSelectHand,
    required this.onSelectText,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: 48,
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(4, 4))
          ]
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. MÀU SẮC
            GestureDetector(
              onTap: onColorTap,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: currentColor.withOpacity(0.4), blurRadius: 4)],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(indent: 10, endIndent: 10, height: 1),
            const SizedBox(height: 12),

            // 2. CÔNG CỤ: BÚT (BRUSH)
            _buildToolBtn(
                icon: Icons.brush_rounded,
                isActive: activeTool == ActiveTool.brush,
                onTap: onSelectBrush
            ),

            const SizedBox(height: 8),

            // 3. CÔNG CỤ: TẨY (ERASER)
            _buildToolBtn(
                icon: Icons.cleaning_services_rounded, // Hoặc Icons.edit_off_rounded
                isActive: activeTool == ActiveTool.eraser,
                onTap: onSelectEraser
            ),

            const SizedBox(height: 8),

            // 4. CÔNG CỤ: CHỌN / DI CHUYỂN (HAND)
            _buildToolBtn(
              icon: Icons.pan_tool_alt_rounded,
              isActive: activeTool == ActiveTool.hand,
              onTap: onSelectHand
            ),

            const SizedBox(height: 8),

            // 5. CÔNG CỤ: TEXT
            _buildToolBtn(
              icon: Icons.text_fields_rounded,
              isActive: activeTool == ActiveTool.text,
              onTap: onSelectText
            ),

            const SizedBox(height: 16),

            // 6. SLIDERS
            const Text("Size", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38)),
            SizedBox(
              height: 100,
              child: RotatedBox(
                  quarterTurns: 3,
                  child: _ModernSlider(value: currentWidth, min: 1, max: 100, onChanged: onWidthChanged)
              ),
            ),

            const SizedBox(height: 8),

            const Text("Opac", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38)),
            SizedBox(
              height: 100,
              child: RotatedBox(
                  quarterTurns: 3,
                  child: _ModernSlider(value: currentOpacity, min: 0, max: 1, onChanged: onOpacityChanged)
              ),
            ),

            const SizedBox(height: 12),
            const Divider(indent: 10, endIndent: 10, height: 1),
            const SizedBox(height: 12),

            // 7. UNDO / REDO
            _buildTinyBtn(Icons.undo_rounded, onUndo),
            const SizedBox(height: 8),
            _buildTinyBtn(Icons.redo_rounded, onRedo),
          ],
        ),
      ),
    );
  }

  // Widget nút công cụ (Tự động đổi màu khi Active)
  Widget _buildToolBtn({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isActive ? Colors.black87 : Colors.white, // Đen nếu chọn, Trắng nếu không
          shape: BoxShape.circle,
          border: isActive ? null : Border.all(color: Colors.grey.shade200),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.black54, // Icon trắng nếu chọn
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTinyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(icon, size: 20, color: Colors.black54),
      ),
    );
  }
}

class _ModernSlider extends StatelessWidget {
  final double value;
  final double min, max;
  final ValueChanged<double> onChanged;
  const _ModernSlider({required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: Colors.black87,
        inactiveTrackColor: Colors.grey.shade200,
        thumbColor: Colors.black,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 2),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, min: min, max: max, onChanged: onChanged),
    );
  }
}