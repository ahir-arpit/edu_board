class PairingSession {
  final String id;
  final String sessionCode;
  final String boardId;
  final bool isActive;
  final DateTime createdAt;

  const PairingSession({
    required this.id,
    required this.sessionCode,
    required this.boardId,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_code': sessionCode,
      'board_id': boardId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PairingSession.fromJson(Map<String, dynamic> json) {
    return PairingSession(
      id: json['id'] ?? '',
      sessionCode: json['session_code'] ?? '',
      boardId: json['board_id'] ?? '',
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
}
