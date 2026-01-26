import 'package:flutter/material.dart';

class DrawingSidebar extends StatelessWidget {
  final double currentWidth;
  final double currentOpacity;
  final Color currentColor;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onOpacityChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onColorTap;
  final bool isEraser;
  final VoidCallback onToggleTool;

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
    required this.isEraser,
    required this.onToggleTool,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: 48, // Tăng nhẹ bề ngang để thoáng hơn
      constraints: BoxConstraints(maxHeight: screenHeight * 0.8),
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
            // 1. MÀU SẮC (Có viền bao quanh)
            GestureDetector(
              onTap: onColorTap,
              child: Container(
                padding: const EdgeInsets.all(2), // Viền trắng
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

            const SizedBox(height: 16),

            // 2. CÔNG CỤ (Có nền khi được chọn)
            GestureDetector(
              onTap: onToggleTool,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100, // Nền xám nhẹ làm background
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEraser ? Icons.cleaning_services_rounded : Icons.brush_rounded,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. SLIDERS
            // Size
            const Text("Size", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38)),
            SizedBox(
              height: 100,
              child: RotatedBox(
                  quarterTurns: 3,
                  child: _ModernSlider(value: currentWidth, min: 1, max: 100, onChanged: onWidthChanged)
              ),
            ),

            const SizedBox(height: 8),

            // Opacity
            const Text("Opac", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38)),
            SizedBox(
              height: 100,
              child: RotatedBox(
                  quarterTurns: 3,
                  child: _ModernSlider(value: currentOpacity, min: 0, max: 1, onChanged: onOpacityChanged)
              ),
            ),

            const SizedBox(height: 16),
            const Divider(indent: 10, endIndent: 10, height: 1),
            const SizedBox(height: 12),

            // 4. UNDO / REDO
            Column(
              children: [
                _buildTinyBtn(Icons.undo_rounded, onUndo),
                const SizedBox(height: 8),
                _buildTinyBtn(Icons.redo_rounded, onRedo),
              ],
            )
          ],
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