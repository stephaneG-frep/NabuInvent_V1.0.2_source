import 'dart:convert';

/// Résultat d'un décodage tolérant d'une réponse de modèle.
class LenientJsonResult {
  /// L'objet JSON récupéré, ou null si aucun objet n'a pu être lu.
  final Map<String, dynamic>? map;

  /// true si le JSON a dû être réparé (réponse tronquée, virgule finale…).
  final bool repaired;

  const LenientJsonResult(this.map, {this.repaired = false});
}

/// Décodage tolérant des réponses JSON des modèles de langage.
///
/// Les modèles renvoient souvent un JSON entouré de texte ou de blocs
/// ```json, avec des virgules finales, ou coupé net quand la limite de
/// tokens est atteinte. Plutôt que d'afficher ce texte brut à l'utilisateur,
/// on récupère tout ce qui est récupérable.
class LenientJson {
  LenientJson._();

  /// Nombre maximal de points de coupe essayés pour réparer un JSON tronqué.
  static const _maxRepairAttempts = 400;

  static LenientJsonResult decodeObject(String content) {
    final text = _stripFences(content);
    final start = text.indexOf('{');
    if (start < 0) return const LenientJsonResult(null);

    // 1. Cas nominal : un objet complet, éventuellement entouré de texte.
    final end = text.lastIndexOf('}');
    if (end > start) {
      final map = _tryDecode(text.substring(start, end + 1));
      if (map != null) return LenientJsonResult(map);
      final cleaned = _removeTrailingCommas(text.substring(start, end + 1));
      final map2 = _tryDecode(cleaned);
      if (map2 != null) return LenientJsonResult(map2, repaired: true);
    }

    // 2. JSON tronqué : on coupe après la dernière valeur complète possible
    //    et on referme les chaînes, tableaux et objets ouverts.
    final body = _removeTrailingCommas(text.substring(start));
    final cuts = _cutPoints(body);
    var attempts = 0;
    for (final cut in cuts) {
      if (attempts++ >= _maxRepairAttempts) break;
      final candidate = _close(body.substring(0, cut));
      if (candidate == null) continue;
      final map = _tryDecode(candidate);
      if (map != null) return LenientJsonResult(map, repaired: true);
    }
    return const LenientJsonResult(null);
  }

  /// Extrait la valeur de "message" d'un texte JSON illisible, si possible.
  static String? extractMessage(String content) {
    final m = RegExp(r'"message"\s*:\s*"((?:[^"\\]|\\.)*)').firstMatch(content);
    if (m == null) return null;
    final raw = m.group(1)!;
    try {
      return jsonDecode('"$raw"') as String;
    } catch (_) {
      return raw.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
    }
  }

  /// Le texte ressemble-t-il à une réponse JSON (et non à de la prose) ?
  static bool looksLikeJson(String content) {
    final t = _stripFences(content).trimLeft();
    return t.startsWith('{') ||
        RegExp(r'^\s*```(?:json)?', caseSensitive: false).hasMatch(content) &&
            content.contains('{');
  }

  static String _stripFences(String s) => s
      .replaceAll(RegExp(r'```(?:json|JSON)?[ \t]*\r?\n?'), '')
      .trim();

  static Map<String, dynamic>? _tryDecode(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map ? v.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// Supprime les virgules placées juste avant } ou ], hors des chaînes.
  static String _removeTrailingCommas(String s) {
    final out = StringBuffer();
    var inString = false;
    var escape = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (inString) {
        out.write(c);
        if (escape) {
          escape = false;
        } else if (c == '\\') {
          escape = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
        out.write(c);
        continue;
      }
      if (c == ',') {
        var j = i + 1;
        while (j < s.length && ' \t\r\n'.contains(s[j])) {
          j++;
        }
        if (j < s.length && (s[j] == '}' || s[j] == ']')) continue;
      }
      out.write(c);
    }
    return out.toString();
  }

  /// Positions (de la plus tardive à la plus précoce) où couper le texte :
  /// la fin du texte, puis juste avant chaque virgule et après chaque
  /// fermeture, hors des chaînes.
  static List<int> _cutPoints(String s) {
    final points = <int>[s.length];
    var inString = false;
    var escape = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (inString) {
        if (escape) {
          escape = false;
        } else if (c == '\\') {
          escape = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == ',') {
        points.add(i);
      } else if (c == '}' || c == ']') {
        points.add(i + 1);
      }
    }
    final unique = points.toSet().toList()..sort((a, b) => b.compareTo(a));
    return unique;
  }

  /// Referme un préfixe de JSON : chaîne ouverte, tableaux, objets.
  /// Renvoie null si le préfixe se termine sur une clé sans valeur.
  static String? _close(String prefix) {
    final stack = <String>[];
    var inString = false;
    var escape = false;
    for (var i = 0; i < prefix.length; i++) {
      final c = prefix[i];
      if (inString) {
        if (escape) {
          escape = false;
        } else if (c == '\\') {
          escape = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '{') {
        stack.add('}');
      } else if (c == '[') {
        stack.add(']');
      } else if ((c == '}' || c == ']') && stack.isNotEmpty) {
        stack.removeLast();
      }
    }
    var out = prefix;
    if (inString) {
      // Une barre oblique inverse finale casserait la chaîne refermée.
      if (escape) out = out.substring(0, out.length - 1);
      out = '$out"';
    }
    final trimmed = out.trimRight();
    if (trimmed.endsWith(':') || trimmed.endsWith(',')) return null;
    return trimmed + stack.reversed.join();
  }
}
