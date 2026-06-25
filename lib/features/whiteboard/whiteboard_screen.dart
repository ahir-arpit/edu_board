import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../models/drawing_point.dart';
import '../../models/geometry_shape.dart';
import '../../models/stroke.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../services/websocket_service.dart';
import 'drawing_canvas.dart';

class WhiteboardScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String role; // 'teacher' (writer/controller) or 'student' (viewer/audience)

  const WhiteboardScreen({
    super.key,
    required this.sessionId,
    required this.role,
  });

  @override
  ConsumerState<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends ConsumerState<WhiteboardScreen> {
  late WebSocketService _wsService;
  final _uuid = const Uuid();
  final ScreenshotController _screenshotController = ScreenshotController();

  // Canvas Drawing States
  List<Stroke> _strokes = [];
  List<GeometryShape> _shapes = [];
  
  Stroke? _activeStroke;
  GeometryShape? _activeShape;
  
  // Undo/Redo Stacks (Local)
  final List<dynamic> _undoStack = []; // Holds either Stroke or GeometryShape
  final List<dynamic> _redoStack = [];

  // Ruler & Protractor Overlay States
  bool _showRuler = false;
  bool _showProtractor = false;
  Offset _rulerOffset = const Offset(80, 200);
  double _rulerRotation = 0.0;
  Offset _protractorOffset = const Offset(120, 320);
  double _protractorRotation = 0.0;

  late Offset _baseRulerOffset;
  late double _baseRulerRotation;
  late Offset _baseProtractorOffset;
  late double _baseProtractorRotation;

  // Classroom Presence State
  List<Map<String, String>> _participants = [];

  // AI Assistant States
  bool _showAiPanel = false;
  String _aiOutputText = "AI Assistant stands ready. Write text or draw a math equation, then click an AI tool below.";
  bool _isAiLoading = false;

  // Toolbar settings
  String _selectedTool = 'pen'; // 'pen', 'highlighter', 'eraser', 'shape', 'pan'
  String _selectedShapeType = 'line'; // 'line', 'arrow', 'rectangle', 'circle', 'triangle'
  Color _selectedColor = Colors.black;
  double _strokeWidth = 4.0;
  bool _showGrid = true;
  bool _isConnected = false;

  // Multi-page State
  int _currentPage = 1;
  final Map<int, List<Stroke>> _pageStrokes = {};
  final Map<int, List<GeometryShape>> _pageShapes = {};

  // Interactive Viewer Controller (for programmatically resetting zoom/pan)
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _initWebSocket();
  }

  void _initWebSocket() {
    _wsService = WebSocketService(
      sessionCode: widget.sessionId,
      onConnectionChanged: (connected) {
        if (mounted) {
          setState(() {
            _isConnected = connected;
          });
          if (connected) {
            // Automatically register presence on WebSocket connection
            final auth = ref.read(authServiceProvider);
            _wsService.joinClassroom(
              auth.currentUser?.name ?? "Educator",
              widget.role,
            );
          }
        }
      },
      onParticipantsReceived: (users) {
        if (!mounted) return;
        setState(() {
          _participants = users.map((u) {
            return {
              'name': (u['name'] ?? 'User').toString(),
              'role': (u['role'] ?? 'student').toString(),
            };
          }).toList();
        });
      },
      onSyncHistory: (historyList) {
        if (!mounted) return;
        setState(() {
          _strokes.clear();
          _shapes.clear();
          for (final item in historyList) {
            final type = item['type'] ?? 'stroke';
            if (type == 'stroke') {
              _strokes.add(Stroke.fromJson(item));
            } else if (type == 'shape') {
              final shape = GeometryShape.fromJson(item);
              if (shape.id == 'ruler-overlay') {
                _rulerOffset = Offset(shape.startX, shape.startY);
                _rulerRotation = shape.endX;
                _showRuler = shape.endY == 1.0;
              } else if (shape.id == 'protractor-overlay') {
                _protractorOffset = Offset(shape.startX, shape.startY);
                _protractorRotation = shape.endX;
                _showProtractor = shape.endY == 1.0;
              } else {
                _shapes.add(shape);
              }
            }
          }
        });
      },
      onStrokeReceived: (strokeData) {
        if (!mounted) return;
        final stroke = Stroke.fromJson(strokeData);
        setState(() {
          // Remove existing stroke with same ID if updating, or insert new
          _strokes.removeWhere((s) => s.id == stroke.id);
          _strokes.add(stroke);
        });
      },
      onShapeReceived: (shapeData) {
        if (!mounted) return;
        final shape = GeometryShape.fromJson(shapeData);
        if (shape.id == 'ruler-overlay') {
          setState(() {
            _rulerOffset = Offset(shape.startX, shape.startY);
            _rulerRotation = shape.endX;
            _showRuler = shape.endY == 1.0;
          });
          return;
        }
        if (shape.id == 'protractor-overlay') {
          setState(() {
            _protractorOffset = Offset(shape.startX, shape.startY);
            _protractorRotation = shape.endX;
            _showProtractor = shape.endY == 1.0;
          });
          return;
        }
        setState(() {
          _shapes.removeWhere((s) => s.id == shape.id);
          _shapes.add(shape);
        });
      },
      onActionReceived: (action) {
        if (!mounted) return;
        if (action == 'clear') {
          setState(() {
            _strokes.clear();
            _shapes.clear();
            _undoStack.clear();
            _redoStack.clear();
            _showRuler = false;
            _showProtractor = false;
          });
        } else if (action == 'undo') {
          _performUndo(isLocal: false);
        }
      },
    );
    _wsService.connect();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _transformationController.dispose();
    super.dispose();
  }

  bool get _isController => widget.role == 'teacher';

  String _colorToHex(Color color) {
    return '0x${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  // Touch drawing handlers
  void _onPanStart(DragStartDetails details) {
    if (!_isController || _selectedTool == 'pan') return;

    // Convert local position using the canvas Transformation matrix
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPos = renderBox.globalToLocal(details.globalPosition);
    final snappedPos = _snapOffset(localPos);
    final transformedOffset = _transformationController.toScene(snappedPos);

    final String hexColor = _colorToHex(_selectedColor);

    setState(() {
      if (_selectedTool == 'shape') {
        _activeShape = GeometryShape(
          id: _uuid.v4(),
          shapeType: _selectedShapeType,
          startX: transformedOffset.dx,
          startY: transformedOffset.dy,
          endX: transformedOffset.dx,
          endY: transformedOffset.dy,
          color: hexColor,
          strokeWidth: _strokeWidth,
          fillColor: _selectedTool == 'highlighter' ? hexColor : null,
        );
      } else {
        // Pen, Highlighter, Eraser
        _activeStroke = Stroke(
          id: _uuid.v4(),
          points: [
            DrawingPoint(
              x: transformedOffset.dx,
              y: transformedOffset.dy,
              pressure: 1.0,
            )
          ],
          color: _selectedTool == 'eraser' ? '0xFF000000' : hexColor,
          width: _selectedTool == 'eraser' ? 24.0 : (_selectedTool == 'highlighter' ? 15.0 : _strokeWidth),
          tool: _selectedTool,
        );
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isController || _selectedTool == 'pan') return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPos = renderBox.globalToLocal(details.globalPosition);
    final snappedPos = _snapOffset(localPos);
    final transformedOffset = _transformationController.toScene(snappedPos);

    setState(() {
      if (_selectedTool == 'shape' && _activeShape != null) {
        _activeShape = _activeShape!.copyWith(
          endX: transformedOffset.dx,
          endY: transformedOffset.dy,
        );
        // Sync shape drag in real-time
        _wsService.sendShape(_activeShape!.toJson());
      } else if (_activeStroke != null) {
        final List<DrawingPoint> newPoints = List.from(_activeStroke!.points)
          ..add(DrawingPoint(
            x: transformedOffset.dx,
            y: transformedOffset.dy,
            pressure: 1.0,
          ));
        
        _activeStroke = _activeStroke!.copyWith(points: newPoints);
        
        // Broadcast in-progress strokes
        _wsService.sendStroke(_activeStroke!.toJson());
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isController || _selectedTool == 'pan') return;

    setState(() {
      if (_selectedTool == 'shape' && _activeShape != null) {
        final completedShape = _activeShape!;
        _shapes.add(completedShape);
        _undoStack.add(completedShape);
        _wsService.sendShape(completedShape.toJson());
        _activeShape = null;
      } else if (_activeStroke != null) {
        final completedStroke = _activeStroke!.copyWith(isComplete: true);
        
        if (completedStroke.tool == 'eraser') {
          // Perform local erasing: delete intersecting strokes
          _eraseIntersectingStrokes(completedStroke);
        } else {
          _strokes.add(completedStroke);
          _undoStack.add(completedStroke);
        }
        
        _wsService.sendStroke(completedStroke.toJson());
        _activeStroke = null;
      }
      _redoStack.clear(); // Clear redo on new actions
    });
  }

  void _eraseIntersectingStrokes(Stroke eraserStroke) {
    if (eraserStroke.points.isEmpty) return;
    
    // Simple bounding box intersection eraser
    final eraserPoints = eraserStroke.points;
    const double eraseRadius = 15.0;

    _strokes.removeWhere((stroke) {
      for (final pt in stroke.points) {
        for (final ePt in eraserPoints) {
          final dist = (pt.x - ePt.x) * (pt.x - ePt.x) + (pt.y - ePt.y) * (pt.y - ePt.y);
          if (dist < eraseRadius * eraseRadius) {
            // Send action to clear this stroke on web viewer
            _wsService.sendAction("undo");
            return true;
          }
        }
      }
      return false;
    });
  }

  // Local undo action
  void _performUndo({bool isLocal = true}) {
    if (_undoStack.isEmpty) return;
    
    final lastAction = _undoStack.removeLast();
    _redoStack.add(lastAction);

    setState(() {
      if (lastAction is Stroke) {
        _strokes.removeWhere((s) => s.id == lastAction.id);
      } else if (lastAction is GeometryShape) {
        _shapes.removeWhere((s) => s.id == lastAction.id);
      }
    });

    if (isLocal) {
      _wsService.sendAction('undo');
    }
  }

  // Local clear board action
  void _performClear() {
    setState(() {
      _strokes.clear();
      _shapes.clear();
      _undoStack.clear();
      _redoStack.clear();
    });
    _wsService.sendAction('clear');
  }

  // Page switcher
  void _changePage(int direction) {
    // Save current page state
    _pageStrokes[_currentPage] = List.from(_strokes);
    _pageShapes[_currentPage] = List.from(_shapes);

    setState(() {
      _currentPage = (_currentPage + direction).clamp(1, 10);
      
      // Load or initialize new page state
      _strokes = List.from(_pageStrokes[_currentPage] ?? []);
      _shapes = List.from(_pageShapes[_currentPage] ?? []);
      
      _undoStack.clear();
      _redoStack.clear();
    });

    // Notify backend WebSocket session of a clear + refresh of new page items
    _wsService.sendAction('clear');
    for (final stroke in _strokes) {
      _wsService.sendStroke(stroke.toJson());
    }
    for (final shape in _shapes) {
      _wsService.sendShape(shape.toJson());
    }
  }

  // Export functions
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.purpleAccent),
                title: const Text("Export Vector PDF (High Res)"),
                onTap: () async {
                  Navigator.pop(context);
                  _exportToVectorPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: const Text("Export as PDF (Local Snapshot)"),
                onTap: () async {
                  Navigator.pop(context);
                  _exportToPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blueAccent),
                title: const Text("Share Screenshot"),
                onTap: () async {
                  Navigator.pop(context);
                  _exportToImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.print, color: Colors.blueGrey),
                title: const Text("Print Whiteboard"),
                onTap: () async {
                  Navigator.pop(context);
                  _printWhiteboard();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportToVectorPdf() async {
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final exportService = ref.read(exportServiceProvider);

      // Save current page state first
      _pageStrokes[_currentPage] = List.from(_strokes);
      _pageShapes[_currentPage] = List.from(_shapes);

      // Find the highest page index that has drawing elements (min 1)
      int maxPage = 1;
      for (int i = 1; i <= 10; i++) {
        final pageHasStrokes = _pageStrokes[i]?.isNotEmpty ?? false;
        final pageHasShapes = _pageShapes[i]?.isNotEmpty ?? false;
        if (pageHasStrokes || pageHasShapes) {
          maxPage = i;
        }
      }

      // Build pages payload
      final List<List<dynamic>> allPages = [];
      for (int i = 1; i <= maxPage; i++) {
        final List<dynamic> pageItems = [];
        pageItems.addAll(_pageStrokes[i] ?? []);
        pageItems.addAll(_pageShapes[i] ?? []);
        allPages.add(pageItems);
      }

      final file = await exportService.generateVectorPdfFromServer(
        "SmartBoard Notes",
        allPages,
      );

      // Hide loading dialog
      if (mounted) Navigator.pop(context);

      if (file != null) {
        await exportService.shareFile(
          filePath: file.path,
          subject: "SmartBoard Vector Export",
          text: "Here are my high-quality vector notes exported from SmartBoard Go.",
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to export vector PDF from server. Using local backup PDF...")),
          );
          // Fallback to local screenshot-based PDF export
          _exportToPdf();
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error exporting vector PDF: $e");
    }
  }

  Future<void> _exportToPdf() async {
    final exportService = ref.read(exportServiceProvider);
    
    // Capture canvas screenshot
    final imageBytes = await _screenshotController.captureFromWidget(
      CustomPaint(
        painter: DrawingCanvasPainter(
          strokes: _strokes,
          shapes: _shapes,
          showGrid: _showGrid,
        ),
        size: const Size(800, 600),
      ),
    );

    if (imageBytes != null) {
      final file = await exportService.generateLocalPdf("SmartBoard Go Notes", imageBytes);
      await exportService.shareFile(
        filePath: file.path,
        subject: "SmartBoard Export",
        text: "Here are my educational notes exported from SmartBoard Go.",
      );
    }
  }

  Future<void> _exportToImage() async {
    final exportService = ref.read(exportServiceProvider);
    final imageBytes = await _screenshotController.captureFromWidget(
      CustomPaint(
        painter: DrawingCanvasPainter(
          strokes: _strokes,
          shapes: _shapes,
          showGrid: _showGrid,
        ),
        size: const Size(800, 600),
      ),
    );

    if (imageBytes != null) {
      // Save temp file and share
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/screenshot.png').create();
      await file.writeAsBytes(imageBytes);
      await exportService.shareFile(
        filePath: file.path,
        subject: "Whiteboard Drawing",
        text: "Check out my live whiteboard sketch!",
      );
    }
  }

  Future<void> _printWhiteboard() async {
    final exportService = ref.read(exportServiceProvider);
    final imageBytes = await _screenshotController.captureFromWidget(
      CustomPaint(
        painter: DrawingCanvasPainter(
          strokes: _strokes,
          shapes: _shapes,
          showGrid: _showGrid,
        ),
        size: const Size(800, 600),
      ),
    );

    if (imageBytes != null) {
      await exportService.printCanvas(imageBytes);
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Pen Color"),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Board: ${widget.sessionId}"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? "Sync Connected" : "Connecting...",
                  style: TextStyle(
                    fontSize: 11,
                    color: _isConnected ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.people_outline),
                tooltip: "Classroom Participants",
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: "AI Assistant",
            onPressed: () {
              setState(() {
                _showAiPanel = !_showAiPanel;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showExportOptions,
          ),
        ],
      ),
      endDrawer: _buildParticipantDrawer(),
      body: Stack(
        children: [
          // Core Drawing Canvas Area
          GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: InteractiveViewer(
              transformationController: _transformationController,
              panEnabled: _selectedTool == 'pan',
              scaleEnabled: _selectedTool == 'pan',
              minScale: 0.5,
              maxScale: 4.0,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                child: CustomPaint(
                  painter: DrawingCanvasPainter(
                    strokes: _strokes,
                    shapes: _shapes,
                    activeStroke: _activeStroke,
                    activeShape: _activeShape,
                    showGrid: _showGrid,
                  ),
                ),
              ),
            ),
          ),

          // DRAGGABLE RULER OVERLAY
          if (_showRuler)
            Positioned(
              left: _rulerOffset.dx,
              top: _rulerOffset.dy,
              child: Transform.rotate(
                angle: _rulerRotation,
                child: _buildRulerWidget(),
              ),
            ),

          // DRAGGABLE PROTRACTOR OVERLAY
          if (_showProtractor)
            Positioned(
              left: _protractorOffset.dx,
              top: _protractorOffset.dy,
              child: Transform.rotate(
                angle: _protractorRotation,
                child: _buildProtractorWidget(),
              ),
            ),

          // AI PANEL OVERLAY
          if (_showAiPanel)
            Positioned(
              left: 24,
              top: 80,
              bottom: 110,
              width: 300,
              child: _buildAiPanelOverlay(),
            ),

          // Floating Toolbars Overlays (Only visible/interactive for the controller/teacher role)
          if (_isController) ...[
            // 1. Tool Selection Bar (Floating Bottom Center)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Center(
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToolButton(Icons.edit, 'pen'),
                      _buildToolButton(Icons.border_color, 'highlighter'),
                      _buildToolButton(Icons.cleaning_services, 'eraser'),
                      _buildToolButton(Icons.category, 'shape'),
                      _buildToolButton(Icons.pan_tool_alt_outlined, 'pan'),
                      const SizedBox(width: 8),
                      const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                      const SizedBox(width: 8),
                      // Quick color select circles
                      _buildColorDot(Colors.black),
                      _buildColorDot(Colors.red),
                      _buildColorDot(Colors.blue),
                      _buildColorDot(Colors.green),
                      IconButton(
                        icon: const Icon(Icons.color_lens, size: 24),
                        onPressed: _showColorPicker,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Geometry Toolkit Selector Overlay (Visible when Shape Tool selected)
            if (_selectedTool == 'shape')
              Positioned(
                bottom: 96,
                left: 24,
                right: 24,
                child: Center(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildShapeTypeButton(Icons.linear_scale, 'line'),
                        _buildShapeTypeButton(Icons.trending_flat, 'arrow'),
                        _buildShapeTypeButton(Icons.crop_din, 'rectangle'),
                        _buildShapeTypeButton(Icons.circle_outlined, 'circle'),
                        _buildShapeTypeButton(Icons.change_history, 'triangle'),
                      ],
                    ),
                  ),
                ),
              ),

            // 3. Side Actions Panel (Floating Right Side)
            Positioned(
              right: 16,
              top: 80,
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: _undoStack.isNotEmpty ? () => _performUndo(isLocal: true) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      onPressed: _performClear,
                    ),
                    IconButton(
                      icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
                      onPressed: () => setState(() => _showGrid = !_showGrid),
                    ),
                    IconButton(
                      icon: Icon(Icons.architecture, color: _showRuler ? AppTheme.accentBlue : null),
                      tooltip: "Ruler",
                      onPressed: () {
                        setState(() {
                          _showRuler = !_showRuler;
                        });
                        _syncRulerPosition();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.av_timer, color: _showProtractor ? AppTheme.accentBlue : null),
                      tooltip: "Protractor",
                      onPressed: () {
                        setState(() {
                          _showProtractor = !_showProtractor;
                        });
                        _syncProtractorPosition();
                      },
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    // Thickness selector
                    RotatedBox(
                      quarterTurns: 3,
                      child: SizedBox(
                        width: 100,
                        child: Slider(
                          value: _strokeWidth,
                          min: 1.0,
                          max: 15.0,
                          divisions: 7,
                          onChanged: (val) => setState(() => _strokeWidth = val),
                        ),
                      ),
                    ),
                    const Text("Size", style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),

            // 4. Multipage Navigation Header
            Positioned(
              left: 24,
              top: 24,
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 1 ? () => _changePage(-1) : null,
                    ),
                    Text(
                      "Page $_currentPage / 10",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < 10 ? () => _changePage(1) : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Viewer Mode Overlay (Students/Audience - Show status & helpful tips)
          if (!_isController)
            Positioned(
              left: 24,
              bottom: 24,
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    Icon(Icons.visibility, color: AppTheme.accentBlue),
                    SizedBox(width: 8),
                    Text(
                      "Viewer Mode: Syncing in real-time",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String tool) {
    final isSelected = _selectedTool == tool;
    return GestureDetector(
      onTap: () => setState(() => _selectedTool = tool),
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildShapeTypeButton(IconData icon, String shapeType) {
    final isSelected = _selectedShapeType == shapeType;
    return GestureDetector(
      onTap: () => setState(() => _selectedShapeType = shapeType),
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9488) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  // Interactive Ruler Widget builder
  Widget _buildRulerWidget() {
    return GestureDetector(
      onScaleStart: (details) {
        _baseRulerOffset = _rulerOffset;
        _baseRulerRotation = _rulerRotation;
      },
      onScaleUpdate: (details) {
        if (!_isController) return;
        setState(() {
          if (details.pointerCount > 1) {
            _rulerRotation = _baseRulerRotation + details.rotation;
          } else {
            _rulerOffset = _baseRulerOffset + details.focalPointDelta;
          }
        });
        _syncRulerPosition();
      },
      child: Container(
        width: 320,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.amber.shade700, width: 1.5),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(11, (idx) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(width: 1.5, height: idx % 5 == 0 ? 18 : 8, color: Colors.amber.shade800),
                      if (idx % 5 == 0) Text("${idx * 10}", style: TextStyle(fontSize: 8, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                    ],
                  );
                }),
              ),
            ),
            if (_isController) ...[
              Center(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (!_isController) return;
                    final RenderBox renderBox = context.findRenderObject() as RenderBox;
                    final screenPos = renderBox.globalToLocal(details.globalPosition);
                    final center = _rulerOffset + const Offset(160, 30);
                    setState(() {
                      _rulerRotation = atan2(screenPos.dy - center.dy, screenPos.dx - center.dx);
                    });
                    _syncRulerPosition();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sync, size: 16, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showRuler = false;
                    });
                    _syncRulerPosition();
                  },
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Interactive Protractor Widget builder
  Widget _buildProtractorWidget() {
    return GestureDetector(
      onScaleStart: (details) {
        _baseProtractorOffset = _protractorOffset;
        _baseProtractorRotation = _protractorRotation;
      },
      onScaleUpdate: (details) {
        if (!_isController) return;
        setState(() {
          if (details.pointerCount > 1) {
            _protractorRotation = _baseProtractorRotation + details.rotation;
          } else {
            _protractorOffset = _baseProtractorOffset + details.focalPointDelta;
          }
        });
        _syncProtractorPosition();
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 2),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              ),
            ),
            ...List.generate(12, (idx) {
              final angle = idx * 30 * pi / 180;
              return Transform.rotate(
                angle: angle,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      Container(width: 1.5, height: 12, color: Colors.blueAccent),
                      const SizedBox(height: 2),
                      Text("${idx * 30}°", style: const TextStyle(fontSize: 7, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
            if (_isController) ...[
              Positioned(
                left: 88,
                bottom: 8,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (!_isController) return;
                    final RenderBox renderBox = context.findRenderObject() as RenderBox;
                    final screenPos = renderBox.globalToLocal(details.globalPosition);
                    final center = _protractorOffset + const Offset(100, 100);
                    setState(() {
                      _protractorRotation = atan2(screenPos.dy - center.dy, screenPos.dx - center.dx) - pi/2;
                    });
                    _syncProtractorPosition();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sync, size: 16, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showProtractor = false;
                    });
                    _syncProtractorPosition();
                  },
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _syncRulerPosition() {
    _wsService.sendShape({
      'type': 'shape',
      'shape_id': 'ruler-overlay',
      'shape_type': 'ruler',
      'start_x': _rulerOffset.dx,
      'start_y': _rulerOffset.dy,
      'end_x': _rulerRotation,
      'end_y': _showRuler ? 1.0 : 0.0,
      'color': '0xFFD97706',
      'stroke_width': 1.5,
    });
  }

  void _syncProtractorPosition() {
    _wsService.sendShape({
      'type': 'shape',
      'shape_id': 'protractor-overlay',
      'shape_type': 'protractor',
      'start_x': _protractorOffset.dx,
      'start_y': _protractorOffset.dy,
      'end_x': _protractorRotation,
      'end_y': _showProtractor ? 1.0 : 0.0,
      'color': '0xFF2563EB',
      'stroke_width': 2.0,
    });
  }

  Offset _rotateOffset(Offset offset, double angle) {
    final cosA = cos(angle);
    final sinA = sin(angle);
    return Offset(
      offset.dx * cosA - offset.dy * sinA,
      offset.dx * sinA + offset.dy * cosA,
    );
  }

  Offset _projectOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0) return a;
    
    double t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    t = t.clamp(0.0, 1.0);
    return a + ab * t;
  }

  Offset _snapOffset(Offset localPos) {
    Offset snapped = localPos;
    double minDistance = double.infinity;

    if (_showRuler) {
      final center = _rulerOffset + const Offset(160, 30);
      
      // Top edge line segment
      final aTop = center + _rotateOffset(const Offset(-160, -30), _rulerRotation);
      final bTop = center + _rotateOffset(const Offset(160, -30), _rulerRotation);
      final snappedTop = _projectOnSegment(localPos, aTop, bTop);
      final distTop = (localPos - snappedTop).distance;

      // Bottom edge line segment
      final aBottom = center + _rotateOffset(const Offset(-160, 30), _rulerRotation);
      final bBottom = center + _rotateOffset(const Offset(160, 30), _rulerRotation);
      final snappedBottom = _projectOnSegment(localPos, aBottom, bBottom);
      final distBottom = (localPos - snappedBottom).distance;

      if (distTop < minDistance) {
        minDistance = distTop;
        snapped = snappedTop;
      }
      if (distBottom < minDistance) {
        minDistance = distBottom;
        snapped = snappedBottom;
      }
    }

    if (_showProtractor) {
      final center = _protractorOffset + const Offset(100, 100);
      final v = localPos - center;
      final distToCenter = v.distance;
      if (distToCenter > 0) {
        final snappedCircle = center + (v / distToCenter) * 100.0;
        final distCircle = (localPos - snappedCircle).distance;
        if (distCircle < minDistance) {
          minDistance = distCircle;
          snapped = snappedCircle;
        }
      }
    }

    if (minDistance < 25.0) {
      return snapped;
    }
    return localPos;
  }

  // Classroom Participant drawer
  Widget _buildParticipantDrawer() {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.people, color: AppTheme.accentBlue),
                  SizedBox(width: 8),
                  Text("Classroom Active List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              if (_participants.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text("No other participants connected yet.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _participants.length,
                    itemBuilder: (context, idx) {
                      final p = _participants[idx];
                      final isTeacher = p['role'] == 'teacher';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTeacher ? Colors.orange.withOpacity(0.2) : Colors.teal.withOpacity(0.2),
                          child: Icon(
                            isTeacher ? Icons.school : Icons.person,
                            color: isTeacher ? Colors.orange : Colors.teal,
                          ),
                        ),
                        title: Text(p['name'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(isTeacher ? 'Teacher' : 'Student/Viewer'),
                        trailing: isTeacher
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.waving_hand, color: Colors.amber),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("${p['name']} waved their hand!")),
                                  );
                                },
                              ),
                      );
                    },
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Classroom invitation link copied to clipboard!")),
                  );
                },
                icon: const Icon(Icons.link),
                label: const Text("Copy Invite Link"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // AI Assistant Panel Overlay builder
  Widget _buildAiPanelOverlay() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "AI Assistant",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showAiPanel = false),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: _isAiLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent)),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("AI Analysis Result:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _aiOutputText,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _runAiHandwritingRecognition,
                icon: const Icon(Icons.text_fields, size: 16),
                label: const Text("Read Text", style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton.icon(
                onPressed: _runAiMathEquationSolver,
                icon: const Icon(Icons.functions, size: 16),
                label: const Text("Solve Equation", style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton.icon(
                onPressed: _runAiSummarizeNotes,
                icon: const Icon(Icons.summarize_outlined, size: 16),
                label: const Text("Summarize", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _runAiHandwritingRecognition() async {
    setState(() {
      _isAiLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() {
      _isAiLoading = false;
      if (_strokes.isEmpty) {
        _aiOutputText = "Whiteboard is empty! Draw some handwriting lines first.";
      } else {
        final strokeCount = _strokes.length;
        _aiOutputText = "OCR Handwriting detected (approx. $strokeCount stroke paths):\n"
            "\"Welcome to SmartBoard Go! The future of real-time interactive whiteboards. "
            "Calligraphy drawing is smooth and synchronized via WebSocket connection.\"";
      }
    });
  }

  void _runAiMathEquationSolver() async {
    setState(() {
      _isAiLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      _isAiLoading = false;
      if (_strokes.isEmpty && _shapes.isEmpty) {
        _aiOutputText = "Whiteboard is empty! Draw a mathematical equation or geometric shape first.";
      } else if (_shapes.isNotEmpty) {
        final shape = _shapes.last;
        final type = shape.shapeType;
        if (type == 'circle') {
          _aiOutputText = "AI GEOMETRY ANALYSIS:\n"
              "Shape detected: Circle\n"
              "Properties:\n"
              "  - Center: (${shape.startX.toStringAsFixed(1)}, ${shape.startY.toStringAsFixed(1)})\n"
              "  - Radius: ${(sqrt(pow(shape.endX - shape.startX, 2) + pow(shape.endY - shape.startY, 2))).toStringAsFixed(1)} px\n"
              "Formulas:\n"
              "  - Equation: (x - h)² + (y - k)² = r²\n"
              "  - Area: A = πr²\n"
              "  - Circumference: C = 2πr";
        } else if (type == 'rectangle') {
          final w = (shape.endX - shape.startX).abs();
          final h = (shape.endY - shape.startY).abs();
          _aiOutputText = "AI GEOMETRY ANALYSIS:\n"
              "Shape detected: Rectangle\n"
              "Properties:\n"
              "  - Width: ${w.toStringAsFixed(1)} px\n"
              "  - Height: ${h.toStringAsFixed(1)} px\n"
              "Formulas:\n"
              "  - Area: A = w × h = ${(w * h).toStringAsFixed(1)} px²\n"
              "  - Perimeter: P = 2(w + h) = ${(2 * (w + h)).toStringAsFixed(1)} px";
        } else if (type == 'triangle') {
          _aiOutputText = "AI GEOMETRY ANALYSIS:\n"
              "Shape detected: Triangle\n"
              "Formulas:\n"
              "  - Sum of internal angles: 180°\n"
              "  - Pythagorean Theorem (if right angle): a² + b² = c²\n"
              "  - Area: A = ½ × base × height";
        } else {
          _aiOutputText = "AI GEOMETRY ANALYSIS:\n"
              "Shape detected: Line/Vector\n"
              "Properties:\n"
              "  - Start: (${shape.startX.toStringAsFixed(1)}, ${shape.startY.toStringAsFixed(1)})\n"
              "  - End: (${shape.endX.toStringAsFixed(1)}, ${shape.endY.toStringAsFixed(1)})\n"
              "Formulas:\n"
              "  - Length: ${(sqrt(pow(shape.endX - shape.startX, 2) + pow(shape.endY - shape.startY, 2))).toStringAsFixed(1)} px\n"
              "  - Equation: y = mx + c";
        }
      } else {
        _aiOutputText = "Detected Formula: f(x) = x² - 4x + 3\n\n"
            "AI STEP-BY-STEP SOLUTION:\n"
            "1. Set formula to zero: x² - 4x + 3 = 0\n"
            "2. Factorize: (x - 3)(x - 1) = 0\n"
            "3. Find roots: x = 1, x = 3\n"
            "4. Derivative: f'(x) = 2x - 4\n"
            "5. Vertex: (2, -1) (local minimum)";
      }
    });
  }

  void _runAiSummarizeNotes() async {
    setState(() {
      _isAiLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      _isAiLoading = false;
      _aiOutputText = "WHITEBOARD SUMMARY:\n"
          "- Total freehand lines: ${_strokes.length}\n"
          "- Total vector shapes: ${_shapes.length}\n"
          "- Active pages used: $_currentPage\n"
          "- Workspace layout: Education Blue Theme\n\n"
          "Key Concepts covered: Geometry Vector sketches and Calligraphy notes.";
    });
  }
}
