import 'dart:math';
import 'package:flutter/material.dart';

class SatValDisc extends StatelessWidget {
  final HSVColor hsvColor;
  final Function(double, double) onSatValChanged;

  const SatValDisc({super.key, required this.hsvColor, required this.onSatValChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160, height: 160,
      child: Stack(
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(160, 160),
              painter: _SatValBasePainter(hsvColor.hue),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (d) => _handleGesture(d.localPosition),
              onTapDown: (d) => _handleGesture(d.localPosition),
              child: CustomPaint(
                painter: _SatValKnobPainter(hsvColor.saturation, hsvColor.value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleGesture(Offset localPosition) {
    double dx = localPosition.dx.clamp(0, 160) / 160;
    double dy = localPosition.dy.clamp(0, 160) / 160;
    onSatValChanged(dx, 1 - dy);
  }
}

class _SatValBasePainter extends CustomPainter {
  final double hue;
  _SatValBasePainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()..addOval(rect);
    canvas.clipPath(path);
    canvas.drawRect(rect, Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor());
    final paintSat = Paint()..shader = const LinearGradient(colors: [Colors.white, Colors.transparent], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(rect);
    canvas.drawRect(rect, paintSat);
    final paintVal = Paint()..shader = const LinearGradient(colors: [Colors.transparent, Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(rect);
    canvas.drawRect(rect, paintVal);
  }
  @override
  bool shouldRepaint(covariant _SatValBasePainter old) => old.hue != hue;
}

class _SatValKnobPainter extends CustomPainter {
  final double sat;
  final double val;
  _SatValKnobPainter(this.sat, this.val);

  @override
  void paint(Canvas canvas, Size size) {
    double x = sat * size.width;
    double y = (1 - val) * size.height;
    final center = Offset(size.width/2, size.height/2);
    final radius = size.width/2;
    final dist = sqrt(pow(x - center.dx, 2) + pow(y - center.dy, 2));
    if (dist > radius) {
      final angle = atan2(y - center.dy, x - center.dx);
      x = center.dx + radius * cos(angle);
      y = center.dy + radius * sin(angle);
    }
    final pWhite = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    final pBlack = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawCircle(Offset(x, y), 8, pBlack);
    canvas.drawCircle(Offset(x, y), 8, pWhite);
  }
  @override
  bool shouldRepaint(covariant _SatValKnobPainter old) => old.sat != sat || old.val != val;
}