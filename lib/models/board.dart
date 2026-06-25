class Board {
  final String id;
  final String title;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Board({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Board',
      ownerId: json['owner_id'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
}
