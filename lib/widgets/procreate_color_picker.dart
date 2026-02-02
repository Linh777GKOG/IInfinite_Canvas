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

  final historyColors = List.generate(
    24,
        (i) => HSVColor.fromAHSV(1, i * 15.0, 1, 1).toColor(),
  );


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
        width: 320,
        height: 420,
        margin: const EdgeInsets.only(top: 60, right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF323232),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Colors", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white54),
                  )
                ],
              ),
            ),

            // DISC COLOR WHEEL
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. OUTER RING (HUE)
                      HueRing(
                        hsvColor: currentHsv,
                        onHueChanged: (h) => _updateColor(currentHsv.withHue(h)),
                      ),

                      // 2. INNER DISC (SATURATION & BRIGHTNESS)
                      SatValDisc(
                        hsvColor: currentHsv,
                        onSatValChanged: (s, v) => _updateColor(currentHsv.withSaturation(s).withValue(v)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // FOOTER (PREVIEW)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60, height: 40,
                        decoration: BoxDecoration(
                          color: currentHsv.toColor(),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "#${currentHsv.toColor().value.toRadixString(16).toUpperCase().substring(2)}",
                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 40,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, mainAxisSpacing: 8, childAspectRatio: 1),
                      itemCount: historyColors.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _updateColor(HSVColor.fromColor(historyColors[index])),
                          child: Container(
                            decoration: BoxDecoration(
                              color: historyColors[index],
                              borderRadius: BorderRadius.circular(4),
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