import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/drawing_models.dart';
import '../painters/canvas_painters.dart';
import '../utils/storage_helper.dart';
import '../utils/image_loader.dart';
import '../utils/selection_utils.dart';
import '../widgets/drawing_settings_modal.dart';
import '../widgets/procreate_color_picker.dart';
import '../widgets/drawing_toolbar.dart';
import '../widgets/drawing_sidebar.dart';
import '../widgets/drawing_layers_sidebar.dart';
import '../widgets/text_editor_dialog.dart'; // Widget mới tách ra

class DrawPage extends StatefulWidget {
  final String drawingId;
  const DrawPage({super.key, required this.drawingId});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

abstract class _EditAction {
  void undo(List<DrawingLayer> layers);
  void redo(List<DrawingLayer> layers);
}

class _AddStrokeAction implements _EditAction {
  final int layerIndex;
  final Stroke stroke;

  _AddStrokeAction({required this.layerIndex, required this.stroke});

  @override
  void undo(List<DrawingLayer> layers) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    final strokes = layers[layerIndex].strokes;
    if (strokes.isEmpty) return;
    if (identical(strokes.last, stroke)) {
      strokes.removeLast();
      return;
    }
    strokes.remove(stroke);
  }

  @override
  void redo(List<DrawingLayer> layers) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    layers[layerIndex].strokes.add(stroke);
  }
}

class _IndexedStroke {
  final int index;
  final Stroke stroke;

  _IndexedStroke(this.index, this.stroke);
}

class _RemoveStrokesAction implements _EditAction {
  final int layerIndex;
  final List<_IndexedStroke> removed;

  _RemoveStrokesAction({required this.layerIndex, required this.removed});

  @override
  void undo(List<DrawingLayer> layers) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    final strokes = layers[layerIndex].strokes;
    final sorted = [...removed]..sort((a, b) => a.index.compareTo(b.index));
    for (final item in sorted) {
      final idx = item.index.clamp(0, strokes.length);
      strokes.insert(idx, item.stroke);
    }
  }

  @override
  void redo(List<DrawingLayer> layers) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    final strokes = layers[layerIndex].strokes;
    for (final item in removed) {
      strokes.remove(item.stroke);
    }
  }
}

class _MoveStrokesAction implements _EditAction {
  final int layerIndex;
  final List<Stroke> strokes;
  final List<List<Offset>> before;
  final List<List<Offset>> after;

  _MoveStrokesAction({
    required this.layerIndex,
    required this.strokes,
    required this.before,
    required this.after,
  });

  void _apply(List<List<Offset>> points) {
    for (int i = 0; i < strokes.length; i++) {
      final s = strokes[i];
      s.points
        ..clear()
        ..addAll(points[i]);
    }
  }

  @override
  void undo(List<DrawingLayer> layers) {
    _apply(before);
  }

  @override
  void redo(List<DrawingLayer> layers) {
    _apply(after);
  }
}

class _DrawPageState extends State<DrawPage> {
  final Uuid _uuid = const Uuid();

  final double canvasWidth = 50000.0;
  final double canvasHeight = 50000.0;

  List<DrawingLayer> layers = [];
  int activeLayerIndex = 0;
  String currentName = "Untitled Drawing";

  final List<_EditAction> _undoActions = [];
  final List<_EditAction> _redoActions = [];
  final List<ImportedImage> images = [];
  final List<CanvasText> texts = [];
  Stroke? currentStroke;

  int? _selectedImageIndex;
  int? _selectedTextIndex;
  bool _isDraggingElement = false;
  Offset? _dragPointerStart;
  Offset? _dragElementStart;

  TransformHandle _activeHandle = TransformHandle.none;
  double? _transformRotationStart;
  double? _transformScaleStart;
  Offset? _transformElementCenter;
  double? _transformStartAngle;
  double? _transformStartDistance;

  final double gridSize = 60.0;
  final Color gridColor = const Color(0xFF32C5FF);
  Color canvasColor = Colors.white;

  List<Offset> currentPoints = [];
  Color currentColor = const Color(0xFF32C5FF);
  double currentWidth = 10;
  double currentOpacity = 1.0;
  ActiveTool activeTool = ActiveTool.brush;
  ShapeType currentShapeType = ShapeType.line;
  double currentScale = 1.0;
  GridType currentGridType = GridType.lines;

  bool isSaving = false;
  bool isInitialLoading = true;

  int _pointerCount = 0;
  int _maxPointerCount = 0;
  bool _isMultitouching = false;
  bool _hasZoomed = false;

  Offset? _shapeStartScene;
  Offset? _shapeCurrentScene;
  bool _isDrawingShape = false;

  bool _isLassoDrawing = false;
  final List<Offset> _lassoPoints = [];
  List<Stroke> _selectedStrokes = [];
  Rect? _selectedStrokesBounds;

  bool _isDraggingStrokes = false;
  Offset? _strokeDragPointerStart;
  Rect? _strokeDragStartBounds;
  List<List<Offset>>? _strokeDragStartPoints;

  final TransformationController controller = TransformationController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    controller.addListener(() {
      final newScale = controller.value.getMaxScaleOnAxis();
      if ((newScale - currentScale).abs() > 0.01)
        setState(() => currentScale = newScale);
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      controller.value = Matrix4.identity()
        ..translate(
          (size.width - canvasWidth) / 2,
          (size.height - canvasHeight) / 2,
        )
        ..scale(1.0);
      setState(() => currentScale = 1.0);
    });
    _initLayers();
    _loadData();
  }

  void _initLayers() {
    if (layers.isEmpty) {
      layers.add(DrawingLayer(id: 'layer_1', strokes: []));
      activeLayerIndex = 0;
    }
  }

  Future<void> _loadData() async {
    try {
      final name = await StorageHelper.getDrawingName(widget.drawingId);
      final doc = await StorageHelper.loadDocument(widget.drawingId);
      if (mounted) {
        final loadedLayers = (doc != null && doc.layers.isNotEmpty)
            ? doc.layers
            : <DrawingLayer>[
                DrawingLayer(
                  id: 'layer_1',
                  strokes: doc?.strokes ?? <Stroke>[],
                ),
              ];
        final loadedTexts = doc?.texts ?? <CanvasText>[];
        final loadedImages = <ImportedImage>[];
        if (doc != null) {
          for (final persisted in doc.images) {
            final bytes = persisted.bytes;
            if (bytes == null || bytes.isEmpty) continue;
            try {
              final uiImage = await ImageLoader.decodeToUiImage(bytes);
              loadedImages.add(
                ImportedImage(
                  id: persisted.id,
                  image: uiImage,
                  bytes: bytes,
                  position: persisted.position,
                  scale: persisted.scale,
                  rotation: persisted.rotation,
                ),
              );
            } catch (_) {}
          }
        }
        setState(() {
          currentName = name;
          layers = loadedLayers;
          if (layers.isEmpty) {
            layers = [DrawingLayer(id: 'layer_1', strokes: [])];
          }
          if (activeLayerIndex >= layers.length) activeLayerIndex = 0;
          images
            ..clear()
            ..addAll(loadedImages);
          texts
            ..clear()
            ..addAll(loadedTexts);
          isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isInitialLoading = false);
    }
  }

  List<ImportedImagePersisted> _buildPersistedImages() {
    return images
        .map(
          (img) => ImportedImagePersisted(
            id: img.id,
            position: img.position,
            scale: img.scale,
            rotation: img.rotation,
            bytes: img.bytes,
            fileRef: null,
          ),
        )
        .toList();
  }

  Future<Uint8List> _generateThumbnailPngBytes() async {
    final strokes = _visibleStrokes;
    final hasContent =
        strokes.isNotEmpty ||
        images.isNotEmpty ||
        texts.any((t) => t.text.trim().isNotEmpty);
    if (!hasContent) return Uint8List(0);

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final stroke in strokes) {
      for (final point in stroke.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
    }

    for (final img in images) {
      final w = img.image.width * img.scale;
      final h = img.image.height * img.scale;
      final left = img.position.dx;
      final top = img.position.dy;
      final right = left + w;
      final bottom = top + h;
      if (left < minX) minX = left;
      if (top < minY) minY = top;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
    }

    for (final t in texts) {
      if (t.text.trim().isEmpty) continue;
      final tp = _layoutTextPainter(t);
      final extraPad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      final w = (tp.width + extraPad) * t.scale;
      final h = (tp.height + extraPad) * t.scale;
      final left = t.position.dx;
      final top = t.position.dy;
      final right = left + w;
      final bottom = top + h;
      if (left < minX) minX = left;
      if (top < minY) minY = top;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
    }

    if (minX == double.infinity || minY == double.infinity) {
      return Uint8List(0);
    }

    const pad = 50.0;
    minX -= pad;
    minY -= pad;
    maxX += pad;
    maxY += pad;
    final width = (maxX - minX).clamp(1.0, 20000.0);
    final height = (maxY - minY).clamp(1.0, 20000.0);

    const targetMax = 512.0;
    final scale = math
        .min(targetMax / width, targetMax / height)
        .clamp(0.01, 1.0);
    final outW = (width * scale).round().clamp(1, 1024);
    final outH = (height * scale).round().clamp(1, 1024);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint()..color = canvasColor,
    );
    canvas.scale(scale);
    canvas.translate(-minX, -minY);

    final painter = DrawPainter(strokes, images, texts: texts);
    painter.paint(canvas, Size(width.toDouble(), height.toDouble()));

    final picture = recorder.endRecording();
    final image = await picture.toImage(outW, outH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List() ?? Uint8List(0);
  }

  Future<void> _saveDocument({bool showToast = true}) async {
    if (isSaving) return;
    setState(() => isSaving = true);
    try {
      final flattenedStrokes = layers.expand((l) => l.strokes).toList();
      final doc = DrawingDocument(
        version: 3,
        strokes: flattenedStrokes,
        layers: layers,
        texts: List<CanvasText>.from(texts),
        images: _buildPersistedImages(),
      );

      final thumb = await _generateThumbnailPngBytes();
      await StorageHelper.saveDrawing(
        widget.drawingId,
        doc: doc,
        thumbnailPngBytes: thumb,
        name: currentName,
      );

      if (showToast && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _renameDrawing() async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Drawing name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    setState(() => currentName = newName);
    await StorageHelper.renameDrawing(widget.drawingId, newName);
  }

  void _addNewLayer() => setState(() {
    layers.add(DrawingLayer(id: 'layer_${layers.length + 1}', strokes: []));
    activeLayerIndex = layers.length - 1;
  });
  void _selectLayer(int index) => setState(() => activeLayerIndex = index);
  void _toggleLayerVisibility(int index) =>
      setState(() => layers[index].isVisible = !layers[index].isVisible);
  void _deleteLayer(int index) {
    if (layers.length <= 1) return;
    setState(() {
      layers.removeAt(index);
      if (activeLayerIndex >= layers.length)
        activeLayerIndex = layers.length - 1;
      else if (index < activeLayerIndex)
        activeLayerIndex--;
    });
    _clearStrokeSelection();
  }

  List<Stroke> get _visibleStrokes => layers
      .where((layer) => layer.isVisible)
      .expand((layer) => layer.strokes)
      .toList();

  Stroke? _buildShapeStroke({required Offset start, required Offset end}) {
    final color = currentColor.withOpacity(currentOpacity);
    final width = currentWidth;

    switch (currentShapeType) {
      case ShapeType.line:
        return Stroke([start, end], color, width);
      case ShapeType.rect:
        final left = math.min(start.dx, end.dx);
        final right = math.max(start.dx, end.dx);
        final top = math.min(start.dy, end.dy);
        final bottom = math.max(start.dy, end.dy);
        return Stroke(
          [
            Offset(left, top),
            Offset(right, top),
            Offset(right, bottom),
            Offset(left, bottom),
            Offset(left, top),
          ],
          color,
          width,
        );
      case ShapeType.circle:
        final cx = (start.dx + end.dx) / 2;
        final cy = (start.dy + end.dy) / 2;
        final rx = (end.dx - start.dx).abs() / 2;
        final ry = (end.dy - start.dy).abs() / 2;
        if (rx <= 0.5 || ry <= 0.5) return Stroke([start, end], color, width);

        const segments = 72;
        final pts = <Offset>[];
        for (int i = 0; i <= segments; i++) {
          final t = (i / segments) * math.pi * 2;
          pts.add(Offset(cx + rx * math.cos(t), cy + ry * math.sin(t)));
        }
        return Stroke(pts, color, width);
    }
  }

  void _beginShape(Offset scenePos) {
    _redoActions.clear();
    _isDrawingShape = true;
    _shapeStartScene = scenePos;
    _shapeCurrentScene = scenePos;
    setState(() {
      currentStroke = _buildShapeStroke(start: scenePos, end: scenePos);
      currentPoints = [];
    });
  }

  void _updateShape(Offset scenePos) {
    if (!_isDrawingShape || _shapeStartScene == null) return;
    _shapeCurrentScene = scenePos;
    final start = _shapeStartScene!;
    setState(() {
      currentStroke = _buildShapeStroke(start: start, end: scenePos);
    });
  }

  void _endShape() {
    if (!_isDrawingShape) return;
    final start = _shapeStartScene;
    final end = _shapeCurrentScene;
    _isDrawingShape = false;
    _shapeStartScene = null;
    _shapeCurrentScene = null;

    if (start == null || end == null) {
      setState(() => currentStroke = null);
      return;
    }

    final stroke = _buildShapeStroke(start: start, end: end);
    if (stroke == null || stroke.points.length < 2) {
      setState(() => currentStroke = null);
      return;
    }

    setState(() {
      layers[activeLayerIndex].strokes.add(stroke);
      _undoActions.add(
        _AddStrokeAction(layerIndex: activeLayerIndex, stroke: stroke),
      );
      _redoActions.clear();
      currentStroke = null;
    });
  }

  void _clearStrokeSelection() {
    _selectedStrokes = [];
    _selectedStrokesBounds = null;
  }

  Rect _boundsOfPoints(List<Offset> pts) {
    double minX = pts.first.dx;
    double minY = pts.first.dy;
    double maxX = pts.first.dx;
    double maxY = pts.first.dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Rect? _strokeBounds(Stroke s) {
    if (s.points.isEmpty) return null;
    return _boundsOfPoints(s.points);
  }

  bool _pointInPolygon(Offset point, List<Offset> poly) {
    if (poly.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;
      final intersects =
          ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx <
              (xj - xi) *
                      (point.dy - yi) /
                      ((yj - yi) == 0 ? 1e-9 : (yj - yi)) +
                  xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  void _beginLasso(Offset scenePos) {
    _isLassoDrawing = true;
    _lassoPoints
      ..clear()
      ..add(scenePos);
    setState(() {
      currentStroke = null;
      currentPoints = [];
      _selectedImageIndex = null;
      _selectedTextIndex = null;
    });
  }

  void _updateLasso(Offset scenePos) {
    if (!_isLassoDrawing) return;
    final last = _lassoPoints.isEmpty ? null : _lassoPoints.last;
    if (last != null && (scenePos - last).distance < 2.0 / currentScale) return;
    setState(() {
      _lassoPoints.add(scenePos);
    });
  }

  void _endLasso() {
    if (!_isLassoDrawing) return;
    _isLassoDrawing = false;
    if (_lassoPoints.length < 3) {
      setState(() {
        _lassoPoints.clear();
      });
      return;
    }

    final poly = List<Offset>.from(_lassoPoints);
    final polyBounds = _boundsOfPoints(poly);

    final strokes = layers[activeLayerIndex].strokes;
    final selected = <Stroke>[];
    Rect? selectedBounds;

    for (final s in strokes) {
      final sb = _strokeBounds(s);
      if (sb == null) continue;
      if (!sb.overlaps(polyBounds)) continue;
      bool hit = false;
      for (final p in s.points) {
        if (_pointInPolygon(p, poly)) {
          hit = true;
          break;
        }
      }
      if (!hit) continue;
      selected.add(s);
      selectedBounds = selectedBounds == null
          ? sb
          : selectedBounds.expandToInclude(sb);
    }

    setState(() {
      _lassoPoints.clear();
      _selectedStrokes = selected;
      _selectedStrokesBounds = selectedBounds;
      activeTool = ActiveTool.hand;
    });
  }

  bool _canBeginStrokeDrag(Offset scenePos) {
    final b = _selectedStrokesBounds;
    return _selectedStrokes.isNotEmpty && b != null && b.contains(scenePos);
  }

  void _beginStrokeDrag(Offset scenePos) {
    _isDraggingStrokes = true;
    _strokeDragPointerStart = scenePos;
    _strokeDragStartBounds = _selectedStrokesBounds;
    _strokeDragStartPoints = _selectedStrokes
        .map((s) => List<Offset>.from(s.points))
        .toList(growable: false);
  }

  void _updateStrokeDrag(Offset scenePos) {
    if (!_isDraggingStrokes || _strokeDragPointerStart == null) return;
    final startPts = _strokeDragStartPoints;
    if (startPts == null) return;
    final delta = scenePos - _strokeDragPointerStart!;
    for (int i = 0; i < _selectedStrokes.length; i++) {
      final newPts = startPts[i].map((p) => p + delta).toList(growable: false);
      _selectedStrokes[i].points
        ..clear()
        ..addAll(newPts);
    }
    setState(() {
      if (_strokeDragStartBounds != null) {
        _selectedStrokesBounds = _strokeDragStartBounds!.shift(delta);
      }
    });
  }

  void _endStrokeDrag() {
    if (!_isDraggingStrokes) return;
    final before = _strokeDragStartPoints;
    if (before == null) {
      _isDraggingStrokes = false;
      _strokeDragPointerStart = null;
      _strokeDragStartBounds = null;
      _strokeDragStartPoints = null;
      return;
    }
    final after = _selectedStrokes
        .map((s) => List<Offset>.from(s.points))
        .toList(growable: false);

    final moved =
        _selectedStrokes.isNotEmpty &&
        before.length == after.length &&
        (() {
          for (int i = 0; i < before.length; i++) {
            if (before[i].length != after[i].length) return true;
            for (int j = 0; j < before[i].length; j++) {
              if (before[i][j] != after[i][j]) return true;
            }
          }
          return false;
        })();

    if (moved) {
      _undoActions.add(
        _MoveStrokesAction(
          layerIndex: activeLayerIndex,
          strokes: List<Stroke>.from(_selectedStrokes),
          before: before,
          after: after,
        ),
      );
      _redoActions.clear();
    }

    _isDraggingStrokes = false;
    _strokeDragPointerStart = null;
    _strokeDragStartBounds = null;
    _strokeDragStartPoints = null;
  }

  Future<void> _chooseShapeType() async {
    final selected = await showModalBottomSheet<ShapeType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget item(ShapeType type, IconData icon, String label) {
          final isActive = currentShapeType == type;
          return ListTile(
            leading: Icon(icon),
            title: Text(label),
            trailing: isActive ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, type),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(ShapeType.line, Icons.show_chart, 'Line'),
              item(ShapeType.rect, Icons.rectangle_outlined, 'Rectangle'),
              item(ShapeType.circle, Icons.circle_outlined, 'Circle'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    setState(() {
      currentShapeType = selected;
      activeTool = ActiveTool.shape;
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount > _maxPointerCount) _maxPointerCount = _pointerCount;
    if (_pointerCount > 1) {
      setState(() {
        _isMultitouching = true;
        currentStroke = null;
        currentPoints = [];
      });
    } else {
      _hasZoomed = false;
      _maxPointerCount = 1;
      final scenePos = controller.toScene(event.localPosition);
      if (activeTool == ActiveTool.shape) {
        setState(() {
          _selectedImageIndex = null;
          _selectedTextIndex = null;
          _clearStrokeSelection();
        });
        if (layers[activeLayerIndex].isVisible) _beginShape(scenePos);
        return;
      }
      if (activeTool == ActiveTool.lasso) {
        _clearStrokeSelection();
        _beginLasso(scenePos);
        return;
      }
      if (activeTool == ActiveTool.hand || activeTool == ActiveTool.text) {
        final handles = _currentSelectionHandles();
        if (handles != null) {
          final handle = handles.hitTest(scenePos);
          if (handle != TransformHandle.none) {
            _beginHandleTransform(handle: handle, pointerScene: scenePos);
            return;
          }
        }
        final hitText = _hitTestText(scenePos);
        if (hitText != null) {
          setState(() {
            _selectedTextIndex = hitText;
            _selectedImageIndex = null;
          });
          if (activeTool == ActiveTool.hand)
            _beginDrag(scenePos, texts[hitText].position);
          else
            _promptAddOrEditText(existingIndex: hitText);
          return;
        }
        final hitImage = _hitTestImage(scenePos);
        if (hitImage != null) {
          setState(() {
            _selectedImageIndex = hitImage;
            _selectedTextIndex = null;
          });
          _beginDrag(scenePos, images[hitImage].position);
          return;
        }
        if (activeTool == ActiveTool.text) {
          setState(() {
            _selectedImageIndex = null;
            _selectedTextIndex = null;
          });
          _promptAddOrEditText(position: scenePos);
          return;
        }

        if (activeTool == ActiveTool.hand && _canBeginStrokeDrag(scenePos)) {
          setState(() {
            _selectedImageIndex = null;
            _selectedTextIndex = null;
          });
          _beginStrokeDrag(scenePos);
          return;
        }

        setState(() {
          _selectedImageIndex = null;
          _selectedTextIndex = null;
          if (_selectedStrokes.isNotEmpty) _clearStrokeSelection();
        });
        return;
      }
      setState(() {
        _selectedImageIndex = null;
        _selectedTextIndex = null;
        if (_selectedStrokes.isNotEmpty) _clearStrokeSelection();
      });
      if (layers[activeLayerIndex].isVisible) startStroke(scenePos);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final scenePos = controller.toScene(event.localPosition);
    if (_activeHandle != TransformHandle.none &&
        !_isMultitouching &&
        _pointerCount == 1) {
      _updateHandleTransform(pointerScene: scenePos);
      return;
    }
    if (_isDraggingElement && !_isMultitouching && _pointerCount == 1) {
      _updateDrag(scenePos);
      return;
    }
    if (_isDraggingStrokes && !_isMultitouching && _pointerCount == 1) {
      _updateStrokeDrag(scenePos);
      return;
    }
    if (!_isMultitouching &&
        _pointerCount == 1 &&
        activeTool == ActiveTool.shape) {
      _updateShape(scenePos);
      return;
    }
    if (!_isMultitouching &&
        _pointerCount == 1 &&
        activeTool == ActiveTool.lasso) {
      _updateLasso(scenePos);
      return;
    }
    if (!_isMultitouching &&
        _pointerCount == 1 &&
        (activeTool == ActiveTool.brush || activeTool == ActiveTool.eraser))
      addPoint(scenePos);
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerCount--;
    if (_pointerCount == 0) {
      if (_activeHandle != TransformHandle.none)
        _endHandleTransform();
      else if (_isDraggingElement)
        _endDrag();
      else if (_isDraggingStrokes)
        _endStrokeDrag();
      else if (activeTool == ActiveTool.shape)
        _endShape();
      else if (activeTool == ActiveTool.lasso)
        _endLasso();
      else if (activeTool == ActiveTool.brush ||
          activeTool == ActiveTool.eraser) {
        if (_maxPointerCount == 2 && !_hasZoomed) {
          undo();
          _showToast("Undo");
        } else if (_maxPointerCount == 3 && !_hasZoomed) {
          redo();
          _showToast("Redo");
        } else
          endStroke();
      }
      setState(() {
        _isMultitouching = false;
        _hasZoomed = false;
        _maxPointerCount = 0;
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount = 0;
    setState(() {
      _isMultitouching = false;
      currentStroke = null;
      _isDrawingShape = false;
      _shapeStartScene = null;
      _shapeCurrentScene = null;
      _isLassoDrawing = false;
      _lassoPoints.clear();
      _isDraggingStrokes = false;
      _strokeDragPointerStart = null;
      _strokeDragStartBounds = null;
      _strokeDragStartPoints = null;
      _endHandleTransform();
      _endDrag();
    });
  }

  void _beginHandleTransform({
    required TransformHandle handle,
    required Offset pointerScene,
  }) {
    final handles = _currentSelectionHandles();
    if (handles == null) return;
    setState(() {
      _activeHandle = handle;
      _transformElementCenter = handles.center;
    });
    if (handle == TransformHandle.rotate) {
      _transformStartAngle = math.atan2(
        pointerScene.dy - handles.center.dy,
        pointerScene.dx - handles.center.dx,
      );
      _transformRotationStart = _selectedImageIndex != null
          ? images[_selectedImageIndex!].rotation
          : texts[_selectedTextIndex!].rotation;
    } else if (handle == TransformHandle.scale) {
      _transformStartDistance = (pointerScene - handles.center).distance;
      _transformScaleStart = _selectedImageIndex != null
          ? images[_selectedImageIndex!].scale
          : texts[_selectedTextIndex!].scale;
    }
  }

  void _updateHandleTransform({required Offset pointerScene}) {
    final center = _transformElementCenter;
    if (_activeHandle == TransformHandle.none || center == null) return;
    if (_activeHandle == TransformHandle.rotate) {
      final currentAngle = math.atan2(
        pointerScene.dy - center.dy,
        pointerScene.dx - center.dx,
      );
      final newRot =
          _transformRotationStart! + (currentAngle - _transformStartAngle!);
      setState(() {
        if (_selectedImageIndex != null)
          images[_selectedImageIndex!].rotation = newRot;
        else
          texts[_selectedTextIndex!].rotation = newRot;
      });
    } else if (_activeHandle == TransformHandle.scale) {
      final factor =
          (pointerScene - center).distance / _transformStartDistance!;
      final newScale = (_transformScaleStart! * factor).clamp(0.05, 50.0);
      setState(() {
        if (_selectedImageIndex != null) {
          final img = images[_selectedImageIndex!];
          img.scale = newScale;
          img.position =
              center -
              Offset(
                (img.image.width * img.scale) / 2,
                (img.image.height * img.scale) / 2,
              );
        } else {
          final t = texts[_selectedTextIndex!];
          t.scale = newScale;
          final tp = _layoutTextPainter(t);
          final pad = t.backgroundColor == null ? 0.0 : t.padding * 2;
          t.position =
              center -
              Offset(
                ((tp.width + pad) * t.scale) / 2,
                ((tp.height + pad) * t.scale) / 2,
              );
        }
      });
    }
  }

  void _endHandleTransform() {
    _activeHandle = TransformHandle.none;
    _transformRotationStart = _transformScaleStart = _transformElementCenter =
        _transformStartAngle = _transformStartDistance = null;
  }

  void _beginDrag(Offset p, Offset el) => setState(() {
    _isDraggingElement = true;
    _dragPointerStart = p;
    _dragElementStart = el;
  });
  void _updateDrag(Offset p) => setState(() {
    if (_selectedImageIndex != null)
      images[_selectedImageIndex!].position =
          _dragElementStart! + (p - _dragPointerStart!);
    else
      texts[_selectedTextIndex!].position =
          _dragElementStart! + (p - _dragPointerStart!);
  });
  void _endDrag() {
    _isDraggingElement = false;
    _dragPointerStart = _dragElementStart = null;
  }

  TextPainter _layoutTextPainter(CanvasText t) => TextPainter(
    text: TextSpan(
      text: t.text,
      style: TextStyle(
        color: t.color,
        fontSize: t.fontSize,
        fontWeight: t.fontWeight,
        fontFamily: t.fontFamily,
        fontStyle: t.italic ? FontStyle.italic : FontStyle.normal,
        decoration: t.underline
            ? TextDecoration.underline
            : TextDecoration.none,
      ),
    ),
    textAlign: t.align,
    textDirection: ui.TextDirection.ltr,
  )..layout(maxWidth: t.maxWidth ?? double.infinity);

  SelectionHandles? _currentSelectionHandles() {
    if (_selectedImageIndex == null && _selectedTextIndex == null) return null;
    double w, h, rot;
    Offset pos;
    if (_selectedImageIndex != null) {
      final img = images[_selectedImageIndex!];
      w = img.image.width * img.scale;
      h = img.image.height * img.scale;
      rot = img.rotation;
      pos = img.position;
    } else {
      final t = texts[_selectedTextIndex!];
      final tp = _layoutTextPainter(t);
      final pad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      w = (tp.width + pad) * t.scale;
      h = (tp.height + pad) * t.scale;
      rot = t.rotation;
      pos = t.position;
    }
    return SelectionHandles(
      center: pos + Offset(w / 2, h / 2),
      rotation: rot,
      width: w,
      height: h,
      handleRadius: 10.0 / currentScale,
      rotateRadius: 10.0 / currentScale,
      rotateGap: 28.0 / currentScale,
    );
  }

  int? _hitTestImage(Offset p) {
    for (int i = images.length - 1; i >= 0; i--) {
      final img = images[i];
      if (SelectionHandles.isPointInRotatedRect(
        point: p,
        center:
            img.position +
            Offset(
              (img.image.width * img.scale) / 2,
              (img.image.height * img.scale) / 2,
            ),
        width: img.image.width * img.scale,
        height: img.image.height * img.scale,
        rotation: img.rotation,
      ))
        return i;
    }
    return null;
  }

  int? _hitTestText(Offset p) {
    for (int i = texts.length - 1; i >= 0; i--) {
      final t = texts[i];
      if (t.text.trim().isEmpty) continue;
      final tp = _layoutTextPainter(t);
      final pad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      final w = (tp.width + pad) * t.scale;
      final h = (tp.height + pad) * t.scale;
      if (SelectionHandles.isPointInRotatedRect(
        point: p,
        center: t.position + Offset(w / 2, h / 2),
        width: w,
        height: h,
        rotation: t.rotation,
      ))
        return i;
    }
    return null;
  }

  Future<void> _pickAndInsertImage() async {
    final picked = await ImageLoader.pickImage();
    if (picked == null) return;
    final center = controller.toScene(
      Offset(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
      ),
    );
    final scale = 900.0 / math.max(picked.image.width, picked.image.height);
    setState(() {
      images.add(
        ImportedImage(
          id: _uuid.v4(),
          image: picked.image,
          bytes: picked.bytes,
          position:
              center -
              Offset(
                (picked.image.width * scale) / 2,
                (picked.image.height * scale) / 2,
              ),
          scale: scale,
        ),
      );
      _selectedImageIndex = images.length - 1;
      activeTool = ActiveTool.hand;
    });
  }

  Future<void> _promptAddOrEditText({
    Offset? position,
    int? existingIndex,
  }) async {
    final isEdit = existingIndex != null;
    final initial = isEdit
        ? texts[existingIndex]
        : CanvasText(
            id: _uuid.v4(),
            text: '',
            position: position ?? Offset.zero,
            color: currentColor,
            fontSize: 36,
          );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => TextEditorDialog(initialText: initial, isEdit: isEdit),
    );

    if (result == true && initial.text.trim().isNotEmpty) {
      setState(() {
        if (isEdit) {
          texts[existingIndex] = initial;
        } else {
          texts.add(initial);
          _selectedTextIndex = texts.length - 1;
        }
        activeTool = ActiveTool.hand;
      });
    }
  }

  void _deleteSelectedElement() => setState(() {
    if (_selectedImageIndex != null)
      images.removeAt(_selectedImageIndex!);
    else if (_selectedTextIndex != null)
      texts.removeAt(_selectedTextIndex!);
    _selectedImageIndex = _selectedTextIndex = null;
  });
  void _showToast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 300)),
    );
  }

  void startStroke(Offset p) {
    currentPoints = [p];
    setState(
      () => currentStroke = Stroke(
        currentPoints,
        currentColor.withOpacity(currentOpacity),
        currentWidth,
        isEraser: activeTool == ActiveTool.eraser,
      ),
    );
    _redoActions.clear();
  }

  void addPoint(Offset p) {
    if (currentStroke == null ||
        (p - currentPoints.last).distance < 2.0 / currentScale)
      return;
    setState(() {
      currentPoints.add(p);
      currentStroke = Stroke(
        currentPoints,
        currentStroke!.color,
        currentStroke!.width,
        isEraser: currentStroke!.isEraser,
      );
    });
  }

  void endStroke() {
    if (currentStroke == null) return;
    final stroke = currentStroke!;
    setState(() {
      layers[activeLayerIndex].strokes.add(stroke);
      _undoActions.add(
        _AddStrokeAction(layerIndex: activeLayerIndex, stroke: stroke),
      );
      _redoActions.clear();
      currentStroke = null;
      currentPoints = [];
    });
  }

  void undo() {
    if (_undoActions.isEmpty) return;
    setState(() {
      final action = _undoActions.removeLast();
      action.undo(layers);
      _redoActions.add(action);
    });
  }

  void redo() {
    if (_redoActions.isEmpty) return;
    setState(() {
      final action = _redoActions.removeLast();
      action.redo(layers);
      _undoActions.add(action);
    });
  }

  void _deleteSelectedStrokes() {
    if (_selectedStrokes.isEmpty) return;
    final layerIndex = activeLayerIndex;
    final strokes = layers[layerIndex].strokes;

    final removed = <_IndexedStroke>[];
    for (int i = 0; i < strokes.length; i++) {
      final s = strokes[i];
      if (_selectedStrokes.contains(s)) {
        removed.add(_IndexedStroke(i, s));
      }
    }
    if (removed.isEmpty) return;

    setState(() {
      for (final item in removed.reversed) {
        strokes.removeAt(item.index);
      }
      _undoActions.add(
        _RemoveStrokesAction(layerIndex: layerIndex, removed: removed),
      );
      _redoActions.clear();
      _clearStrokeSelection();
    });
  }

  void _deleteSelection() {
    if (_selectedImageIndex != null || _selectedTextIndex != null) {
      _deleteSelectedElement();
      return;
    }
    _deleteSelectedStrokes();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveDocument(showToast: false);
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: InteractiveViewer(
                  transformationController: controller,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.1,
                  maxScale: 5.0,
                  constrained: false,
                  panEnabled: false,
                  scaleEnabled: true,
                  onInteractionUpdate: (d) => _hasZoomed = true,
                  child: SizedBox(
                    width: canvasWidth,
                    height: canvasHeight,
                    child: Stack(
                      children: [
                        // Đã tối ưu: Loại bỏ RepaintBoundary ở lớp lưới để tránh tràn bộ nhớ
                        SizedBox(
                          width: canvasWidth,
                          height: canvasHeight,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  color: canvasColor,
                                  key: ValueKey("bg_$canvasColor"),
                                ),
                              ),
                              Positioned.fill(
                                child: CustomPaint(
                                  key: ValueKey("grid_$currentGridType"),
                                  painter: GridPainter(
                                    gridSize: gridSize,
                                    gridType: currentGridType,
                                    baseColor: gridColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        RepaintBoundary(
                          child: CustomPaint(
                            isComplex: true,
                            foregroundPainter: DrawPainter(
                              _visibleStrokes,
                              images,
                              texts: texts,
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: CustomPaint(
                            foregroundPainter: DrawPainter(
                              currentStroke == null ? [] : [currentStroke!],
                              [],
                              canvasColor: canvasColor,
                              isPreview: true,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            foregroundPainter: SelectionPainter(
                              selectedImage: _selectedImageIndex == null
                                  ? null
                                  : images[_selectedImageIndex!],
                              selectedText: _selectedTextIndex == null
                                  ? null
                                  : texts[_selectedTextIndex!],
                              viewportScale: currentScale,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            foregroundPainter: LassoPainter(
                              lassoPoints: _lassoPoints,
                              selectionBounds: _selectedStrokesBounds,
                              viewportScale: currentScale,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DrawingToolbar(
                onBack: () async {
                  await _saveDocument(showToast: false);
                  if (context.mounted) Navigator.pop(context);
                },
                onSave: _saveDocument,
                onSettingsSelect: () => DrawingSettingsModal.show(
                  context,
                  currentGridType: currentGridType,
                  onGridTypeChanged: (t) => setState(() => currentGridType = t),
                  onPickBgColor: () => showDialog(
                    context: context,
                    builder: (ctx) => ProcreateColorPicker(
                      currentColor: canvasColor,
                      onColorChanged: (c) => setState(() => canvasColor = c),
                    ),
                  ),
                ),
                onAddImage: _pickAndInsertImage,
                onAddText: () => setState(() => activeTool = ActiveTool.text),
                zoomLevel: "${(currentScale * 100).round()}%",
                drawingName: currentName,
                onRename: _renameDrawing,
              ),
            ),
            Positioned(
              left: 4,
              top: 100,
              bottom: 80,
              child: Center(
                child: DrawingSidebar(
                  currentWidth: currentWidth,
                  currentOpacity: currentOpacity,
                  currentColor: currentColor,
                  onWidthChanged: (v) => setState(() => currentWidth = v),
                  onOpacityChanged: (v) => setState(() => currentOpacity = v),
                  onUndo: undo,
                  onRedo: redo,
                  onColorTap: () => showDialog(
                    context: context,
                    builder: (ctx) => ProcreateColorPicker(
                      currentColor: currentColor,
                      onColorChanged: (c) => setState(() => currentColor = c),
                    ),
                  ),
                  activeTool: activeTool,
                  onSelectBrush: () =>
                      setState(() => activeTool = ActiveTool.brush),
                  onSelectEraser: () =>
                      setState(() => activeTool = ActiveTool.eraser),
                  onSelectHand: () =>
                      setState(() => activeTool = ActiveTool.hand),
                  onSelectText: () =>
                      setState(() => activeTool = ActiveTool.text),
                  onSelectShape: _chooseShapeType,
                  onSelectLasso: () => setState(() {
                    activeTool = ActiveTool.lasso;
                    _selectedImageIndex = null;
                    _selectedTextIndex = null;
                    _clearStrokeSelection();
                  }),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 60,
              child: DrawingLayersSidebar(
                layers: layers,
                activeLayerIndex: activeLayerIndex,
                onNewLayer: _addNewLayer,
                onSelectLayer: _selectLayer,
                onToggleVisibility: _toggleLayerVisibility,
                onDeleteLayer: _deleteLayer,
              ),
            ),
            if (_selectedImageIndex != null ||
                _selectedTextIndex != null ||
                _selectedStrokes.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 30,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 14),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: _deleteSelection,
                        ),
                        const VerticalDivider(width: 16),
                        IconButton(
                          icon: const Icon(Icons.zoom_out_map),
                          onPressed: () => {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.rotate_right),
                          onPressed: () => {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (isSaving || isInitialLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
