import 'package:flutter/material.dart';
import '../painters/canvas_painters.dart';

class DrawingSettingsModal {
  static void show(
    BuildContext context, {
    required VoidCallback onPickBgColor,
    required GridType currentGridType,
    required Function(GridType) onGridTypeChanged,
  }) {
    // Lưu giá trị hiện tại vào biến cục bộ để cập nhật UI bên trong modal
    GridType selectedGridType = currentGridType;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Canvas Settings",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              const Text("Background",
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  onPickBgColor();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.color_lens_rounded, color: Colors.white70),
                      const SizedBox(width: 12),
                      const Text("Change Background Color",
                          style: TextStyle(color: Colors.white, fontSize: 15)),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text("Grid Style",
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildGridOption(
                      ctx,
                      title: "None",
                      icon: Icons.not_interested_rounded,
                      type: GridType.none,
                      current: selectedGridType,
                      onChanged: (val) {
                        setLocalState(() => selectedGridType = val);
                        onGridTypeChanged(val);
                      },
                    ),
                    _buildGridOption(
                      ctx,
                      title: "Lines",
                      icon: Icons.grid_4x4_rounded,
                      type: GridType.lines,
                      current: selectedGridType,
                      onChanged: (val) {
                        setLocalState(() => selectedGridType = val);
                        onGridTypeChanged(val);
                      },
                    ),
                    _buildGridOption(
                      ctx,
                      title: "Dots",
                      icon: Icons.grain_rounded,
                      type: GridType.dots,
                      current: selectedGridType,
                      onChanged: (val) {
                        setLocalState(() => selectedGridType = val);
                        onGridTypeChanged(val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildGridOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required GridType type,
    required GridType current,
    required Function(GridType) onChanged,
  }) {
    final isSelected = current == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF32C5FF) : Colors.white38,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
