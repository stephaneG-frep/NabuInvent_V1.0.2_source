class Spark {
  final String id;
  final String title;
  final String domain;
  final String mechanism;
  final String material;
  final String pitch;
  final bool challenge;
  final DateTime createdAt;
  bool saved;

  Spark({
    required this.id,
    required this.title,
    required this.domain,
    required this.mechanism,
    required this.material,
    required this.pitch,
    this.challenge = false,
    DateTime? createdAt,
    this.saved = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'domain': domain,
        'mechanism': mechanism,
        'material': material,
        'pitch': pitch,
        'challenge': challenge,
        'createdAt': createdAt.toIso8601String(),
        'saved': saved,
      };

  factory Spark.fromJson(Map<String, dynamic> json) => Spark(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        domain: json['domain'] as String? ?? '',
        mechanism: json['mechanism'] as String? ?? '',
        material: json['material'] as String? ?? '',
        pitch: json['pitch'] as String? ?? '',
        challenge: json['challenge'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        saved: json['saved'] as bool? ?? false,
      );
}