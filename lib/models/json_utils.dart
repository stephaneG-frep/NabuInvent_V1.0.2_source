// Lecture tolérante des JSON : les réponses des modèles cloud ne respectent
// pas toujours les types (ex. "difficulty": "3" ou 3.0 au lieu de 3).

String jsonString(Object? v, [String fallback = '']) {
  if (v == null) return fallback;
  if (v is String) return v;
  if (v is num || v is bool) return v.toString();
  return fallback;
}

String? jsonStringOrNull(Object? v) {
  if (v == null) return null;
  final s = jsonString(v);
  return s.isEmpty ? null : s;
}

int jsonInt(Object? v, int fallback, {int? min, int? max}) {
  int? n;
  if (v is int) {
    n = v;
  } else if (v is num) {
    n = v.round();
  } else if (v is String) {
    n = num.tryParse(v.trim().replaceAll(',', '.'))?.round();
  }
  n ??= fallback;
  if (min != null && n < min) n = min;
  if (max != null && n > max) n = max;
  return n;
}

bool jsonBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == 'oui') return true;
    if (s == 'false' || s == 'non') return false;
  }
  return fallback;
}

List<String> jsonStringList(Object? v) {
  if (v is List) {
    return [for (final e in v) if (e != null) e.toString()];
  }
  if (v is String && v.trim().isNotEmpty) return [v.trim()];
  return [];
}

Map<String, dynamic>? jsonMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;
