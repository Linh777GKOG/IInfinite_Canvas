import 'dart:math';
import 'package:flutter/material.dart';

class HueRing extends StatelessWidget {
  final HSVColor hsvColor;
  final ValueChanged<double> onHueChanged;

  const HueRing({super.key, required this.hsvColor, required this.onHueChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240, height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: CustomPaint(painter: _HueRingBasePainter()),
          ),
          GestureDetector(
            onPanUpdate: (d) => _handleGesture(d.localPosition),
            onTapDown: (d) => _handleGesture(d.localPosition),
            child: CustomPaint(
              painter: _HueKnobPainter(hsvColor.hue),
            ),
          ),
        ],
      ),
    );
  }

  void _handleGesture(Offset localPosition) {
    final center = const Offset(120, 120);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    double angle = atan2(dy, dx);
    double degree = angle * 180 / pi;
    if (degree < 0) degree += 360;
    onHueChanged(degree);
  }
}

class _HueRingBasePainter extends CustomPainter {
  const _HueRingBasePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const thickness = 30.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      colors: const [
        Colors.red, Colors.yellow, Colors.green, Colors.cyan,
        Colors.blue, Color(0xFFFF00FF), Colors.red
      ],
    );
    final paint = Paint()..shader = gradient.createShader(rect)..style = PaintingStyle.stroke..strokeWidth = thickness;
    canvas.drawCircle(center, radius - thickness / 2, paint);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _HueKnobPainter extends CustomPainter {
  final double hue;
  _HueKnobPainter(this.hue);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const thickness = 30.0;
    final angle = hue * pi / 180;
    final markerPos = Offset(
      center.dx + (radius - thickness / 2) * cos(angle),
      center.dy + (radius - thickness / 2) * sin(angle),
    );
    canvas.drawCircle(markerPos, 9, Paint()..color = Colors.black);
    canvas.drawCircle(markerPos, 7, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant _HueKnobPainter old) => old.hue != hue;
}