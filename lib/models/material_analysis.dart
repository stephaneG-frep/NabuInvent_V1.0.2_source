import '../ai/lenient_json.dart';
import 'json_utils.dart';

/// Objet ou matériau repéré sur une photo, corrigeable par l'utilisateur.
class DetectedMaterial {
  String name;
  String material;

  /// Quantité visible ; null si l'IA ne peut pas l'estimer.
  int? quantity;

  /// Dimensions saisies par l'utilisateur (l'IA ne les mesure pas sur photo).
  String dimensions;

  /// Confiance de la reconnaissance, 0–100 (0 = ajouté à la main).
  final int confidence;

  /// L'utilisateur a corrigé ou ajouté cet élément.
  bool edited;

  DetectedMaterial({
    required this.name,
    this.material = '',
    this.quantity,
    this.dimensions = '',
    this.confidence = 0,
    this.edited = false,
  });

  factory DetectedMaterial.fromJson(Map<String, dynamic> json) => DetectedMaterial(
        name: jsonString(json['name']),
        material: jsonString(json['material']),
        quantity: json['quantity'] == null ? null : jsonInt(json['quantity'], 1, min: 1),
        confidence: jsonInt(json['confidence'], 50, min: 0, max: 100),
      );

  /// Ligne lisible, ex. « 4 × boîtes de conserve (acier, ≈ 10 cm) ».
  String describe() {
    final details = [
      if (material.isNotEmpty) material,
      if (dimensions.isNotEmpty) dimensions,
    ].join(', ');
    return '${quantity != null ? '$quantity × ' : ''}$name${details.isEmpty ? '' : ' ($details)'}';
  }
}

/// Résultat d'une analyse de photo par un modèle multimodal.
class MaterialAnalysis {
  final String message;
  final List<DetectedMaterial> items;

  /// Informations que l'IA ne peut pas déduire de l'image (dimensions…).
  final List<String> questions;
  final String provider;

  const MaterialAnalysis({
    required this.message,
    required this.items,
    this.questions = const [],
    required this.provider,
  });

  static const prompt = '''
Tu analyses la photo d'un bricoleur qui veut savoir ce qu'il peut fabriquer avec ce qu'il possède.
Liste UNIQUEMENT les objets et matériaux réellement visibles et réutilisables (boîtes de conserve,
bouteilles, palettes, chutes de bois, tubes, outils, cartons, pièces mécaniques…).
Ne devine pas ce qui n'est pas visible. Ne donne AUCUNE dimension : elles ne peuvent pas être
mesurées sur une photo ; demande-les dans "questions" si elles sont utiles.
Réponds UNIQUEMENT avec un objet JSON :
{
  "message": "1 à 2 phrases en français sur ce que tu vois",
  "items": [{"name": string, "material": string, "quantity": int ou null, "confidence": 0-100}],
  "questions": [string] // informations manquantes utiles (dimensions, état, quantités cachées)
}''';

  /// Interprète la réponse du modèle (JSON tolérant, jamais affiché brut).
  factory MaterialAnalysis.parse(String content, String provider) {
    final json = LenientJson.decodeObject(content).map;
    if (json == null) {
      return MaterialAnalysis(
        message: LenientJson.looksLikeJson(content)
            ? (LenientJson.extractMessage(content) ?? 'Réponse illisible du modèle.')
            : content.trim(),
        items: const [],
        provider: provider,
      );
    }
    final items = <DetectedMaterial>[
      if (json['items'] is List)
        for (final e in json['items'] as List)
          if (jsonMap(e) case final m?)
            if (jsonString(m['name']).trim().isNotEmpty) DetectedMaterial.fromJson(m),
    ];
    return MaterialAnalysis(
      message: jsonString(json['message']),
      items: items,
      questions: jsonStringList(json['questions']),
      provider: provider,
    );
  }

  /// Demande envoyée au Studio une fois la liste vérifiée par l'utilisateur.
  static String toResourceRequest(List<DetectedMaterial> items) {
    final lines = items.where((i) => i.name.trim().isNotEmpty).map((i) => i.describe()).toList();
    return 'J\'ai, d\'après une photo vérifiée de mes matériaux : ${lines.join(' ; ')}. '
        'Trouve-moi quelque chose à fabriquer.';
  }
}
