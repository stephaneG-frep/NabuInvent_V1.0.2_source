import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/invention_project.dart';
import 'openai_provider.dart';

/// Fournisseur de génération d'images. Aucune implémentation locale : sans
/// fournisseur configuré, la fonction est indiquée comme indisponible.
abstract class ImageGenerator {
  String get name;
  bool get isConfigured;
  Future<Uint8List> generate(String prompt);
}

/// Point d'accès compatible OpenAI `/images/generations` (OpenAI gpt-image-1,
/// dall-e-3, ou tout service exposant la même API).
class OpenAIImageGenerator implements ImageGenerator {
  final String baseUrl;
  final String apiKey;
  final String model;

  OpenAIImageGenerator({required this.baseUrl, required this.apiKey, required this.model});

  @override
  String get name => 'Images ($model)';

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  Uri get endpoint {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse(base.endsWith('/images/generations') ? base : '$base/images/generations');
  }

  /// Options refusées par certains modèles (gpt-image-1 ne connaît pas
  /// response_format) : retirées et mémorisées comme pour le texte.
  static final Map<String, Map<String, Object>> _optionsByModel = {};

  @override
  Future<Uint8List> generate(String prompt) async {
    final url = endpoint;
    if (url.scheme != 'https') {
      throw Exception('L\'URL du service d\'images doit commencer par https://.');
    }
    final options = _optionsByModel.putIfAbsent(
        '$url|$model', () => {'size': '1024x1024', 'response_format': 'b64_json'});
    http.Response res;
    for (var attempt = 0;; attempt++) {
      res = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'model': model.trim(), 'prompt': prompt, 'n': 1, ...options}),
          )
          .timeout(const Duration(seconds: 150));
      if (res.statusCode == 200) break;
      final message = _message(res.body);
      final rejected = options.keys
          .where((k) => message.toLowerCase().contains(k))
          .toList();
      if (res.statusCode != 400 || attempt >= 2 || rejected.isEmpty) {
        throw AiHttpException(res.statusCode, message);
      }
      for (final k in rejected) {
        options.remove(k);
      }
    }

    final decoded = jsonDecode(res.body);
    final first = decoded is Map && decoded['data'] is List && (decoded['data'] as List).isNotEmpty
        ? (decoded['data'] as List).first
        : null;
    if (first is Map && first['b64_json'] is String) {
      return base64Decode(first['b64_json'] as String);
    }
    if (first is Map && first['url'] is String) {
      final img = await http.get(Uri.parse(first['url'] as String)).timeout(const Duration(seconds: 60));
      if (img.statusCode == 200) return img.bodyBytes;
      throw Exception('Téléchargement de l\'image impossible (HTTP ${img.statusCode}).');
    }
    throw Exception('Le service n\'a renvoyé aucune image.');
  }

  static String _message(String body) {
    try {
      final j = jsonDecode(body);
      final err = j is Map ? j['error'] : null;
      final msg = err is Map ? err['message'] : err;
      if (msg != null) return msg.toString();
    } catch (_) {}
    return body.length > 200 ? body.substring(0, 200) : body;
  }
}

/// Styles d'aperçu proposés.
class VisualStyle {
  final String name;
  final String direction;
  const VisualStyle(this.name, this.direction);

  static const all = [
    VisualStyle('Réaliste', 'photographie réaliste, éclairage naturel doux, détails des matériaux visibles'),
    VisualStyle('Rustique', 'ambiance rustique et chaleureuse, matériaux patinés, lumière de fin de journée'),
    VisualStyle('Industriel', 'style industriel, métal brut, rivets apparents, éclairage d\'atelier'),
    VisualStyle('Fantaisiste', 'univers fantaisiste et ludique, couleurs vives, mise en scène poétique'),
    VisualStyle('Artistique', 'rendu d\'illustration artistique, aquarelle et encre, composition soignée'),
    VisualStyle('Minimaliste', 'rendu minimaliste, formes épurées, fond uni clair, peu d\'éléments'),
  ];

  static VisualStyle byName(String name) =>
      all.firstWhere((s) => s.name == name, orElse: () => all.first);
}

/// Prompt d'aperçu construit à partir des données du projet (déterministe) :
/// l'image reste cohérente avec le concept et les matériaux choisis.
String buildVisualPrompt(InventionProject p, String style, List<String> modifications) {
  final s = VisualStyle.byName(style);
  final b = StringBuffer()
    ..write('Aperçu d\'un objet fabriqué à la main par un bricoleur : « ${p.title} ». ');
  if (p.concept.isNotEmpty) b.write('${p.concept} ');
  if (p.materials.isNotEmpty) {
    b.write('Fabriqué avec : ${p.materials.take(8).join(', ')} ; ces matériaux doivent être reconnaissables. ');
  }
  if (p.designNotes.isNotEmpty) b.write('Contraintes : ${p.designNotes.take(6).join(' ; ')}. ');
  if (modifications.isNotEmpty) {
    b.write('Modifications demandées : ${modifications.join(' ; ')}. ');
  }
  b.write('Style : ${s.direction}. Objet entier visible, vue de trois-quarts, '
      'aucun texte, aucune personne, aucun logo.');
  return b.toString();
}
