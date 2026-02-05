import 'package:flutter/material.dart';
import 'color_picker_components/hue_ring.dart';
import 'color_picker_components/sat_val_disc.dart';

class ProcreateColorPicker extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;

  const ProcreateColorPicker({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
  });

  @override
  State<ProcreateColorPicker> createState() => _ProcreateColorPickerState();
}

class _ProcreateColorPickerState extends State<ProcreateColorPicker> {
  late HSVColor currentHsv;

  // Bảng màu lấy cảm hứng từ hệ thống Copic của app Concepts
  final List<Color> conceptsPalette = [
    // Grays (Neutral, Cool, Warm)
    const Color(0xFF000000), // Black
    const Color(0xFF4A4A4A), // Cool Gray
    const Color(0xFF8E8E93), // Neutral Gray
    const Color(0xFFD1D1D6), // Light Gray
    const Color(0xFFFFFFFF), // White
    const Color(0xFFE5E5EA), // Warm Gray
    
    // Essential Copic-like Tones
    const Color(0xFFE63946), // Red
    const Color(0xFFF1FAEE), // Soft White
    const Color(0xFFA8DADC), // Light Blue
    const Color(0xFF457B9D), // Steel Blue
    const Color(0xFF1D3557), // Deep Blue
    const Color(0xFFF4A261), // Sand
    const Color(0xFFE9C46A), // Yellow
    const Color(0xFF2A9D8F), // Teal
    const Color(0xFF264653), // Charcoal
    const Color(0xFFBC6C25), // Earth
    const Color(0xFFDDA15E), // Camel
    const Color(0xFF606C38), // Moss
    const Color(0xFF283618), // Dark Green
    const Color(0xFF8338EC), // Violet
    const Color(0xFFFF006E), // Magenta
    const Color(0xFFFB5607), // Orange
    const Color(0xFFFFBE0B), // Gold
    const Color(0xFF3A86FF), // Azure
  ];

  @override
  void initState() {
    super.initState();
    currentHsv = HSVColor.fromColor(widget.currentColor);
  }

  void _updateColor(HSVColor newHsv) {
    setState(() => currentHsv = newHsv);
    widget.onColorChanged(currentHsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      alignment: Alignment.topRight,
      child: Container(
        width: 300,
        height: 520,
        margin: const EdgeInsets.only(top: 60, right: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E), // Gray nền Concepts
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 12)),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: Column(
          children: [
            // HEADER - Tối giản theo Concepts
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 15, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Colors",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 17,
                          letterSpacing: 0.2)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),

            // COLOR WHEEL AREA
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      HueRing(
                        hsvColor: currentHsv,
                        onHueChanged: (h) => _updateColor(currentHsv.withHue(h)),
                      ),
                      SatValDisc(
                        hsvColor: currentHsv,
                        onSatValChanged: (s, v) =>
                            _updateColor(currentHsv.withSaturation(s).withValue(v)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // CONCEPTS PALETTE AREA
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Color Preview & Hex
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: currentHsv.toColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentHsv.toColor().value.toRadixString(16).toUpperCase().substring(2),
                        style: const TextStyle(
                            color: Colors.white38,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Circle Palette (Concepts Style)
                  SizedBox(
                    height: 170, // FIX: Tăng chiều cao để vừa đủ cho 4 hàng màu
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: conceptsPalette.length,
                      itemBuilder: (context, index) {
                        final color = conceptsPalette[index];
                        final isSelected = currentHsv.toColor() == color;
                        return GestureDetector(
                          onTap: () => _updateColor(HSVColor.fromColor(color)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)
                              ] : null,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
