import '../models/concept.dart';

/// Demande analysée par l'atelier local.
class ConceptRequest {
  /// Objets à concevoir (ex. « canard », « héron »), tels qu'écrits.
  final List<String> subjects;

  /// Matériaux cités (« boîtes de conserve »…).
  final List<String> materials;

  /// Destination (« jardin »…), vide si non précisée.
  final String destination;

  /// Mode « inventeur autonome » : l'utilisateur liste ce qu'il possède.
  final bool resourceMode;

  const ConceptRequest({
    this.subjects = const [],
    this.materials = const [],
    this.destination = '',
    this.resourceMode = false,
  });
}

/// Atelier hors ligne : analyse de la demande et variantes à partir de
/// modèles types. Fonctions pures (testables) ; aucune n'invente de mesure :
/// les dimensions sont des ordres de grandeur signalés comme indicatifs.
class OfflineAtelier {
  OfflineAtelier._();

  static const _articles =
      r"(?:(?:un|une|des|le|la|les|l'|mon|ma|mes|ton|ta|tes|du|de la|de l'|deux|trois|quelques|plein de|petit|petite|petits|petites|grand|grande)\s+)*";

  static final _makeVerb = RegExp(
      r"(?:fabriquer|construire|creer|faire|realiser|bricoler|sculpter|concevoir|assembler)\s+(.+)");
  static final _resourceStart = RegExp(r"j'ai\s+(.+?)(?:[.?!]|\s+(?:trouve|que |qu'|quoi|peux-tu|tu peux)|$)");
  static final _askIdea = RegExp(r"trouve|quoi fabriquer|quoi faire|que (?:puis|peux)-je|quelque chose|une idee|des idees");

  /// La demande appelle-t-elle des concepts plutôt qu'une invention unique ?
  /// [text] est en minuscules et sans accents.
  static bool wantsConcepts(String text) {
    if (RegExp(r'\b(?:plan|etape)s?\b').hasMatch(text)) return false;
    if (RegExp(r"(?:je veux|je voudrais|j'aimerais|j'ai envie de)\s+(?:fabriquer|construire|creer|faire|realiser|bricoler|sculpter)").hasMatch(text)) {
      return true;
    }
    if (RegExp(r'\b(?:variantes|concepts|plusieurs idees|propositions)\b').hasMatch(text)) return true;
    return _resourceStart.hasMatch(text) && _askIdea.hasMatch(text);
  }

  /// Analyse une demande. [original] est le texte tel que tapé et [text] sa
  /// version minuscule sans accents, de même longueur (les extraits sont
  /// repris dans [original] pour garder les accents).
  static ConceptRequest parse(String original, String text) {
    final resource = _resourceStart.firstMatch(text);
    if (resource != null && _askIdea.hasMatch(text) && !_makeVerb.hasMatch(text.substring(0, resource.start))) {
      final list = _slice(original, text, resource.start + 6, resource.end);
      return ConceptRequest(materials: _splitList(list), resourceMode: true);
    }

    final make = _makeVerb.firstMatch(text);
    if (make == null) return const ConceptRequest();
    final restStart = make.start + make.group(0)!.length - make.group(1)!.length;
    final rest = text.substring(restStart);
    final stop = RegExp(r"\s(?:avec|en|a partir|pour|afin|qui|dans|sur)\s|[,.;!?]").firstMatch(rest);
    final subjectsRaw = _slice(original, text, restStart, restStart + (stop?.start ?? rest.length));

    final materials = <String>[];
    final withMatch = RegExp(r"\savec\s+(.+?)(?:\s+(?:pour|afin|qui|dans)\s|[.;!?]|$)").firstMatch(rest);
    if (withMatch != null) {
      final s = restStart + withMatch.start + withMatch.group(0)!.indexOf(withMatch.group(1)!);
      materials.addAll(_splitList(_slice(original, text, s, s + withMatch.group(1)!.length)));
    }

    var destination = '';
    final dest = RegExp(r"pour\s+(?:decorer|orner|embellir|amenager|egayer)?\s*" + _articles + r"([a-z\-]+)").firstMatch(rest);
    if (dest != null) {
      final s = restStart + dest.start + dest.group(0)!.length - dest.group(1)!.length;
      destination = _slice(original, text, s, s + dest.group(1)!.length);
    }

    return ConceptRequest(
      subjects: _splitList(subjectsRaw).where((s) => s.length > 1).take(4).toList(),
      materials: materials,
      destination: destination,
    );
  }

  static String _slice(String original, String text, int start, int end) {
    // Longueurs identiques en pratique ; par sécurité on retombe sur le texte normalisé.
    final src = original.length == text.length ? original : text;
    return src.substring(start.clamp(0, src.length), end.clamp(0, src.length)).trim();
  }

  static List<String> _splitList(String s) => s
      .split(RegExp(r',|\s+et\s+|\s+ainsi que\s+', caseSensitive: false))
      .map((e) => e
          .replaceFirst(RegExp('^$_articles', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim())
      .where((e) => e.isNotEmpty)
      .toList();

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Trois variantes types par objet : rustique, articulée, stylisée.
  static List<InventionConcept> variantsFor(ConceptRequest req) {
    final outdoor = RegExp(r'jardin|terrasse|balcon|exterieur|extérieur|potager|cour', caseSensitive: false)
        .hasMatch(req.destination);
    final base = req.materials.isEmpty ? ['matériaux de récupération'] : req.materials;
    final finish = outdoor ? 'vernis ou peinture pour l\'extérieur' : 'peinture ou vernis';
    final metal = base.any((m) => RegExp(r'conserve|canette|metal|métal|tole|tôle|alu', caseSensitive: false).hasMatch(m));
    final edge = metal ? 'Bords métalliques coupants : ébavurer et porter des gants.' : '';
    const dims = 'à définir — ordre de grandeur suggéré ≈ 30 à 60 cm (indicatif)';

    final concepts = <InventionConcept>[];
    for (final raw in req.subjects) {
      final subject = _capitalize(raw);
      concepts.addAll([
        InventionConcept(
          subject: subject,
          name: '$subject rustique',
          style: 'Récup brut',
          description:
              'Silhouette simple obtenue en assemblant les éléments presque sans les transformer : '
              'l\'aspect récupération est assumé.',
          materials: [...base, 'vis ou rivets', 'fil de fer'],
          dimensions: dims,
          difficulty: 2,
          time: '≈ 2 à 3 h',
          budget: '≈ 0 à 10 € (surtout de la récupération)',
          advantages: ['Rapide à réaliser', 'Peu d\'outils', 'Valorise la récupération'],
          constraints: [if (edge.isNotEmpty) edge, 'Rendu volontairement brut'],
        ),
        InventionConcept(
          subject: subject,
          name: '$subject articulé',
          style: 'Mécanique / mobile',
          description:
              'Tête, cou ou ailes montés sur pivots en fil de fer : la pièce bouge au vent ou à la main.',
          materials: [...base, 'fil de fer épais', 'rondelles', 'vis et écrous'],
          dimensions: dims,
          difficulty: 4,
          time: '≈ 4 à 6 h',
          budget: '≈ 5 à 15 €',
          advantages: ['Effet vivant et ludique', 'Pièce originale'],
          constraints: [
            if (edge.isNotEmpty) edge,
            'Plus de pièces à ajuster',
            'Pivots à vérifier et graisser',
            if (outdoor) 'Stabilité au vent : prévoir un socle ou un piquet lesté',
          ],
        ),
        InventionConcept(
          subject: subject,
          name: '$subject stylisé',
          style: 'Décoratif minimaliste',
          description:
              'Formes simplifiées et lignes épurées, mises en valeur par la peinture : un objet décoratif graphique.',
          materials: [...base, finish, 'socle ou tige de fixation'],
          dimensions: dims,
          difficulty: 2,
          time: '≈ 3 h, séchage compris',
          budget: '≈ 8 à 20 € (peinture)',
          advantages: ['Très décoratif', 'Facile à personnaliser'],
          constraints: [
            if (edge.isNotEmpty) edge,
            if (outdoor) 'Peinture extérieure et protection anticorrosion indispensables',
          ],
        ),
      ]);
    }
    return concepts;
  }

  static const _ideas = <({String name, String style, String description, List<String> needs, int difficulty, String time})>[
    (name: 'Photophore ajouré', style: 'Lumière', description: 'Boîte percée de motifs au clou, avec une bougie LED à l\'intérieur.', needs: ['conserve', 'clou'], difficulty: 1, time: '≈ 1 h'),
    (name: 'Carillon à vent', style: 'Jardin sonore', description: 'Éléments suspendus à des longueurs différentes, qui tintent au vent.', needs: ['conserve', 'fil'], difficulty: 2, time: '≈ 2 h'),
    (name: 'Pot suspendu pour aromates', style: 'Jardin', description: 'Contenant percé au fond pour le drainage, suspendu par une anse.', needs: ['conserve', 'fil', 'vis'], difficulty: 1, time: '≈ 1 h'),
    (name: 'Organiseur de bureau', style: 'Rangement', description: 'Plusieurs contenants fixés ensemble ou sur une planchette.', needs: ['conserve', 'vis', 'planche'], difficulty: 2, time: '≈ 2 h'),
    (name: 'Mangeoire à oiseaux', style: 'Jardin', description: 'Contenant couché avec un perchoir, suspendu hors de portée des chats.', needs: ['conserve', 'fil', 'baguette'], difficulty: 2, time: '≈ 1 h 30'),
    (name: 'Sculpture filaire', style: 'Art', description: 'Silhouette dessinée en fil de fer plié, fixée sur un socle.', needs: ['fil', 'socle'], difficulty: 2, time: '≈ 2 h'),
    (name: 'Mini-serre', style: 'Jardin', description: 'Bouteille coupée placée sur les semis pour les protéger.', needs: ['bouteille'], difficulty: 1, time: '≈ 30 min'),
    (name: 'Arrosage goutte-à-goutte', style: 'Jardin', description: 'Bouteille percée et enterrée tête en bas près des racines.', needs: ['bouteille'], difficulty: 1, time: '≈ 30 min'),
    (name: 'Jardinière en bois', style: 'Jardin', description: 'Caisse assemblée en planches, doublée d\'une toile.', needs: ['planche', 'vis'], difficulty: 3, time: '≈ 3 h'),
    (name: 'Étagère murale', style: 'Rangement', description: 'Planches et équerres pour une étagère simple.', needs: ['planche', 'vis', 'equerre'], difficulty: 3, time: '≈ 2 h'),
  ];

  /// Mode « inventeur autonome » : idées classées selon les ressources citées.
  static List<InventionConcept> ideasFromResources(List<String> resources) {
    final norm = resources.map(_normalize).join(' ');
    bool has(String need) => switch (need) {
          'conserve' => RegExp(r'conserve|canette|boite').hasMatch(norm),
          'fil' => RegExp(r'\bfil\b|ficelle|corde').hasMatch(norm),
          'planche' => RegExp(r'planche|bois|palette|tasseau').hasMatch(norm),
          'vis' => RegExp(r'\bvis\b|clou|rivet|boulon').hasMatch(norm),
          _ => norm.contains(need),
        };
    final scored = [
      for (final idea in _ideas)
        (idea: idea, covered: idea.needs.where(has).toList(), missing: idea.needs.where((n) => !has(n)).toList()),
    ]..sort((a, b) => (b.covered.length / b.idea.needs.length).compareTo(a.covered.length / a.idea.needs.length));

    return [
      for (final s in scored.where((s) => s.covered.isNotEmpty).take(3))
        InventionConcept(
          subject: 'Avec tes ressources',
          name: s.idea.name,
          style: s.idea.style,
          description: s.idea.description,
          materials: resources,
          dimensions: 'selon tes pièces — à mesurer avant de commencer',
          difficulty: s.idea.difficulty,
          time: s.idea.time,
          budget: s.missing.isEmpty ? '≈ 0 € (tout est déjà là)' : 'faible (petits compléments)',
          feasibility: (100 * s.covered.length / s.idea.needs.length).round(),
          why: s.missing.isEmpty
              ? 'Réalisable entièrement avec ce que tu as cité.'
              : 'Utilise ce que tu as ; il manquerait : ${s.missing.join(', ')}.',
          constraints: [
            if (RegExp(r'conserve|canette|boite').hasMatch(norm))
              'Bords métalliques coupants : ébavurer et porter des gants.',
          ],
        ),
    ];
  }

  static String _normalize(String s) {
    const from = 'àáâäãåçèéêëìíîïòóôöõùúûüýÿñ';
    const to = 'aaaaaaceeeeiiiiooooouuuuyyn';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }
}
