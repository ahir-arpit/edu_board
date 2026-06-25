class DrawingPoint {
  final double x;
  final double y;
  final double pressure;

  const DrawingPoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'p': pressure,
    };
  }

  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    return DrawingPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pressure: (json['p'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
