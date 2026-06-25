import 'dart:math';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../../models/stroke.dart';
import '../../models/geometry_shape.dart';

class DrawingCanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<GeometryShape> shapes;
  final Stroke? activeStroke;
  final GeometryShape? activeShape;
  final bool showGrid;
  final Color gridColor;

  DrawingCanvasPainter({
    required this.strokes,
    required this.shapes,
    this.activeStroke,
    this.activeShape,
    this.showGrid = true,
    this.gridColor = const Color(0x1F2563EB), // Soft blue tint grid line
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Background Grid if enabled
    if (showGrid) {
      _drawGraphGrid(canvas, size);
    }

    // 2. Draw completed vector shapes
    for (final shape in shapes) {
      _drawGeometryShape(canvas, shape);
    }

    // 3. Draw active vector shape (in-progress drawing feedback)
    if (activeShape != null) {
      _drawGeometryShape(canvas, activeShape!);
    }

    // 4. Draw completed freehand strokes
    for (final stroke in strokes) {
      _drawFreehandStroke(canvas, stroke);
    }

    // 5. Draw active freehand stroke (in-progress drawing feedback)
    if (activeStroke != null) {
      _drawFreehandStroke(canvas, activeStroke!);
    }
  }

  // Draw background graph paper grids
  void _drawGraphGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const double gridSpacing = 30.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  // Render a freehand stroke with calligraphy effect using perfect_freehand
  void _drawFreehandStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    // Setup paint based on tool type
    final paint = Paint();
    final colorVal = _parseColor(stroke.color);
    
    if (stroke.tool == 'eraser') {
      // For eraser representation, we skip drawing or draw transparent/background color if not using clipping.
      // Since it's a simplified drawing model, the backend handles stroke deletion, and completed canvas
      // filtered lists don't include erased strokes. However, while drawing, we can show a grey stroke.
      paint.color = Colors.grey.withValues(alpha: 0.4);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = stroke.width;
      paint.strokeCap = StrokeCap.round;
      paint.strokeJoin = StrokeJoin.round;
    } else if (stroke.tool == 'highlighter') {
      paint.color = colorVal.withValues(alpha: 0.35); // Semi-transparent
      paint.style = PaintingStyle.fill;
    } else {
      // Regular pen
      paint.color = colorVal;
      paint.style = PaintingStyle.fill;
    }

    // Extract points as PointVector types for perfect_freehand
    final List<PointVector> perfectPoints = stroke.points
        .map((p) => PointVector(p.x, p.y, p.pressure))
        .toList();

    // Generate calligraphic outline
    final outlinePoints = getStroke(
      perfectPoints,
      options: StrokeOptions(
        size: stroke.width,
        thinning: stroke.tool == 'highlighter' ? 0.0 : 0.6,
        smoothing: 0.5,
        streamline: 0.55,
      ),
    );

    if (outlinePoints.isEmpty) return;

    // Draw outline points as a filled path
    final path = Path();
    path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
    
    for (int i = 1; i < outlinePoints.length; i++) {
      path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
    }
    path.close();

    if (stroke.tool == 'eraser') {
      // Just draw dashed or direct lines for eraser track
      final linePath = Path();
      linePath.moveTo(stroke.points.first.x, stroke.points.first.y);
      for (int i = 1; i < stroke.points.length; i++) {
        linePath.lineTo(stroke.points[i].x, stroke.points[i].y);
      }
      canvas.drawPath(linePath, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  // Render a vector geometry shape
  void _drawGeometryShape(Canvas canvas, GeometryShape shape) {
    final paint = Paint()
      ..color = _parseColor(shape.color)
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final start = Offset(shape.startX, shape.startY);
    final end = Offset(shape.endX, shape.endY);

    switch (shape.shapeType) {
      case 'line':
        canvas.drawLine(start, end, paint);
        break;
        
      case 'arrow':
        // Draw main line
        canvas.drawLine(start, end, paint);
        
        // Draw arrowhead at end
        final double angle = atan2(end.dy - start.dy, end.dx - start.dx);
        const double arrowLength = 15.0;
        const double arrowAngle = pi / 6; // 30 degrees

        final arrowPath = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(
            end.dx - arrowLength * cos(angle - arrowAngle),
            end.dy - arrowLength * sin(angle - arrowAngle),
          )
          ..moveTo(end.dx, end.dy)
          ..lineTo(
            end.dx - arrowLength * cos(angle + arrowAngle),
            end.dy - arrowLength * sin(angle + arrowAngle),
          );
        canvas.drawPath(arrowPath, paint);
        break;
        
      case 'rectangle':
        final rect = Rect.fromPoints(start, end);
        // Fill if color is supplied
        if (shape.fillColor != null) {
          final fillPaint = Paint()
            ..color = _parseColor(shape.fillColor!).withValues(alpha: 0.25)
            ..style = PaintingStyle.fill;
          canvas.drawRect(rect, fillPaint);
        }
        canvas.drawRect(rect, paint);
        break;
        
      case 'circle':
        final double dx = end.dx - start.dx;
        final double dy = end.dy - start.dy;
        final double radius = sqrt(dx * dx + dy * dy);
        
        // Fill if color is supplied
        if (shape.fillColor != null) {
          final fillPaint = Paint()
            ..color = _parseColor(shape.fillColor!).withValues(alpha: 0.25)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(start, radius, fillPaint);
        }
        canvas.drawCircle(start, radius, paint);
        break;
        
      case 'triangle':
        final double midX = (start.dx + end.dx) / 2.0;
        final trianglePath = Path()
          ..moveTo(midX, end.dy) // Apex
          ..lineTo(start.dx, start.dy) // Bottom left
          ..lineTo(end.dx, start.dy) // Bottom right
          ..close();

        // Fill if color is supplied
        if (shape.fillColor != null) {
          final fillPaint = Paint()
            ..color = _parseColor(shape.fillColor!).withValues(alpha: 0.25)
            ..style = PaintingStyle.fill;
          canvas.drawPath(trianglePath, fillPaint);
        }
        canvas.drawPath(trianglePath, paint);
        break;
    }
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('0xFF') || colorStr.startsWith('0xff')) {
        return Color(int.parse(colorStr));
      } else if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
      }
    } catch (_) {}
    return Colors.black;
  }

  @override
  bool shouldRepaint(covariant DrawingCanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.shapes != shapes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.activeShape != activeShape ||
        oldDelegate.showGrid != showGrid;
  }
}
