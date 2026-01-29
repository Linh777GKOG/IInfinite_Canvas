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
import '../widgets/drawing_settings_modal.dart';
import '../widgets/procreate_color_picker.dart';
import '../widgets/drawing_toolbar.dart';
import '../widgets/drawing_sidebar.dart';
import '../widgets/drawing_layers_sidebar.dart';
import 'gallery_page.dart';


enum _TransformHandle { none, scale, rotate }

class _SelectionHandles {
  final Offset center;
  final double rotation;
  final double width;
  final double height;
  final double handleRadius;
  final double rotateRadius;
  final double rotateGap;

  const _SelectionHandles({
    required this.center,
    required this.rotation,
    required this.width,
    required this.height,
    required this.handleRadius,
    required this.rotateRadius,
    required this.rotateGap,
  });

  factory _SelectionHandles.fromBox({
    required Offset center,
    required double width,
    required double height,
    required double rotation,
    required double handleRadius,
    required double rotateRadius,
    required double rotateGap,
  }) {
    return _SelectionHandles(
      center: center,
      width: width,
      height: height,
      rotation: rotation,
      handleRadius: handleRadius,
      rotateRadius: rotateRadius,
      rotateGap: rotateGap,
    );
  }

  _TransformHandle hitTest(Offset scenePos) {
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
      if ((scenePos - c).distance <= handleRadius) return _TransformHandle.scale;
    }
    if ((scenePos - rotHandle).distance <= rotateRadius) return _TransformHandle.rotate;
    return _TransformHandle.none;
  }

  static Offset _rotateOffset(Offset p, double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
  }
}



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

  _TransformHandle _activeHandle = _TransformHandle.none;
  double? _transformRotationStart;
  double? _transformScaleStart;
  Offset? _transformElementCenter;
  double? _transformStartAngle;
  double? _transformStartDistance;

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

  //  LOAD DỮ LIỆU
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
            } catch (_) {
              // skip broken image
            }
          }
        }

        setState(() {
          currentName = name;
          layers[0].strokes = strokes;
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

      final scenePos = controller.toScene(event.localPosition);

      // Nếu đang ở chế độ chọn/ảnh/text -> ưu tiên chọn & kéo thả
      if (activeTool == ActiveTool.hand || activeTool == ActiveTool.text) {
        // Hand tool: ưu tiên handle transform nếu đang có selection
        if (activeTool == ActiveTool.hand && (_selectedImageIndex != null || _selectedTextIndex != null)) {
          final handles = _currentSelectionHandles();
          if (handles != null) {
            final handle = handles.hitTest(scenePos);
            if (handle != _TransformHandle.none) {
              _beginHandleTransform(handle: handle, pointerScene: scenePos);
              return;
            }
          }
        }

        final hitText = _hitTestText(scenePos);
        if (hitText != null) {
          setState(() {
            _selectedTextIndex = hitText;
            _selectedImageIndex = null;
          });

          if (activeTool == ActiveTool.hand) {
            _beginDrag(scenePos, texts[hitText].position);
          } else {
            // Text tool: tap vào text để sửa
            Future.microtask(() => _promptAddOrEditText(existingIndex: hitText));
          }
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

        // Text tool: tap chỗ trống để thêm text
        if (activeTool == ActiveTool.text) {
          setState(() {
            _selectedImageIndex = null;
            _selectedTextIndex = null;
          });
          Future.microtask(() => _promptAddOrEditText(position: scenePos));
          return;
        }

        // Hand tool: tap chỗ trống -> bỏ chọn
        setState(() {
          _selectedImageIndex = null;
          _selectedTextIndex = null;
        });
        return;
      }

      // Brush / Eraser
      setState(() {
        _selectedImageIndex = null;
        _selectedTextIndex = null;
      });
      if (layers[activeLayerIndex].isVisible) {
        startStroke(scenePos);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không thể vẽ lên Layer đang ẩn!"), duration: Duration(milliseconds: 500)));
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final scenePos = controller.toScene(event.localPosition);

    if (_activeHandle != _TransformHandle.none && !_isMultitouching && _pointerCount == 1) {
      _updateHandleTransform(pointerScene: scenePos);
      return;
    }

    if (_isDraggingElement && !_isMultitouching && _pointerCount == 1) {
      _updateDrag(scenePos);
      return;
    }

    if (!_isMultitouching && _pointerCount == 1 && (activeTool == ActiveTool.brush || activeTool == ActiveTool.eraser)) {
      addPoint(scenePos);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerCount--;
    if (_pointerCount == 0) {
      if (_activeHandle != _TransformHandle.none) {
        _endHandleTransform();
      } else if (_isDraggingElement) {
        _endDrag();
      } else if (activeTool == ActiveTool.brush || activeTool == ActiveTool.eraser) {
        if (_maxPointerCount == 2 && !_hasZoomed) {
          undo();
          _showToast("Undo");
        } else if (_maxPointerCount == 3 && !_hasZoomed) {
          redo();
          _showToast("Redo");
        } else {
          endStroke();
        }
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
      _endHandleTransform();
      _endDrag();
    });
  }

  void _beginHandleTransform({required _TransformHandle handle, required Offset pointerScene}) {
    final selectedImageIndex = _selectedImageIndex;
    final selectedTextIndex = _selectedTextIndex;
    if (selectedImageIndex == null && selectedTextIndex == null) return;

    final handles = _currentSelectionHandles();
    if (handles == null) return;

    setState(() {
      _activeHandle = handle;
      _transformElementCenter = handles.center;
    });

    if (handle == _TransformHandle.rotate) {
      final center = handles.center;
      _transformStartAngle = math.atan2(pointerScene.dy - center.dy, pointerScene.dx - center.dx);
      if (selectedImageIndex != null) {
        _transformRotationStart = images[selectedImageIndex].rotation;
      } else if (selectedTextIndex != null) {
        _transformRotationStart = texts[selectedTextIndex].rotation;
      }
      return;
    }

    if (handle == _TransformHandle.scale) {
      final center = handles.center;
      final dist = (pointerScene - center).distance;
      _transformStartDistance = dist <= 0.001 ? 0.001 : dist;
      if (selectedImageIndex != null) {
        _transformScaleStart = images[selectedImageIndex].scale;
      } else if (selectedTextIndex != null) {
        _transformScaleStart = texts[selectedTextIndex].scale;
      }
    }
  }

  void _updateHandleTransform({required Offset pointerScene}) {
    final handle = _activeHandle;
    final center = _transformElementCenter;
    if (handle == _TransformHandle.none || center == null) return;

    final selectedImageIndex = _selectedImageIndex;
    final selectedTextIndex = _selectedTextIndex;

    if (handle == _TransformHandle.rotate) {
      final startAngle = _transformStartAngle;
      final startRotation = _transformRotationStart;
      if (startAngle == null || startRotation == null) return;

      final currentAngle = math.atan2(pointerScene.dy - center.dy, pointerScene.dx - center.dx);
      final delta = currentAngle - startAngle;
      final newRotation = startRotation + delta;

      if (selectedImageIndex != null) {
        images[selectedImageIndex].rotation = newRotation;
        setState(() {});
      } else if (selectedTextIndex != null) {
        texts[selectedTextIndex].rotation = newRotation;
        setState(() {});
      }
      return;
    }

    if (handle == _TransformHandle.scale) {
      final startDist = _transformStartDistance;
      final startScale = _transformScaleStart;
      if (startDist == null || startScale == null) return;
      final currentDist = (pointerScene - center).distance;
      final factor = currentDist / startDist;
      var newScale = startScale * factor;
      newScale = newScale.clamp(0.05, 50.0);

      if (selectedImageIndex != null) {
        final img = images[selectedImageIndex];
        img.scale = newScale;
        final w = img.image.width * img.scale;
        final h = img.image.height * img.scale;
        img.position = center - Offset(w / 2, h / 2);
        setState(() {});
      } else if (selectedTextIndex != null) {
        final t = texts[selectedTextIndex];
        t.scale = newScale;
        final tp = _layoutTextPainter(t);
        final extraPad = t.backgroundColor == null ? 0.0 : t.padding * 2;
        final baseW = tp.width + extraPad;
        final baseH = tp.height + extraPad;
        final w = baseW * t.scale;
        final h = baseH * t.scale;
        t.position = center - Offset(w / 2, h / 2);
        setState(() {});
      }
    }
  }

  void _endHandleTransform() {
    _activeHandle = _TransformHandle.none;
    _transformRotationStart = null;
    _transformScaleStart = null;
    _transformElementCenter = null;
    _transformStartAngle = null;
    _transformStartDistance = null;
  }

  void _beginDrag(Offset pointerScene, Offset elementPos) {
    setState(() {
      _isDraggingElement = true;
      _dragPointerStart = pointerScene;
      _dragElementStart = elementPos;
    });
  }

  void _updateDrag(Offset pointerScene) {
    final startPointer = _dragPointerStart;
    final startElement = _dragElementStart;
    if (startPointer == null || startElement == null) return;
    final delta = pointerScene - startPointer;

    if (_selectedImageIndex != null) {
      images[_selectedImageIndex!].position = startElement + delta;
      setState(() {});
      return;
    }
    if (_selectedTextIndex != null) {
      texts[_selectedTextIndex!].position = startElement + delta;
      setState(() {});
    }
  }

  void _endDrag() {
    _isDraggingElement = false;
    _dragPointerStart = null;
    _dragElementStart = null;
  }

  static bool _pointInRotatedRect({
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

  TextPainter _layoutTextPainter(CanvasText t) {
    final tp = TextPainter(
      text: TextSpan(
        text: t.text,
        style: TextStyle(
          color: t.color,
          fontSize: t.fontSize,
          fontWeight: t.fontWeight,
          fontFamily: t.fontFamily,
          fontStyle: t.italic ? FontStyle.italic : FontStyle.normal,
          decoration: t.underline ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
      textAlign: t.align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: t.maxWidth ?? double.infinity);
    return tp;
  }

  _SelectionHandles? _currentSelectionHandles() {
    const baseHandleRadiusPx = 10.0;
    const baseRotateRadiusPx = 10.0;
    const baseRotateGapPx = 28.0;

    final handleRadius = baseHandleRadiusPx / currentScale;
    final rotateRadius = baseRotateRadiusPx / currentScale;
    final rotateGap = baseRotateGapPx / currentScale;

    if (_selectedImageIndex != null) {
      final img = images[_selectedImageIndex!];
      final w = img.image.width * img.scale;
      final h = img.image.height * img.scale;
      final center = img.position + Offset(w / 2, h / 2);
      return _SelectionHandles.fromBox(
        center: center,
        width: w,
        height: h,
        rotation: img.rotation,
        handleRadius: handleRadius,
        rotateRadius: rotateRadius,
        rotateGap: rotateGap,
      );
    }
    if (_selectedTextIndex != null) {
      final t = texts[_selectedTextIndex!];
      if (t.text.trim().isEmpty) return null;
      final tp = _layoutTextPainter(t);
      final extraPad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      final baseW = tp.width + extraPad;
      final baseH = tp.height + extraPad;
      final w = baseW * t.scale;
      final h = baseH * t.scale;
      final center = t.position + Offset(w / 2, h / 2);
      return _SelectionHandles.fromBox(
        center: center,
        width: w,
        height: h,
        rotation: t.rotation,
        handleRadius: handleRadius,
        rotateRadius: rotateRadius,
        rotateGap: rotateGap,
      );
    }
    return null;
  }

  int? _hitTestImage(Offset scenePos) {
    for (int i = images.length - 1; i >= 0; i--) {
      final img = images[i];
      final w = img.image.width * img.scale;
      final h = img.image.height * img.scale;
      final center = img.position + Offset(w / 2, h / 2);
      final hit = _pointInRotatedRect(
        point: scenePos,
        center: center,
        width: w,
        height: h,
        rotation: img.rotation,
      );
      if (hit) return i;
    }
    return null;
  }

  int? _hitTestText(Offset scenePos) {
    for (int i = texts.length - 1; i >= 0; i--) {
      final t = texts[i];
      if (t.text.trim().isEmpty) continue;
      final tp = _layoutTextPainter(t);
      final extraPad = t.backgroundColor == null ? 0.0 : t.padding * 2;
      final baseW = tp.width + extraPad;
      final baseH = tp.height + extraPad;
      final w = baseW * t.scale;
      final h = baseH * t.scale;
      final center = t.position + Offset(w / 2, h / 2);
      final hit = _pointInRotatedRect(
        point: scenePos,
        center: center,
        width: w,
        height: h,
        rotation: t.rotation,
      );
      if (hit) return i;
    }
    return null;
  }

  Future<void> _pickAndInsertImage() async {
    final picked = await ImageLoader.pickImage();
    if (picked == null) return;

    final size = MediaQuery.of(context).size;
    final centerScene = controller.toScene(Offset(size.width / 2, size.height / 2));

    final maxDim = (picked.image.width > picked.image.height)
        ? picked.image.width.toDouble()
        : picked.image.height.toDouble();
    const targetMax = 900.0;
    final scale = maxDim > targetMax ? targetMax / maxDim : 1.0;
    final w = picked.image.width * scale;
    final h = picked.image.height * scale;

    final newImg = ImportedImage(
      id: _uuid.v4(),
      image: picked.image,
      bytes: picked.bytes,
      position: Offset(centerScene.dx - w / 2, centerScene.dy - h / 2),
      scale: scale,
    );

    setState(() {
      images.add(newImg);
      _selectedImageIndex = images.length - 1;
      _selectedTextIndex = null;
      activeTool = ActiveTool.hand;
    });
  }

  Future<void> _promptAddOrEditText({Offset? position, int? existingIndex}) async {
    final isEdit = existingIndex != null;

    final initial = isEdit
        ? texts[existingIndex!]
        : CanvasText(
            id: _uuid.v4(),
            text: '',
            position: position ?? const Offset(0, 0),
            color: currentColor,
            fontSize: 36,
          );

    final controllerText = TextEditingController(text: initial.text);
    double fontSize = initial.fontSize;
    Color color = initial.color;

    FontWeight fontWeight = initial.fontWeight;
    String? fontFamily = initial.fontFamily;
    bool italic = initial.italic;
    bool underline = initial.underline;
    TextAlign align = initial.align;

    bool bgEnabled = initial.backgroundColor != null;
    Color bgColor = initial.backgroundColor ?? Colors.black.withOpacity(0.08);
    double padding = initial.padding;

    bool wrapEnabled = (initial.maxWidth != null);
    double wrapWidth = (initial.maxWidth ?? 400).clamp(120, 1200);

    final fontFamilies = const <String?>[
      null,
      'Roboto',
      'Arial',
      'Times New Roman',
      'Georgia',
      'Courier New',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(isEdit ? 'Sửa văn bản' : 'Thêm văn bản'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controllerText,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 6,
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Nhập nội dung...',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Preview
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wrapEnabled ? wrapWidth : double.infinity,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(bgEnabled ? padding : 0),
                        decoration: BoxDecoration(
                          color: bgEnabled ? bgColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          controllerText.text.isEmpty
                              ? 'Preview'
                              : controllerText.text,
                          textAlign: align,
                          style: TextStyle(
                            color: color,
                            fontSize: fontSize,
                            fontWeight: fontWeight,
                            fontFamily: fontFamily,
                            fontStyle:
                                italic ? FontStyle.italic : FontStyle.normal,
                            decoration: underline
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Text('Font'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: fontFamily,
                          items: fontFamilies
                              .map(
                                (f) => DropdownMenuItem<String?>(
                                  value: f,
                                  child: Text(f ?? 'Default'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setLocal(() => fontFamily = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Text('Style'),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Bold',
                        onPressed: () => setLocal(() {
                          fontWeight =
                              fontWeight == FontWeight.w700 ? FontWeight.w600 : FontWeight.w700;
                        }),
                        icon: Icon(
                          Icons.format_bold,
                          color: fontWeight == FontWeight.w700
                              ? Colors.blueAccent
                              : Colors.black54,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Italic',
                        onPressed: () => setLocal(() => italic = !italic),
                        icon: Icon(
                          Icons.format_italic,
                          color: italic ? Colors.blueAccent : Colors.black54,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Underline',
                        onPressed: () => setLocal(() => underline = !underline),
                        icon: Icon(
                          Icons.format_underline,
                          color: underline ? Colors.blueAccent : Colors.black54,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Text('Align'),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Left',
                        onPressed: () => setLocal(() => align = TextAlign.left),
                        icon: Icon(
                          Icons.format_align_left,
                          color: align == TextAlign.left
                              ? Colors.blueAccent
                              : Colors.black54,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Center',
                        onPressed: () => setLocal(() => align = TextAlign.center),
                        icon: Icon(
                          Icons.format_align_center,
                          color: align == TextAlign.center
                              ? Colors.blueAccent
                              : Colors.black54,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Right',
                        onPressed: () => setLocal(() => align = TextAlign.right),
                        icon: Icon(
                          Icons.format_align_right,
                          color: align == TextAlign.right
                              ? Colors.blueAccent
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Text('Size'),
                      Expanded(
                        child: Slider(
                          value: fontSize.clamp(12, 180),
                          min: 12,
                          max: 180,
                          onChanged: (v) => setLocal(() => fontSize = v),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(fontSize.round().toString()),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Text('Color'),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setLocal(() => color = currentColor),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Tap vòng màu để dùng màu hiện tại'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Background'),
                    value: bgEnabled,
                    onChanged: (v) => setLocal(() => bgEnabled = v),
                  ),

                  if (bgEnabled) ...[
                    Row(
                      children: [
                        const Text('BG'),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setLocal(() => bgColor = Colors.black.withOpacity(0.08)),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: bgColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Tap để dùng nền mặc định'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Pad'),
                        Expanded(
                          child: Slider(
                            value: padding.clamp(0, 40),
                            min: 0,
                            max: 40,
                            onChanged: (v) => setLocal(() => padding = v),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(padding.round().toString()),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wrap width'),
                    value: wrapEnabled,
                    onChanged: (v) => setLocal(() => wrapEnabled = v),
                  ),

                  if (wrapEnabled)
                    Row(
                      children: [
                        const Text('W'),
                        Expanded(
                          child: Slider(
                            value: wrapWidth.clamp(120, 1200),
                            min: 120,
                            max: 1200,
                            onChanged: (v) => setLocal(() => wrapWidth = v),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(wrapWidth.round().toString()),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isEdit ? 'Cập nhật' : 'Thêm'),
              ),
            ],
          ),
        );
      },
    );

    if (result != true) return;
    final textValue = controllerText.text.trim();
    if (textValue.isEmpty) return;

    setState(() {
      if (isEdit) {
        final t = texts[existingIndex!];
        t.text = textValue;
        t.fontSize = fontSize;
        t.color = color;
        t.fontWeight = fontWeight;
        t.fontFamily = fontFamily;
        t.italic = italic;
        t.underline = underline;
        t.align = align;
        t.backgroundColor = bgEnabled ? bgColor : null;
        t.padding = padding;
        t.maxWidth = wrapEnabled ? wrapWidth : null;
        _selectedTextIndex = existingIndex;
        _selectedImageIndex = null;
      } else {
        final t = CanvasText(
          id: _uuid.v4(),
          text: textValue,
          position: position ?? const Offset(0, 0),
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
          italic: italic,
          underline: underline,
          align: align,
          backgroundColor: bgEnabled ? bgColor : null,
          padding: padding,
          maxWidth: wrapEnabled ? wrapWidth : null,
        );
        texts.add(t);
        _selectedTextIndex = texts.length - 1;
        _selectedImageIndex = null;
      }
      activeTool = ActiveTool.hand;
    });
  }

  void _deleteSelectedElement() {
    setState(() {
      if (_selectedImageIndex != null) {
        images.removeAt(_selectedImageIndex!);
        _selectedImageIndex = null;
      } else if (_selectedTextIndex != null) {
        texts.removeAt(_selectedTextIndex!);
        _selectedTextIndex = null;
      }
    });
  }

  void _scaleSelected(double factor) {
    setState(() {
      if (_selectedImageIndex != null) {
        images[_selectedImageIndex!].scale =
            (images[_selectedImageIndex!].scale * factor).clamp(0.05, 10.0);
      } else if (_selectedTextIndex != null) {
        texts[_selectedTextIndex!].scale =
            (texts[_selectedTextIndex!].scale * factor).clamp(0.2, 6.0);
      }
    });
  }

  void _rotateSelected(double deltaRadians) {
    setState(() {
      if (_selectedImageIndex != null) {
        images[_selectedImageIndex!].rotation += deltaRadians;
      } else if (_selectedTextIndex != null) {
        texts[_selectedTextIndex!].rotation += deltaRadians;
      }
    });
  }

  void _moveSelectedForward() {
    setState(() {
      if (_selectedImageIndex != null) {
        final idx = _selectedImageIndex!;
        if (idx < images.length - 1) {
          final item = images.removeAt(idx);
          images.insert(idx + 1, item);
          _selectedImageIndex = idx + 1;
        }
      } else if (_selectedTextIndex != null) {
        final idx = _selectedTextIndex!;
        if (idx < texts.length - 1) {
          final item = texts.removeAt(idx);
          texts.insert(idx + 1, item);
          _selectedTextIndex = idx + 1;
        }
      }
    });
  }

  void _moveSelectedBackward() {
    setState(() {
      if (_selectedImageIndex != null) {
        final idx = _selectedImageIndex!;
        if (idx > 0) {
          final item = images.removeAt(idx);
          images.insert(idx - 1, item);
          _selectedImageIndex = idx - 1;
        }
      } else if (_selectedTextIndex != null) {
        final idx = _selectedTextIndex!;
        if (idx > 0) {
          final item = texts.removeAt(idx);
          texts.insert(idx - 1, item);
          _selectedTextIndex = idx - 1;
        }
      }
    });
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
      texts: texts,
      onLoadingChanged: (val) => setState(() => isSaving = val),
    );
  }

  // HÀM LƯU TRANH
  Future<void> _saveDrawing() async {
    if (isSaving) return;
    setState(() => isSaving = true);

    try {
      // 1. Tạo Thumbnail nhỏ (Fix crash)
      Uint8List pngBytes = await _generateSmallThumbnail(
        _visibleStrokes,
        images: images,
        texts: texts,
        canvasColor: canvasColor,
      );

      // 2. Build document
      final doc = DrawingDocument(
        version: 2,
        strokes: _visibleStrokes,
        texts: List<CanvasText>.from(texts),
        images: images
            .where((img) => img.bytes != null && img.bytes!.isNotEmpty)
            .map(
              (img) => ImportedImagePersisted(
                id: img.id,
                position: img.position,
                scale: img.scale,
                rotation: img.rotation,
                bytes: img.bytes,
              ),
            )
            .toList(),
      );

      // 2. Lưu dữ liệu
      await StorageHelper.saveDrawing(
        widget.drawingId,
        doc: doc,
        thumbnailPngBytes: pngBytes,
        name: currentName,
      );

    } catch (e) {
      debugPrint("Lỗi lưu: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  //  HÀM TẠO THUMBNAIL (Helper)
  Future<Uint8List> _generateSmallThumbnail(
    List<Stroke> strokes, {
    required List<ImportedImage> images,
    required List<CanvasText> texts,
    required Color canvasColor,
  }) async {
    if (strokes.isEmpty && images.isEmpty && texts.isEmpty) return Uint8List(0);

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
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: t.color,
            fontSize: t.fontSize,
            fontWeight: t.fontWeight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final w = tp.width * t.scale;
      final h = tp.height * t.scale;
      final left = t.position.dx;
      final top = t.position.dy;
      final right = left + w;
      final bottom = top + h;
      if (left < minX) minX = left;
      if (top < minY) minY = top;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
    }

    minX -= 50; minY -= 50; maxX += 50; maxY += 50;
    double w = maxX - minX;
    double h = maxY - minY;
    if (w <= 0 || h <= 0) return Uint8List(0);

    const double thumbSize = 300.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, thumbSize, thumbSize));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, thumbSize, thumbSize),
      Paint()..color = canvasColor,
    );

    double scale = thumbSize / (w > h ? w : h);
    canvas.scale(scale);
    canvas.translate(-minX, -minY);

    final painter = DrawPainter(strokes, images, texts: texts);
    painter.paint(canvas, Size(w, h));

    final picture = recorder.endRecording();
    final img = await picture.toImage(thumbSize.toInt(), thumbSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // XỬ LÝ NÚT BACK
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
                          Positioned.fill(child: RepaintBoundary(child: CustomPaint(isComplex: false, foregroundPainter: DrawPainter(_visibleStrokes, images, texts: texts)))),
                          Positioned.fill(child: CustomPaint(foregroundPainter: DrawPainter(currentStroke == null ? [] : [currentStroke!], [], texts: const [], canvasColor: canvasColor, isPreview: true))),
                          Positioned.fill(
                            child: IgnorePointer(
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
                          ),
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
                onAddImage: _pickAndInsertImage,
                onAddText: () => setState(() => activeTool = ActiveTool.text),
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

                  // CẬP NHẬT CÁC THAM SỐ MỚI Ở ĐÂY:
                  activeTool: activeTool, // Truyền trạng thái hiện tại

                  onSelectBrush: () {
                    setState(() => activeTool = ActiveTool.brush);
                  },

                  onSelectEraser: () {
                    setState(() => activeTool = ActiveTool.eraser);
                  },

                  onSelectHand: () {
                    setState(() => activeTool = ActiveTool.hand);
                  },

                  onSelectText: () {
                    setState(() => activeTool = ActiveTool.text);
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

            if (_selectedImageIndex != null || _selectedTextIndex != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: _deleteSelectedElement,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.layers_outlined),
                          onPressed: _moveSelectedBackward,
                          tooltip: 'Đưa xuống dưới',
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.layers_rounded),
                          onPressed: _moveSelectedForward,
                          tooltip: 'Đưa lên trên',
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          onPressed: () => _scaleSelected(0.9),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          onPressed: () => _scaleSelected(1.1),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.rotate_left_rounded),
                          onPressed: () => _rotateSelected(-0.261799),
                          tooltip: 'Xoay -15°',
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.rotate_right_rounded),
                          onPressed: () => _rotateSelected(0.261799),
                          tooltip: 'Xoay +15°',
                        ),
                        if (_selectedTextIndex != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _promptAddOrEditText(existingIndex: _selectedTextIndex),
                          ),
                      ],
                    ),
                  ),
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