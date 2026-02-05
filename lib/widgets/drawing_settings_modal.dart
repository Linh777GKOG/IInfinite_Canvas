import 'package:flutter/material.dart';
import '../painters/canvas_painters.dart'; // Để lấy GridType enum


class DrawingSettingsModal {
  // Hàm hiển thị Bottom Sheet chính
  static void show(
      BuildContext context, {
        required VoidCallback onPickBgColor,
        required GridType currentGridType,
        required Function(GridType) onGridTypeChanged,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.color_lens_outlined, color: Colors.white70),
            title: const Text("Background Color",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              onPickBgColor();
            },
          ),
          const Divider(
              color: Colors.white12, height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.grid_4x4, color: Colors.white70),
            title: const Text("Grid Type", style: TextStyle(color: Colors.white)),
            trailing: Text(currentGridType.name.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(ctx);
              _showGridTypePicker(context, currentGridType, onGridTypeChanged);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Hàm hiển thị Dialog chọn Grid (Private)
  static void _showGridTypePicker(BuildContext context, GridType currentType,
      Function(GridType) onSelected) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF38383A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Select Grid Type",
            style: TextStyle(color: Colors.white, fontSize: 18)),
        children: [
          _buildOption(ctx, "Lines", Icons.grid_4x4, GridType.lines,
              currentType, onSelected),
          _buildOption(ctx, "Dots", Icons.grain, GridType.dots, currentType,
              onSelected),
          _buildOption(ctx, "None", Icons.check_box_outline_blank,
              GridType.none, currentType, onSelected),
        ],
      ),
    );
  }

  static Widget _buildOption(BuildContext ctx, String title, IconData icon,
      GridType type, GridType currentType, Function(GridType) onSelected) {
    final isSelected = currentType == type;
    return SimpleDialogOption(
      onPressed: () {
        onSelected(type);
        Navigator.pop(ctx);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(children: [
          Icon(icon,
              color: isSelected ? const Color(0xFF32C5FF) : Colors.white54,
              size: 20),
          const SizedBox(width: 15),
          Text(title,
              style: TextStyle(
                  color: isSelected ? const Color(0xFF32C5FF) : Colors.white,
                  fontSize: 16)),
          const Spacer(),
          if (isSelected)
            const Icon(Icons.check, color: Color(0xFF32C5FF), size: 20),
        ]),
      ),
    );
  }
}