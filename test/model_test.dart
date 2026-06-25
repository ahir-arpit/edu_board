import 'package:flutter_test/flutter_test.dart';
import 'package:edu_board/models/drawing_point.dart';
import 'package:edu_board/models/geometry_shape.dart';
import 'package:edu_board/models/stroke.dart';

void main() {
  group('DrawingPoint Model Tests', () {
    test('toJson and fromJson serializes correctly with double pressure', () {
      const point = DrawingPoint(x: 100.0, y: 150.0, pressure: 0.85);
      final json = point.toJson();
      
      expect(json['x'], 100.0);
      expect(json['y'], 150.0);
      expect(json['p'], 0.85);

      final parsed = DrawingPoint.fromJson(json);
      expect(parsed.x, 100.0);
      expect(parsed.y, 150.0);
      expect(parsed.pressure, 0.85);
    });

    test('fromJson parses integer coordinate inputs safely', () {
      final json = {'x': 100, 'y': 150, 'p': 1};
      final parsed = DrawingPoint.fromJson(json);
      
      expect(parsed.x, 100.0);
      expect(parsed.y, 150.0);
      expect(parsed.pressure, 1.0);
    });
  });

  group('Stroke Model Tests', () {
    test('toJson and fromJson serializes correctly', () {
      final stroke = Stroke(
        id: 'stroke-123',
        points: [
          const DrawingPoint(x: 10.0, y: 20.0, pressure: 0.5),
          const DrawingPoint(x: 15.0, y: 25.0, pressure: 0.7),
        ],
        color: '0xFF2196F3',
        width: 4.0,
        tool: 'pen',
        isComplete: true,
      );

      final json = stroke.toJson();
      expect(json['type'], 'stroke');
      expect(json['stroke_id'], 'stroke-123');
      expect(json['color'], '0xFF2196F3');
      expect(json['width'], 4.0);
      expect(json['tool'], 'pen');
      expect(json['is_complete'], true);
      expect((json['points'] as List).length, 2);

      final parsed = Stroke.fromJson(json);
      expect(parsed.id, 'stroke-123');
      expect(parsed.color, '0xFF2196F3');
      expect(parsed.width, 4.0);
      expect(parsed.tool, 'pen');
      expect(parsed.isComplete, true);
      expect(parsed.points.length, 2);
    });
  });

  group('GeometryShape Model Tests', () {
    test('toJson and fromJson serializes correctly', () {
      const shape = GeometryShape(
        id: 'shape-456',
        shapeType: 'rectangle',
        startX: 50.0,
        startY: 50.0,
        endX: 200.0,
        endY: 150.0,
        color: '0xFFFF5722',
        strokeWidth: 3.0,
        fillColor: '0x33FF5722',
      );

      final json = shape.toJson();
      expect(json['type'], 'shape');
      expect(json['shape_id'], 'shape-456');
      expect(json['shape_type'], 'rectangle');
      expect(json['start_x'], 50.0);
      expect(json['start_y'], 50.0);
      expect(json['end_x'], 200.0);
      expect(json['end_y'], 150.0);
      expect(json['color'], '0xFFFF5722');
      expect(json['stroke_width'], 3.0);
      expect(json['fill_color'], '0x33FF5722');

      final parsed = GeometryShape.fromJson(json);
      expect(parsed.id, 'shape-456');
      expect(parsed.shapeType, 'rectangle');
      expect(parsed.startX, 50.0);
      expect(parsed.startY, 50.0);
      expect(parsed.endX, 200.0);
      expect(parsed.endY, 150.0);
      expect(parsed.color, '0xFFFF5722');
      expect(parsed.strokeWidth, 3.0);
      expect(parsed.fillColor, '0x33FF5722');
    });
  });
}
