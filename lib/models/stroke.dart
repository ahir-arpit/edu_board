import 'drawing_point.dart';

class Stroke {
  final String id;
  final List<DrawingPoint> points;
  final String color;
  final double width;
  final String tool; // 'pen', 'highlighter', 'eraser'
  final bool isComplete;

  const Stroke({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
    this.isComplete = false,
  });

  Stroke copyWith({
    String? id,
    List<DrawingPoint>? points,
    String? color,
    double? width,
    String? tool,
    bool? isComplete,
  }) {
    return Stroke(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      tool: tool ?? this.tool,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'stroke',
      'stroke_id': id,
      'points': points.map((p) => p.toJson()).toList(),
      'color': color,
      'width': width,
      'tool': tool,
      'is_complete': isComplete,
    };
  }

  factory Stroke.fromJson(Map<String, dynamic> json) {
    return Stroke(
      id: json['stroke_id'] ?? '',
      points: (json['points'] as List<dynamic>?)
              ?.map((p) => DrawingPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      color: json['color'] ?? '0xFF000000',
      width: (json['width'] as num?)?.toDouble() ?? 2.0,
      tool: json['tool'] ?? 'pen',
      isComplete: json['is_complete'] ?? true,
    );
  }
}
