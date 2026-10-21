class JournalEntry {
  final String id;
  final String text;
  final String? projectId;
  final DateTime createdAt;

  JournalEntry({
    required this.id,
    required this.text,
    this.projectId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'projectId': projectId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        projectId: json['projectId'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}