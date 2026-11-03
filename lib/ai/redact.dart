/// Masque tout ce qui ressemble à un secret avant d'afficher ou d'enregistrer
/// un texte brut (mode technique, rapports d'erreur).
String redactSecrets(String text) => text
    .replaceAll(RegExp(r'sk-[A-Za-z0-9_\-]{12,}'), '[clé masquée]')
    .replaceAll(RegExp(r'AIza[0-9A-Za-z_\-]{20,}'), '[clé masquée]')
    .replaceAll(RegExp(r'gsk_[A-Za-z0-9]{20,}'), '[clé masquée]')
    .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._\-]{8,}'), 'Bearer [masqué]');
