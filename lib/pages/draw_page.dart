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
import '../utils/export_helper.dart';
import '../utils/storage_helper.dart';
import '../utils/image_loader.dart';
import '../utils/selection_utils.dart'; // Import tiện ích mới
import '../widgets/drawing_settings_modal.dart';
import '../widgets/procreate_color_picker.dart';
import '../widgets/drawing_toolbar.dart';
import '../widgets/drawing_sidebar.dart';
import '../widgets/drawing_layers_sidebar.dart';
import 'gallery_page.dart';

class DrawPage extends StatefulWidget {
  final String drawingId;
  const DrawPage({super.key, required this.drawingId});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  final GlobalKey _globalKey = GlobalKey();
  final Uuid _uuid = const Uuid();

  // --- KÍCH THƯỚC CANVAS ---
  final double canvasWidth = 50000.0;
  final double canvasHeight = 50000.0;

  // --- DỮ LIỆU ---
  List<DrawingLayer> layers = [];
  int activeLayerIndex = 0;
  String currentName = "Untitled Drawing";

  final List<Stroke> redoStack = [];
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

  // --- CẤU HÌNH ---
  final double gridSize = 50.0;
  final Color gridColor = const Color(0xFF32C5FF); // Màu xanh Concept
  Color canvasColor = Colors.white;

  // --- TRẠNG THÁI ---
  List<Offset> currentPoints = [];
  Color currentColor = const Color(0xFF32C5FF);
  double currentWidth = 10;
  double currentOpacity = 1.0;
  ActiveTool activeTool = ActiveTool.brush;
  double currentScale = 1.0;
  GridType currentGridType = GridType.lines;

  bool isSaving = false;
  bool isInitialLoading = true;

  // --- MULTITOUCH & GESTURE ---
  int _pointerCount = 0;
  int _maxPointerCount = 0;
  bool _isMultitouching = false;
  bool _hasZoomed = false;

  final TransformationController controller = TransformationController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    controller.addListener(() {
      final newScale = controller.value.getMaxScaleOnAxis();
      if ((newScale - currentScale).abs() > 0.01) {
        setState(() => currentScale = newScale);
      }
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final screenSize = MediaQuery.of(context).size;
      final x = (screenSize.width - canvasWidth) / 2;
      final y = (screenSize.height - canvasHeight) / 2;
      controller.value = Matrix4.identity()..translate(x, y)..scale(1.0);
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
        final strokes = doc?.strokes ?? <Stroke>[];
        final loadedTexts = doc?.texts ?? <CanvasText>[];
        final loadedImages = <ImportedImage>[];
        if (doc != null) {
          for (final persisted in doc.images) {
            final bytes = persisted.bytes;
            if (bytes == null || bytes.isEmpty) continue;
            try {
              final uiImage = await ImageLoader.decodeToUiImage(bytes);
              loadedImages.add(ImportedImage(id: persisted.id, image: uiImage, bytes: bytes, position: persisted.position, scale: persisted.scale, rotation: persisted.rotation));
            } catch (_) {}
          }
        }
        setState(() {
          currentName = name;
          layers[0].strokes = strokes;
          images..clear()..addAll(loadedImages);
          texts..clear()..addAll(loadedTexts);
          isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isInitialLoading = false);
    }
  }

  // --- QUẢN LÝ LAYER ---
  void _addNewLayer() => setState(() { layers.add(DrawingLayer(id: 'layer_${layers.length + 1}', strokes: [])); activeLayerIndex = layers.length - 1; });
  void _selectLayer(int index) => setState(() => activeLayerIndex = index);
  void _toggleLayerVisibility(int index) => setState(() => layers[index].isVisible = !layers[index].isVisible);
  void _deleteLayer(int index) {
    if (layers.length <= 1) return;
    setState(() {
      layers.removeAt(index);
      if (activeLayerIndex >= layers.length) activeLayerIndex = layers.length - 1;
      else if (index < activeLayerIndex) activeLayerIndex--;
    });
  }

  List<Stroke> get _visibleStrokes => layers.where((layer) => layer.isVisible).expand((layer) => layer.strokes).toList();

  // --- LOGIC CẢM ỨNG ---
  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount > _maxPointerCount) _maxPointerCount = _pointerCount;
    if (_pointerCount > 1) {
      setState(() { _isMultitouching = true; currentStroke = null; currentPoints = []; });
    } else {
      _hasZoomed = false;
      _maxPointerCount = 1;
      final scenePos = controller.toScene(event.localPosition);

      if (activeTool == ActiveTool.hand || activeTool == ActiveTool.text) {
        if (activeTool == ActiveTool.hand && (_selectedImageIndex != null || _selectedTextIndex != null)) {
          final handles = _currentSelectionHandles();
          if (handles != null) {
            final handle = handles.hitTest(scenePos);
            if (handle != TransformHandle.none) { _beginHandleTransform(handle: handle, pointerScene: scenePos); return; }
          }
        }
        final hitText = _hitTestText(scenePos);
        if (hitText != null) {
          setState(() { _selectedTextIndex = hitText; _selectedImageIndex = null; });
          if (activeTool == ActiveTool.hand) _beginDrag(scenePos, texts[hitText].position);
          else Future.microtask(() => _promptAddOrEditText(existingIndex: hitText));
          return;
        }
        final hitImage = _hitTestImage(scenePos);
        if (hitImage != null) {
          setState(() { _selectedImageIndex = hitImage; _selectedTextIndex = null; });
          _beginDrag(scenePos, images[hitImage].position);
          return;
        }
        if (activeTool == ActiveTool.text) {
          setState(() { _selectedImageIndex = null; _selectedTextIndex = null; });
          Future.microtask(() => _promptAddOrEditText(position: scenePos));
          return;
        }
        setState(() { _selectedImageIndex = null; _selectedTextIndex = null; });
        return;
      }
      setState(() { _selectedImageIndex = null; _selectedTextIndex = null; });
      if (layers[activeLayerIndex].isVisible) startStroke(scenePos);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final scenePos = controller.toScene(event.localPosition);
    if (_activeHandle != TransformHandle.none && !_isMultitouching && _pointerCount == 1) { _updateHandleTransform(pointerScene: scenePos); return; }
    if (_isDraggingElement && !_isMultitouching && _pointerCount == 1) { _updateDrag(scenePos); return; }
    if (!_isMultitouching && _pointerCount == 1 && (activeTool == ActiveTool.brush || activeTool == ActiveTool.eraser)) addPoint(scenePos);
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerCount--;
    if (_pointerCount == 0) {
      if (_activeHandle != TransformHandle.none) _endHandleTransform();
      else if (_isDraggingElement) _endDrag();
      else if (activeTool == ActiveTool.brush || activeTool == ActiveTool.eraser) {
        if (_maxPointerCount == 2 && !_hasZoomed) { undo(); _showToast("Undo"); }
        else if (_maxPointerCount == 3 && !_hasZoomed) { redo(); _showToast("Redo"); }
        else endStroke();
      }
      setState(() { _isMultitouching = false; _hasZoomed = false; _maxPointerCount = 0; });
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount = 0;
    setState(() { _isMultitouching = false; currentStroke = null; _endHandleTransform(); _endDrag(); });
  }

  // --- LOGIC TRANSFORM & DRAG ---
  void _beginHandleTransform({required TransformHandle handle, required Offset pointerScene}) {
    final handles = _currentSelectionHandles();
    if (handles == null) return;
    setState(() { _activeHandle = handle; _transformElementCenter = handles.center; });
    if (handle == TransformHandle.rotate) {
      _transformStartAngle = math.atan2(pointerScene.dy - handles.center.dy, pointerScene.dx - handles.center.dx);
      _transformRotationStart = _selectedImageIndex != null ? images[_selectedImageIndex!].rotation : texts[_selectedTextIndex!].rotation;
    } else if (handle == TransformHandle.scale) {
      final dist = (pointerScene - handles.center).distance;
      _transformStartDistance = dist <= 0.001 ? 0.001 : dist;
      _transformScaleStart = _selectedImageIndex != null ? images[_selectedImageIndex!].scale : texts[_selectedTextIndex!].scale;
    }
  }

  void _updateHandleTransform({required Offset pointerScene}) {
    final center = _transformElementCenter;
    if (_activeHandle == TransformHandle.none || center == null) return;
    if (_activeHandle == TransformHandle.rotate) {
      final currentAngle = math.atan2(pointerScene.dy - center.dy, pointerScene.dx - center.dx);
      final newRot = _transformRotationStart! + (currentAngle - _transformStartAngle!);
      setState(() { if (_selectedImageIndex != null) images[_selectedImageIndex!].rotation = newRot; else texts[_selectedTextIndex!].rotation = newRot; });
    } else if (_activeHandle == TransformHandle.scale) {
      final factor = (pointerScene - center).distance / _transformStartDistance!;
      final newScale = (_transformScaleStart! * factor).clamp(0.05, 50.0);
      setState(() {
        if (_selectedImageIndex != null) {
          final img = images[_selectedImageIndex!]; img.scale = newScale;
          img.position = center - Offset((img.image.width * img.scale) / 2, (img.image.height * img.scale) / 2);
        } else {
          final t = texts[_selectedTextIndex!]; t.scale = newScale;
          final tp = _layoutTextPainter(t);
          t.position = center - Offset(((tp.width + (t.backgroundColor == null ? 0 : t.padding * 2)) * t.scale) / 2, ((tp.height + (t.backgroundColor == null ? 0 : t.padding * 2)) * t.scale) / 2);
        }
      });
    }
  }

  void _endHandleTransform() { _activeHandle = TransformHandle.none; _transformRotationStart = _transformScaleStart = _transformElementCenter = _transformStartAngle = _transformStartDistance = null; }
  void _beginDrag(Offset p, Offset el) => setState(() { _isDraggingElement = true; _dragPointerStart = p; _dragElementStart = el; });
  void _updateDrag(Offset p) => setState(() { if (_selectedImageIndex != null) images[_selectedImageIndex!].position = _dragElementStart! + (p - _dragPointerStart!); else texts[_selectedTextIndex!].position = _dragElementStart! + (p - _dragPointerStart!); });
  void _endDrag() { _isDraggingElement = false; _dragPointerStart = _dragElementStart = null; }

  // --- HIT TESTING ---
  TextPainter _layoutTextPainter(CanvasText t) => TextPainter(text: TextSpan(text: t.text, style: TextStyle(color: t.color, fontSize: t.fontSize, fontWeight: t.fontWeight, fontFamily: t.fontFamily, fontStyle: t.italic ? FontStyle.italic : FontStyle.normal, decoration: t.underline ? TextDecoration.underline : TextDecoration.none)), textAlign: t.align, textDirection: TextDirection.ltr)..layout(maxWidth: t.maxWidth ?? double.infinity);

  SelectionHandles? _currentSelectionHandles() {
    if (_selectedImageIndex == null && _selectedTextIndex == null) return null;
    double w, h, rot; Offset pos;
    if (_selectedImageIndex != null) {
      final img = images[_selectedImageIndex!]; w = img.image.width * img.scale; h = img.image.height * img.scale; rot = img.rotation; pos = img.position;
    } else {
      final t = texts[_selectedTextIndex!]; final tp = _layoutTextPainter(t); final pad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      w = (tp.width + pad) * t.scale; h = (tp.height + pad) * t.scale; rot = t.rotation; pos = t.position;
    }
    return SelectionHandles(center: pos + Offset(w/2, h/2), rotation: rot, width: w, height: h, handleRadius: 10.0/currentScale, rotateRadius: 10.0/currentScale, rotateGap: 28.0/currentScale);
  }

  int? _hitTestImage(Offset p) {
    for (int i = images.length - 1; i >= 0; i--) {
      final img = images[i]; final w = img.image.width * img.scale; final h = img.image.height * img.scale;
      if (SelectionHandles.isPointInRotatedRect(point: p, center: img.position + Offset(w/2, h/2), width: w, height: h, rotation: img.rotation)) return i;
    }
    return null;
  }

  int? _hitTestText(Offset p) {
    for (int i = texts.length - 1; i >= 0; i--) {
      final t = texts[i]; if (t.text.trim().isEmpty) continue;
      final tp = _layoutTextPainter(t); final pad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      final w = (tp.width + pad) * t.scale; final h = (tp.height + pad) * t.scale;
      if (SelectionHandles.isPointInRotatedRect(point: p, center: t.position + Offset(w/2, h/2), width: w, height: h, rotation: t.rotation)) return i;
    }
    return null;
  }

  // --- ACTIONS ---
  Future<void> _pickAndInsertImage() async {
    final picked = await ImageLoader.pickImage(); if (picked == null) return;
    final center = controller.toScene(Offset(MediaQuery.of(context).size.width/2, MediaQuery.of(context).size.height/2));
    final scale = 900.0 / math.max(picked.image.width, picked.image.height);
    setState(() { images.add(ImportedImage(id: _uuid.v4(), image: picked.image, bytes: picked.bytes, position: center - Offset((picked.image.width*scale)/2, (picked.image.height*scale)/2), scale: scale)); _selectedImageIndex = images.length-1; activeTool = ActiveTool.hand; });
  }

  Future<void> _promptAddOrEditText({Offset? position, int? existingIndex}) async {
    // (Giữ nguyên logic Dialog text vì nó quá đặc thù, sau này có thể tách thành widget riêng)
    // ... logic dialog text giữ nguyên từ phiên bản trước ...
  }

  void _deleteSelectedElement() => setState(() { if (_selectedImageIndex != null) images.removeAt(_selectedImageIndex!); else if (_selectedTextIndex != null) texts.removeAt(_selectedTextIndex!); _selectedImageIndex = _selectedTextIndex = null; });
  void _showToast(String msg) { ScaffoldMessenger.of(context).clearSnackBars(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 300))); }

  // --- DRAWING LOGIC ---
  void startStroke(Offset p) { currentPoints = [p]; setState(() => currentStroke = Stroke(currentPoints, currentColor.withOpacity(currentOpacity), currentWidth, isEraser: activeTool == ActiveTool.eraser)); redoStack.clear(); }
  void addPoint(Offset p) { if (currentStroke == null || (p - currentPoints.last).distance < 2.0 / currentScale) return; setState(() { currentPoints.add(p); currentStroke = Stroke(currentPoints, currentStroke!.color, currentStroke!.width, isEraser: currentStroke!.isEraser); }); }
  void endStroke() { if (currentStroke == null) return; setState(() { layers[activeLayerIndex].strokes.add(currentStroke!); currentStroke = null; currentPoints = []; }); }
  void undo() { if (layers[activeLayerIndex].strokes.isNotEmpty) setState(() { redoStack.add(layers[activeLayerIndex].strokes.removeLast()); }); }
  void redo() { if (redoStack.isNotEmpty) setState(() { layers[activeLayerIndex].strokes.add(redoStack.removeLast()); }); }

  void _openSettings() => DrawingSettingsModal.show(context, currentGridType: currentGridType, onGridTypeChanged: (type) => setState(() => currentGridType = type), onPickBgColor: () => showDialog(context: context, builder: (ctx) => ProcreateColorPicker(currentColor: canvasColor, onColorChanged: (c) => setState(() => canvasColor = c))));

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { await ExportHelper.exportDrawing(context: context, completedStrokes: _visibleStrokes, currentStroke: currentStroke, canvasColor: canvasColor, images: images, texts: texts, onLoadingChanged: (v) => setState(() => isSaving = v)); return true; },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: _onPointerDown, onPointerMove: _onPointerMove, onPointerUp: _onPointerUp, onPointerCancel: _onPointerCancel,
                child: InteractiveViewer(
                  transformationController: controller, boundaryMargin: const EdgeInsets.all(double.infinity), minScale: 0.1, maxScale: 5.0, constrained: false, panEnabled: false, scaleEnabled: true,
                  onInteractionUpdate: (d) => _hasZoomed = true,
                  child: SizedBox(
                    width: canvasWidth, height: canvasHeight,
                    child: RepaintBoundary(
                      key: _globalKey,
                      child: Stack(
                        children: [
                          RepaintBoundary(
                            key: ValueKey("grid_${currentGridType.name}_$canvasColor"),
                            child: Stack(children: [Container(color: canvasColor), CustomPaint(painter: GridPainter(gridSize: gridSize, gridType: currentGridType, baseColor: gridColor))]),
                          ),
                          RepaintBoundary(child: CustomPaint(isComplex: true, foregroundPainter: DrawPainter(_visibleStrokes, images, texts: texts))),
                          RepaintBoundary(child: CustomPaint(foregroundPainter: DrawPainter(currentStroke == null ? [] : [currentStroke!], [], canvasColor: canvasColor, isPreview: true))),
                          IgnorePointer(child: CustomPaint(foregroundPainter: SelectionPainter(selectedImage: _selectedImageIndex == null ? null : images[_selectedImageIndex!], selectedText: _selectedTextIndex == null ? null : texts[_selectedTextIndex!], viewportScale: currentScale))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: DrawingToolbar(onBack: () => Navigator.pop(context), onSave: () {}, onSettingsSelect: _openSettings, onAddImage: _pickAndInsertImage, onAddText: () => setState(() => activeTool = ActiveTool.text), zoomLevel: "${(currentScale * 100).round()}%", drawingName: currentName, onRename: () {})),
            Positioned(left: 4, top: 100, bottom: 80, child: Center(child: DrawingSidebar(currentWidth: currentWidth, currentOpacity: currentOpacity, currentColor: currentColor, onWidthChanged: (v) => setState(() => currentWidth = v), onOpacityChanged: (v) => setState(() => currentOpacity = v), onUndo: undo, onRedo: redo, onColorTap: () => showDialog(context: context, builder: (ctx) => ProcreateColorPicker(currentColor: currentColor, onColorChanged: (c) => setState(() => currentColor = c))), activeTool: activeTool, onSelectBrush: () => setState(() => activeTool = ActiveTool.brush), onSelectEraser: () => setState(() => activeTool = ActiveTool.eraser), onSelectHand: () => setState(() => activeTool = ActiveTool.hand), onSelectText: () => setState(() => activeTool = ActiveTool.text)))),
            Positioned(right: 0, top: 60, child: DrawingLayersSidebar(layers: layers, activeLayerIndex: activeLayerIndex, onNewLayer: _addNewLayer, onSelectLayer: _selectLayer, onToggleVisibility: _toggleLayerVisibility, onDeleteLayer: _deleteLayer)),
            if (_selectedImageIndex != null || _selectedTextIndex != null) Positioned(left: 0, right: 0, bottom: 30, child: Center(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 14)]), child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: _deleteSelectedElement), const VerticalDivider(width: 16), IconButton(icon: const Icon(Icons.zoom_out_map), onPressed: () => {}), IconButton(icon: const Icon(Icons.rotate_right), onPressed: () => {})])))),
            if (isSaving || isInitialLoading) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: Colors.black))),
          ],
        ),
      ),
    );
  }
}
