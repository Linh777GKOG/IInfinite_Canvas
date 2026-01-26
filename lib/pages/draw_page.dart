import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/drawing_models.dart';
import '../painters/canvas_painters.dart';
import '../utils/export_helper.dart';
import '../utils/storage_helper.dart';
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

  // --- KÍCH THƯỚC CANVAS ---
  final double canvasWidth = 50000.0;
  final double canvasHeight = 50000.0;

  // --- DỮ LIỆU ---
  List<DrawingLayer> layers = [];
  int activeLayerIndex = 0;
  String currentName = "Untitled Drawing";

  final List<Stroke> redoStack = [];
  final List<ImportedImage> images = [];
  Stroke? currentStroke;

  // --- CẤU HÌNH ---
  final double gridSize = 50.0;
  final Color gridColor = Colors.black.withOpacity(0.05);
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

  // 🔥 LOAD DỮ LIỆU
  Future<void> _loadData() async {
    try {
      final name = await StorageHelper.getDrawingName(widget.drawingId);
      final savedStrokes = await StorageHelper.loadDrawing(widget.drawingId);

      if (mounted) {
        setState(() {
          currentName = name;
          if (savedStrokes.isNotEmpty) {
            layers[0].strokes = savedStrokes;
          }
          isInitialLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi load data: $e");
      if (mounted) setState(() => isInitialLoading = false);
    }
  }

  // --- QUẢN LÝ LAYER ---
  void _addNewLayer() {
    setState(() {
      String newId = 'layer_${layers.length + 1}';
      layers.add(DrawingLayer(id: newId, strokes: []));
      activeLayerIndex = layers.length - 1;
    });
  }

  void _selectLayer(int index) {
    setState(() => activeLayerIndex = index);
  }

  void _toggleLayerVisibility(int index) {
    setState(() {
      layers[index].isVisible = !layers[index].isVisible;
    });
  }

  void _deleteLayer(int index) {
    if (layers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không thể xóa layer cuối cùng!")),
      );
      return;
    }
    setState(() {
      layers.removeAt(index);
      if (activeLayerIndex >= layers.length) {
        activeLayerIndex = layers.length - 1;
      } else if (index < activeLayerIndex) {
        activeLayerIndex--;
      }
    });
  }

  List<Stroke> get _visibleStrokes {
    return layers
        .where((layer) => layer.isVisible)
        .expand((layer) => layer.strokes)
        .toList();
  }

  // --- LOGIC CẢM ỨNG ---
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

      if (layers[activeLayerIndex].isVisible) {
        startStroke(controller.toScene(event.localPosition));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không thể vẽ lên Layer đang ẩn!"), duration: Duration(milliseconds: 500)));
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isMultitouching && _pointerCount == 1) {
      addPoint(controller.toScene(event.localPosition));
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerCount--;
    if (_pointerCount == 0) {
      if (_maxPointerCount == 2 && !_hasZoomed) {
        undo();
        _showToast("Undo");
      } else if (_maxPointerCount == 3 && !_hasZoomed) {
        redo();
        _showToast("Redo");
      } else {
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
    setState(() { _isMultitouching = false; currentStroke = null; });
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 300)));
  }

  void startStroke(Offset p) {
    if (_isMultitouching || _pointerCount > 1) return;
    currentPoints = [p];
    setState(() => currentStroke = Stroke(currentPoints, currentColor.withOpacity(currentOpacity), currentWidth, isEraser: activeTool == ActiveTool.eraser));
    redoStack.clear();
  }

  void addPoint(Offset p) {
    if (_isMultitouching || currentStroke == null) return;
    if ((p - currentPoints.last).distance < 3.0) return;
    setState(() => currentPoints.add(p));
    currentStroke = Stroke(currentPoints, currentStroke!.color, currentStroke!.width, isEraser: currentStroke!.isEraser);
  }

  void endStroke() {
    if (_isMultitouching || currentStroke == null) return;
    setState(() {
      layers[activeLayerIndex].strokes.add(currentStroke!);
      currentStroke = null;
      currentPoints = [];
    });
  }

  void undo() {
    final activeStrokes = layers[activeLayerIndex].strokes;
    if (activeStrokes.isNotEmpty) {
      redoStack.add(activeStrokes.removeLast());
      setState(() {});
    }
  }

  void redo() {
    if (redoStack.isNotEmpty) {
      layers[activeLayerIndex].strokes.add(redoStack.removeLast());
      setState(() {});
    }
  }

  void toggleTool() => setState(() => activeTool = (activeTool == ActiveTool.brush) ? ActiveTool.eraser : ActiveTool.brush);

  // --- HỘP THOẠI ĐỔI TÊN ---
  void _showRenameDialog() {
    TextEditingController nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Rename Drawing", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Enter new name",
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _performRename(value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _performRename(nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Rename", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _performRename(String newName) {
    setState(() => currentName = newName);
    StorageHelper.renameDrawing(widget.drawingId, newName);
  }

  // --- CÁC HÀM KHÁC ---
  void _openSettings() {
    DrawingSettingsModal.show(context, currentGridType: currentGridType, onGridTypeChanged: (type) => setState(() => currentGridType = type), onPickBgColor: _showBackgroundColorPicker);
  }
  void _showBackgroundColorPicker() {
    showDialog(context: context, barrierColor: Colors.transparent, builder: (ctx) => ProcreateColorPicker(currentColor: canvasColor, onColorChanged: (c) => setState(() => canvasColor = c)));
  }
  void _showColorPicker() {
    showDialog(context: context, barrierColor: Colors.transparent, builder: (ctx) => ProcreateColorPicker(currentColor: currentColor, onColorChanged: (c) => setState(() { currentColor = c; if(activeTool==ActiveTool.eraser) activeTool=ActiveTool.brush; })));
  }

  Future<void> _handleExport() async {
    await ExportHelper.exportDrawing(
      context: context,
      completedStrokes: _visibleStrokes,
      currentStroke: currentStroke,
      canvasColor: canvasColor,
      images: images,
      onLoadingChanged: (val) => setState(() => isSaving = val),
    );
  }

  // 🔥 HÀM LƯU TRANH (Đã Fix lỗi Crash & Lặp code)
  Future<void> _saveDrawing() async {
    if (isSaving) return;
    setState(() => isSaving = true);

    try {
      // 1. Tạo Thumbnail nhỏ (Fix crash)
      Uint8List pngBytes = await _generateSmallThumbnail(_visibleStrokes);

      // 2. Lưu dữ liệu
      await StorageHelper.saveDrawing(
          widget.drawingId,
          _visibleStrokes,
          pngBytes,
          name: currentName
      );

    } catch (e) {
      debugPrint("Lỗi lưu: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // 🔥 HÀM TẠO THUMBNAIL (Helper)
  Future<Uint8List> _generateSmallThumbnail(List<Stroke> strokes) async {
    if (strokes.isEmpty) return Uint8List(0);

    // Tính vùng bao quanh nét vẽ
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (var stroke in strokes) {
      for (var p in stroke.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    minX -= 50; minY -= 50; maxX += 50; maxY += 50;
    double w = maxX - minX;
    double h = maxY - minY;
    if (w <= 0 || h <= 0) return Uint8List(0);

    const double thumbSize = 300.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, thumbSize, thumbSize));

    canvas.drawRect(const Rect.fromLTWH(0, 0, thumbSize, thumbSize), Paint()..color = Colors.white);

    double scale = thumbSize / (w > h ? w : h);
    canvas.scale(scale);
    canvas.translate(-minX, -minY);

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (var stroke in strokes) {
      paint.color = stroke.color;
      paint.strokeWidth = stroke.width;

      if (stroke.points.length > 1) {
        Path path = Path();
        path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      } else if (stroke.points.isNotEmpty) {
        canvas.drawPoints(ui.PointMode.points, stroke.points, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(thumbSize.toInt(), thumbSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // 🔥 XỬ LÝ NÚT BACK
  Future<void> _handleBack() async {
    await _saveDrawing();

    if (!mounted) return;

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const GalleryPage()));
    }
  }

  Future<bool> _onWillPop() async {
    await _handleBack();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Stack(
          children: [
            // 1. CANVAS
            Positioned.fill(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: InteractiveViewer(
                  transformationController: controller,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.1, maxScale: 5.0, constrained: false,
                  panEnabled: false, scaleEnabled: true,
                  onInteractionUpdate: (details) {
                    if (details.scale != 1.0) _hasZoomed = true;
                  },
                  onInteractionStart: (d) {
                    if (d.pointerCount > 1) setState(() { _isMultitouching = true; currentStroke = null; });
                  },
                  child: SizedBox(
                    width: canvasWidth, height: canvasHeight,
                    child: RepaintBoundary(
                      key: _globalKey,
                      child: Stack(
                        children: [
                          Positioned.fill(child: Stack(children: [Container(key: ValueKey(canvasColor), color: canvasColor), RepaintBoundary(child: AnimatedBuilder(animation: controller, builder: (c, _) => CustomPaint(painter: GridPainter(gridSize: gridSize, gridColor: gridColor, controller: controller, gridType: currentGridType))))])),
                          Positioned.fill(child: RepaintBoundary(child: CustomPaint(isComplex: false, foregroundPainter: DrawPainter(_visibleStrokes, images)))),
                          Positioned.fill(child: CustomPaint(foregroundPainter: DrawPainter(currentStroke == null ? [] : [currentStroke!], [], canvasColor: canvasColor, isPreview: true))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. TOP BAR
            Positioned(
              top: 0, left: 0, right: 0,
              child: DrawingToolbar(
                onBack: _handleBack,
                onSave: _handleExport,
                onSettingsSelect: _openSettings,
                zoomLevel: "${(currentScale * 100).round()}%",
                drawingName: currentName,
                onRename: _showRenameDialog,
              ),
            ),

            // 3. LEFT SIDEBAR
            Positioned(
              left: 4, top: 100, bottom: 80,
              child: Center(
                child: DrawingSidebar(
                  currentWidth: currentWidth,
                  currentOpacity: currentOpacity,
                  currentColor: currentColor,
                  onWidthChanged: (v) => setState(() => currentWidth = v),
                  onOpacityChanged: (v) => setState(() => currentOpacity = v),
                  onUndo: undo,
                  onRedo: redo,
                  onColorTap: _showColorPicker,

                  // 🔥 CẬP NHẬT CÁC THAM SỐ MỚI Ở ĐÂY:
                  activeTool: activeTool, // Truyền trạng thái hiện tại

                  onSelectBrush: () {
                    setState(() => activeTool = ActiveTool.brush);
                  },

                  onSelectEraser: () {
                    setState(() => activeTool = ActiveTool.eraser);
                  },
                ),
              ),
            ),


            // 4. RIGHT SIDEBAR (LAYERS)
            Positioned(
              right: 0, top: 60,
              child: DrawingLayersSidebar(
                layers: layers,
                activeLayerIndex: activeLayerIndex,
                onNewLayer: _addNewLayer,
                onSelectLayer: _selectLayer,
                onToggleVisibility: _toggleLayerVisibility,
                onDeleteLayer: _deleteLayer,
              ),
            ),

            if (isSaving || isInitialLoading)
              Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: Colors.black))),
          ],
        ),
      ),
    );
  }
}