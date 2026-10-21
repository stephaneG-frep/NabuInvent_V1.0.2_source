class ChatTurn {
  final String role;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;

  ChatTurn({
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.payload,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        if (payload != null) 'payload': payload,
      };

  factory ChatTurn.fromJson(Map<String, dynamic> json) => ChatTurn(
        role: json['role'] as String? ?? 'assistant',
        content: json['content'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
      );
}