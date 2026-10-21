import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_provider.dart';
import 'ai_response.dart';

class OpenAICompatibleProvider extends AiProvider {
  final String baseUrl;
  final String apiKey;
  final String model;

  OpenAICompatibleProvider({
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
  });

  @override
  String get name => 'API compatible OpenAI ($model)';

  @override
  bool get isCloud => true;

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  Uri get _endpoint {
    var base = baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (base.endsWith('/chat/completions')) {
      return Uri.parse(base);
    }
    return Uri.parse('$base/chat/completions');
  }

  @override
  Future<NabuAiResponse> respond({
    required String userText,
    List<AiTurn> history = const [],
    String? projectContext,
  }) async {
    final messages = [
      {'role': 'system', 'content': AiContract.systemPrompt},
      ...history.map((t) => t.toJson()),
      {
        'role': 'user',
        'content': AiContract.buildUserContent(
          userText: userText,
          projectContext: projectContext,
        ),
      },
    ];

    final endpoint = _endpoint;
    if (endpoint.scheme != 'https') {
      throw Exception(
          'L\'URL de base doit commencer par https:// (la clé API ne doit pas '
          'circuler en clair).');
    }

    // Les paramètres facultatifs ne sont pas acceptés par tous les modèles
    // (ex. « temperature is deprecated » sur les Claude récents, « max_tokens »
    // remplacé par « max_completion_tokens » chez OpenAI). Si le fournisseur
    // en refuse un, on le retire et on renvoie la requête ; l'ajustement est
    // mémorisé pour ce couple URL + modèle.
    final key = '${endpoint.toString()}|${model.trim()}';
    final options = _optionsByModel.putIfAbsent(
        key, () => {'temperature': 0.8, 'max_tokens': 1800});

    http.Response res;
    for (var attempt = 0;; attempt++) {
      res = await http
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model.trim(),
              'messages': messages,
              ...options,
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (res.statusCode == 200) break;
      final message = _errorMessage(res.body);
      if (res.statusCode != 400 || attempt >= 3 || !_dropRejectedOption(options, message)) {
        throw AiHttpException(res.statusCode, message);
      }
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final content = ((decoded['choices'] as List?)?.firstOrNull
            as Map<String, dynamic>?)?['message']?['content']
        as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('Réponse vide du modèle');
    }
    return NabuAiResponse.parse(content, name);
  }

  static final Map<String, Map<String, Object>> _optionsByModel = {};

  /// Retire (ou renomme) le paramètre cité dans le message d'erreur.
  /// Renvoie false si aucun paramètre connu n'est en cause.
  static bool _dropRejectedOption(Map<String, Object> options, String message) {
    final m = message.toLowerCase();
    if (m.contains('max_tokens') && options.containsKey('max_tokens')) {
      final value = options.remove('max_tokens')!;
      if (!m.contains('max_completion_tokens')) return true;
      options['max_completion_tokens'] = value;
      return true;
    }
    if (m.contains('max_completion_tokens') &&
        options.containsKey('max_completion_tokens')) {
      options.remove('max_completion_tokens');
      return true;
    }
    if (m.contains('temperature') && options.containsKey('temperature')) {
      options.remove('temperature');
      return true;
    }
    return false;
  }

  /// Extrait le message d'erreur du fournisseur. Formats rencontrés :
  /// {"error":{"message":…}} (OpenAI, Anthropic, Groq…), [{"error":{…}}]
  /// (Gemini), {"message":…} ou {"detail":…} (Mistral, Perplexity).
  String _errorMessage(String body) {
    try {
      var json = jsonDecode(body);
      if (json is List && json.isNotEmpty) json = json.first;
      if (json is Map) {
        final err = json['error'];
        final msg = err is Map ? err['message'] : (err ?? json['message'] ?? json['detail']);
        if (msg != null && msg.toString().trim().isNotEmpty) {
          return msg.toString().trim();
        }
      }
    } catch (_) {}
    final s = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '(réponse vide)';
    return s.length > 160 ? s.substring(0, 160) : s;
  }
}

/// Erreur HTTP d'un fournisseur, avec une explication lisible en français.
class AiHttpException implements Exception {
  final int statusCode;
  final String serverMessage;
  const AiHttpException(this.statusCode, this.serverMessage);

  String get hint {
    final m = serverMessage.toLowerCase();
    if (statusCode == 401 || statusCode == 403 ||
        m.contains('api key') || m.contains('api_key')) {
      return 'Clé API refusée : vérifie qu\'elle correspond bien à ce fournisseur '
          'et qu\'elle est toujours active.';
    }
    final modelProblem = m.contains('model') &&
        (m.contains('not found') || m.contains('does not exist') ||
            m.contains('not_found') || m.contains('invalid model') ||
            m.contains('unknown model') || m.contains('no such model') ||
            m.contains('decommissioned') || m.contains('retired'));
    if (statusCode == 404 || modelProblem) {
      return 'Modèle introuvable ou retiré : vérifie le nom du modèle dans la '
          'documentation du fournisseur.';
    }
    if (statusCode == 402 || statusCode == 429 ||
        m.contains('credit') || m.contains('quota') || m.contains('billing')) {
      return 'Quota ou crédits épuisés : vérifie la facturation de ton compte.';
    }
    return 'Le fournisseur a refusé la requête.';
  }

  @override
  String toString() => '$hint (HTTP $statusCode : $serverMessage)';
}