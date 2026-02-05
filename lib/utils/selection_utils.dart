import 'dart:math' as math;
import 'package:flutter/material.dart';

enum TransformHandle { none, scale, rotate }

class SelectionHandles {
  final Offset center;
  final double rotation;
  final double width;
  final double height;
  final double handleRadius;
  final double rotateRadius;
  final double rotateGap;

  const SelectionHandles({
    required this.center,
    required this.rotation,
    required this.width,
    required this.height,
    required this.handleRadius,
    required this.rotateRadius,
    required this.rotateGap,
  });

  TransformHandle hitTest(Offset scenePos) {
    final halfW = width / 2;
    final halfH = height / 2;

    final corners = <Offset>[
      Offset(-halfW, -halfH),
      Offset(halfW, -halfH),
      Offset(halfW, halfH),
      Offset(-halfW, halfH),
    ].map((p) => center + _rotateOffset(p, rotation)).toList();

    final rotHandle = center + _rotateOffset(Offset(0, -halfH - rotateGap), rotation);

    for (final c in corners) {
      if ((scenePos - c).distance <= handleRadius) return TransformHandle.scale;
    }
    if ((scenePos - rotHandle).distance <= rotateRadius) return TransformHandle.rotate;
    return TransformHandle.none;
  }

  static Offset _rotateOffset(Offset p, double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
  }

  static bool isPointInRotatedRect({
    required Offset point,
    required Offset center,
    required double width,
    required double height,
    required double rotation,
  }) {
    final p = point - center;
    final c = math.cos(-rotation);
    final s = math.sin(-rotation);
    final local = Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
    return local.dx.abs() <= width / 2 && local.dy.abs() <= height / 2;
  }
}
