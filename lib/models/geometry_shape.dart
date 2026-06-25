class GeometryShape {
  final String id;
  final String shapeType; // 'line', 'arrow', 'rectangle', 'circle', 'triangle'
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final String color;
  final double strokeWidth;
  final String? fillColor;

  const GeometryShape({
    required this.id,
    required this.shapeType,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.color,
    required this.strokeWidth,
    this.fillColor,
  });

  GeometryShape copyWith({
    String? id,
    String? shapeType,
    double? startX,
    double? startY,
    double? endX,
    double? endY,
    String? color,
    double? strokeWidth,
    String? fillColor,
  }) {
    return GeometryShape(
      id: id ?? this.id,
      shapeType: shapeType ?? this.shapeType,
      startX: startX ?? this.startX,
      startY: startY ?? this.startY,
      endX: endX ?? this.endX,
      endY: endY ?? this.endY,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      fillColor: fillColor ?? this.fillColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'shape',
      'shape_id': id,
      'shape_type': shapeType,
      'start_x': startX,
      'start_y': startY,
      'end_x': endX,
      'end_y': endY,
      'color': color,
      'stroke_width': strokeWidth,
      'fill_color': fillColor,
    };
  }

  factory GeometryShape.fromJson(Map<String, dynamic> json) {
    return GeometryShape(
      id: json['shape_id'] ?? '',
      shapeType: json['shape_type'] ?? 'line',
      startX: (json['start_x'] as num?)?.toDouble() ?? 0.0,
      startY: (json['start_y'] as num?)?.toDouble() ?? 0.0,
      endX: (json['end_x'] as num?)?.toDouble() ?? 0.0,
      endY: (json['end_y'] as num?)?.toDouble() ?? 0.0,
      color: json['color'] ?? '0xFF000000',
      strokeWidth: (json['stroke_width'] as num?)?.toDouble() ?? 2.0,
      fillColor: json['fill_color'],
    );
  }
}
