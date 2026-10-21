class BacklogIdea {
  final String id;
  final String title;
  final String note;
  final List<String> tags;
  final DateTime createdAt;
  String? convertedProjectId;
  bool archived;

  BacklogIdea({
    required this.id,
    required this.title,
    this.note = '',
    List<String>? tags,
    DateTime? createdAt,
    this.convertedProjectId,
    this.archived = false,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isConverted => convertedProjectId != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'convertedProjectId': convertedProjectId,
        'archived': archived,
      };

  factory BacklogIdea.fromJson(Map<String, dynamic> json) => BacklogIdea(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        note: json['note'] as String? ?? '',
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        convertedProjectId: json['convertedProjectId'] as String?,
        archived: json['archived'] as bool? ?? false,
      );
}